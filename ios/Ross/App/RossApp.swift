import AuthenticationServices
import Foundation
import LocalAuthentication
import Security
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

func rossBackendBaseURL() -> URL {
    let environment = ProcessInfo.processInfo.environment
    let rawURL = environment["ROSS_BACKEND_BASE_URL"] ?? environment["ROSS_BACKEND_URL"] ?? "http://127.0.0.1:8080"
    return URL(string: rawURL) ?? URL(string: "http://127.0.0.1:8080")!
}

func rossMobileAuthRedirectURL() -> URL {
    let environment = ProcessInfo.processInfo.environment
    let rawURL = environment["ROSS_AUTH_MOBILE_REDIRECT"] ?? "ross://auth/callback"
    return URL(string: rawURL) ?? URL(string: "ross://auth/callback")!
}

struct RossAuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accountToken: String
    let email: String
    let displayName: String?
    let subject: String
    let expiresAt: Date

    var displayLabel: String {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? email : trimmedName
    }
}

enum RossAuthPhase: Equatable {
    case loading
    case signedOut
    case unlockRequired(RossAuthSession)
    case signedIn(RossAuthSession)
}

final class RossAuthSessionSnapshot: @unchecked Sendable {
    static let shared = RossAuthSessionSnapshot()

    private let lock = NSLock()
    private var cachedSession: RossAuthSession?

    private init() {}

    func update(_ session: RossAuthSession?) {
        lock.lock()
        cachedSession = session
        lock.unlock()
    }

    func accountToken(fallback: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return cachedSession?.accountToken ?? fallback
    }

    func accessToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSession?.accessToken
    }
}

private final class RossAuthSessionStore {
    private let service = "ross.ios.auth.session"
    private let account = "primary"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func loadSession() throws -> RossAuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: "RossAuthSessionStore", code: Int(status), userInfo: nil)
        }

        return try decoder.decode(RossAuthSession.self, from: data)
    }

    func saveSession(_ session: RossAuthSession) throws {
        let data = try encoder.encode(session)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            let addQuery = query.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: "RossAuthSessionStore", code: Int(addStatus), userInfo: nil)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw NSError(domain: "RossAuthSessionStore", code: Int(updateStatus), userInfo: nil)
        }
    }

    func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct RossRefreshSessionPayload: Decodable {
    struct Profile: Decodable {
        let email: String?
        let displayName: String?
    }

    let accountToken: String
    let accessToken: String
    let refreshToken: String
    let subject: String
    let expiresAt: Date
    let profile: Profile?

    private enum CodingKeys: String, CodingKey {
        case accountToken
        case accessToken
        case refreshToken
        case subject
        case expiresAt
        case profile
    }
}

@MainActor
@Observable
final class RossAuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    @ObservationIgnored private let store = RossAuthSessionStore()
    @ObservationIgnored private var webAuthenticationSession: ASWebAuthenticationSession?
    @ObservationIgnored private let isoFormatter = ISO8601DateFormatter()
    @ObservationIgnored private var didLoad = false

    var phase: RossAuthPhase = .loading
    var isStartingSignIn = false
    var authErrorMessage: String?

    var session: RossAuthSession? {
        switch phase {
        case .unlockRequired(let session), .signedIn(let session):
            session
        case .loading, .signedOut:
            nil
        }
    }

    var quickUnlockSummary: String {
        switch currentBiometryType() {
        case .faceID:
            "Face ID or device passcode"
        case .touchID:
            "Touch ID or device passcode"
        default:
            "Device passcode"
        }
    }

    var unlockButtonTitle: String {
        if let biometryLabel = availableBiometryLabel() {
            return "Unlock with \(biometryLabel)"
        }
        return "Unlock"
    }

    var unlockSymbolName: String {
        switch currentBiometryType() {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        default:
            "lock.open.display"
        }
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        do {
            guard let storedSession = try store.loadSession() else {
                RossAuthSessionSnapshot.shared.update(nil)
                phase = .signedOut
                return
            }

            let activeSession = try await refreshedSessionIfNeeded(from: storedSession)
            RossAuthSessionSnapshot.shared.update(activeSession)
            phase = shouldRequireUnlock() ? .unlockRequired(activeSession) : .signedIn(activeSession)
        } catch {
            store.clearSession()
            RossAuthSessionSnapshot.shared.update(nil)
            phase = .signedOut
            authErrorMessage = nil
        }
    }

    func startGoogleSignIn() {
        guard !isStartingSignIn else { return }
        authErrorMessage = nil
        isStartingSignIn = true

        guard let callbackScheme = rossMobileAuthRedirectURL().scheme else {
            isStartingSignIn = false
            authErrorMessage = "Ross could not prepare the mobile sign-in callback."
            return
        }

        var components = URLComponents(
            url: rossBackendBaseURL().appendingPathComponent("auth/google/start"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [URLQueryItem(name: "redirectTarget", value: rossMobileAuthRedirectURL().absoluteString)]
        if let email = session?.email {
            queryItems.append(URLQueryItem(name: "loginHint", value: email))
        }
        components?.queryItems = queryItems

        guard let startURL = components?.url else {
            isStartingSignIn = false
            authErrorMessage = "Ross could not prepare sign-in."
            return
        }

        let authenticationSession = ASWebAuthenticationSession(
            url: startURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                self?.finishGoogleSignIn(callbackURL: callbackURL, error: error)
            }
        }
        authenticationSession.prefersEphemeralWebBrowserSession = false
        authenticationSession.presentationContextProvider = self
        webAuthenticationSession = authenticationSession

        if !authenticationSession.start() {
            webAuthenticationSession = nil
            isStartingSignIn = false
            authErrorMessage = "Ross could not open sign-in."
        }
    }

    func unlockSession() {
        guard case .unlockRequired(let pendingSession) = phase else { return }
        authErrorMessage = nil

        let context = LAContext()
        context.localizedFallbackTitle = "Use device passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            phase = .signedIn(pendingSession)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock Ross to access your local matters, files, and chats."
        ) { [weak self] success, evaluationError in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.authErrorMessage = nil
                    self.phase = .signedIn(pendingSession)
                } else if let evaluationError {
                    self.authErrorMessage = evaluationError.localizedDescription
                }
            }
        }
    }

    func signOut() {
        webAuthenticationSession?.cancel()
        webAuthenticationSession = nil
        store.clearSession()
        RossAuthSessionSnapshot.shared.update(nil)
        authErrorMessage = nil
        phase = .signedOut
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        guard scenePhase == .background else { return }
        guard case .signedIn(let session) = phase else { return }
        guard shouldRequireUnlock() else { return }
        phase = .unlockRequired(session)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return window
        }
        return ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }

    private func refreshedSessionIfNeeded(from session: RossAuthSession) async throws -> RossAuthSession {
        let refreshLeadTime: TimeInterval = 5 * 60
        guard session.expiresAt.timeIntervalSinceNow <= refreshLeadTime else {
            return session
        }

        var request = URLRequest(url: rossBackendBaseURL().appendingPathComponent("auth/session/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refreshToken": session.refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw NSError(domain: "RossAuthController", code: 401, userInfo: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(RossRefreshSessionPayload.self, from: data)
        let refreshedSession = RossAuthSession(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            accountToken: payload.accountToken,
            email: payload.profile?.email ?? session.email,
            displayName: payload.profile?.displayName ?? session.displayName,
            subject: payload.subject,
            expiresAt: payload.expiresAt
        )
        try store.saveSession(refreshedSession)
        return refreshedSession
    }

    private func finishGoogleSignIn(callbackURL: URL?, error: Error?) {
        defer {
            webAuthenticationSession = nil
            isStartingSignIn = false
        }

        if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
            return
        }

        if let error {
            authErrorMessage = error.localizedDescription
            return
        }

        guard let callbackURL else {
            authErrorMessage = "Ross did not receive a sign-in callback."
            return
        }

        let callbackItems = parseCallbackItems(from: callbackURL)
        if let errorTitle = callbackItems["error"] {
            let detail = callbackItems["error_description"]?.removingPercentEncoding
            authErrorMessage = [errorTitle, detail].compactMap { $0 }.joined(separator: ": ")
            return
        }

        guard
            let accessToken = callbackItems["access_token"],
            let refreshToken = callbackItems["refresh_token"],
            let accountToken = callbackItems["account_token"],
            let email = callbackItems["email"],
            let subject = callbackItems["subject"],
            let expiresAt = parseDate(from: callbackItems["expires_at"])
        else {
            authErrorMessage = "Ross received an incomplete sign-in response."
            return
        }

        let session = RossAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accountToken: accountToken,
            email: email,
            displayName: callbackItems["display_name"],
            subject: subject,
            expiresAt: expiresAt
        )

        do {
            try store.saveSession(session)
            RossAuthSessionSnapshot.shared.update(session)
            phase = .signedIn(session)
        } catch {
            authErrorMessage = "Ross could not save the local sign-in session."
        }
    }

    private func parseCallbackItems(from url: URL) -> [String: String] {
        var values: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                if let value = item.value {
                    values[item.name] = value
                }
            }
        }

        if let fragment = url.fragment,
           let fragmentComponents = URLComponents(string: "ross://fragment?\(fragment)") {
            fragmentComponents.queryItems?.forEach { item in
                if let value = item.value {
                    values[item.name] = value
                }
            }
        }

        return values
    }

    private func parseDate(from value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        if let seconds = TimeInterval(value) {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    private func shouldRequireUnlock() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    private func currentBiometryType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return context.biometryType
    }

    private func availableBiometryLabel() -> String? {
        switch currentBiometryType() {
        case .faceID:
            "Face ID"
        case .touchID:
            "Touch ID"
        default:
            nil
        }
    }
}

private struct RossAuthRootView: View {
    @Bindable var authController: RossAuthController

    var body: some View {
        Group {
            switch authController.phase {
            case .loading:
                RossLaunchSplashView()
            case .signedOut:
                RossSignInScreen(authController: authController)
            case .unlockRequired(let session):
                RossQuickUnlockScreen(authController: authController, session: session)
            case .signedIn:
                AlphaRossRootView(authController: authController)
            }
        }
        .task {
            await authController.loadIfNeeded()
        }
    }
}

private struct RossSignInScreen: View {
    @Bindable var authController: RossAuthController

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RossAuthBackdrop()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.size.height * 0.08, 42))

                    RossAuthHeroMark()

                    Spacer(minLength: 30)

                    Text("Private legal work. On this phone.")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.rossInk)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 0)

                    VStack(spacing: 16) {
                        if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        Button {
                            authController.startGoogleSignIn()
                        } label: {
                            Text(authController.isStartingSignIn ? "Opening sign-in…" : "Continue with Google")
                        }
                        .buttonStyle(RossAuthPrimaryButtonStyle())
                        .disabled(authController.isStartingSignIn)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct RossQuickUnlockScreen: View {
    @Bindable var authController: RossAuthController
    let session: RossAuthSession

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RossAuthBackdrop()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.size.height * 0.08, 42))

                    RossAuthHeroMark(size: 150, logoSize: 72)

                    Spacer(minLength: 26)

                    VStack(alignment: .center, spacing: 10) {
                        Text("Welcome back")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.rossInk)

                        Text(session.displayLabel)
                            .font(.headline.weight(.medium))
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)

                    if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 14) {
                        Button {
                            authController.unlockSession()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: authController.unlockSymbolName)
                                    .font(.system(size: 17, weight: .semibold))

                                Text(authController.unlockButtonTitle)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .buttonStyle(RossAuthPrimaryButtonStyle())

                        Button("Remove local sign-in") {
                            authController.signOut()
                        }
                        .buttonStyle(RossAuthTextButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct RossAuthHeroMark: View {
    var size: CGFloat = 172
    var logoSize: CGFloat = 82

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.rossAccent.opacity(0.92),
                            Color.rossAccent.opacity(0.42),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: size * 0.64
                    )
                )
                .frame(width: size * 1.08, height: size * 1.08)
                .blur(radius: 4)

            Circle()
                .fill(Color.rossGlassFill.opacity(0.92))
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.52), Color.rossGlassStroke.opacity(0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .shadow(color: Color.rossShadow.opacity(0.28), radius: 30, y: 18)
                .frame(width: size, height: size)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.86, height: size * 0.86)
                .offset(x: -14, y: -14)

            Image("RossLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .padding(size * 0.14)
                .background(Color.rossGlassSubtleFill.opacity(0.94), in: RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: Color.rossShadow.opacity(0.22), radius: 18, y: 10)
        }
    }
}

private struct RossAuthBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.rossHeroTop,
                    Color.rossGroupedBackground,
                    Color.rossHeroBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.rossBackdropGlow.opacity(0.95), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 540, height: 280)
                .rotationEffect(.degrees(-18))
                .blur(radius: 28)
                .offset(x: 60, y: -255)

            Circle()
                .fill(Color.rossAccent.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 52)
                .offset(x: 146, y: -230)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 72)
                .offset(x: -118, y: -108)
        }
        .ignoresSafeArea()
    }
}

private struct RossAuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.rossAccent.opacity(configuration.isPressed ? 0.78 : 0.96),
                                Color.rossAccent.opacity(configuration.isPressed ? 0.68 : 0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.34), Color.white.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1.4)
                    }
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color.rossAccent.opacity(configuration.isPressed ? 0.18 : 0.24), radius: configuration.isPressed ? 10 : 18, y: configuration.isPressed ? 6 : 12)
            .shadow(color: Color.rossShadow.opacity(configuration.isPressed ? 0.14 : 0.22), radius: configuration.isPressed ? 6 : 14, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct RossAuthTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.rossInk.opacity(configuration.isPressed ? 0.56 : 0.72))
            .padding(.vertical, 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

@MainActor
@main
struct RossApp: App {
    private let launchMode = RossLaunchMode.current
    @Environment(\.scenePhase) private var scenePhase
    @State private var authController = RossAuthController()

    var body: some Scene {
        WindowGroup {
            switch launchMode {
            case .interactive:
                RossAuthRootView(authController: authController)
                    .onChange(of: scenePhase) { _, newPhase in
                        authController.handleScenePhase(newPhase)
                    }
            case .screenshotExport:
                ScreenshotExportView()
            }
        }
    }
}
