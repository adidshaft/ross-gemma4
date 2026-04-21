import AuthenticationServices
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

    func currentSession() -> RossAuthSession? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSession
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

@MainActor
@Observable
final class RossAuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    @ObservationIgnored private let store = RossAuthSessionStore()
    @ObservationIgnored private var webAuthenticationSession: ASWebAuthenticationSession?
    @ObservationIgnored private let isoFormatter = ISO8601DateFormatter()
    private var didLoad = false

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
        if let biometryLabel = availableBiometryLabel() {
            return "\(biometryLabel) or device passcode"
        }
        return "Device passcode"
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

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        do {
            guard let session = try store.loadSession() else {
                RossAuthSessionSnapshot.shared.update(nil)
                phase = .signedOut
                return
            }

            RossAuthSessionSnapshot.shared.update(session)
            if shouldRequireUnlock() {
                phase = .unlockRequired(session)
            } else {
                phase = .signedIn(session)
            }
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
            authErrorMessage = "Ross could not prepare the Google sign-in request."
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
            authErrorMessage = "Ross could not open Google sign-in."
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
            localizedReason: "Unlock Ross to access your matters and chats."
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
            authController.loadIfNeeded()
        }
    }
}

private struct RossSignInScreen: View {
    @Bindable var authController: RossAuthController

    private let featureColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RossAuthBackdrop()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        RossAuthWordmark()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Private case work, signed in once")
                                .font(.system(size: 31, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.rossInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Google is only used for your session. Matters, files, and chats stay on this phone.")
                                .font(.title3)
                                .foregroundStyle(Color.rossInk.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        LazyVGrid(columns: featureColumns, alignment: .leading, spacing: 12) {
                            RossInfoPill(title: "Google session only", systemImage: "person.crop.circle.badge.checkmark")
                            RossInfoPill(title: "Files stay local", systemImage: "lock")
                            RossInfoPill(title: "Quick unlock on return", systemImage: "faceid")
                        }

                        if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        Spacer(minLength: 10)

                        Button {
                            authController.startGoogleSignIn()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .semibold))

                                Text(authController.isStartingSignIn ? "Opening Google…" : "Sign in with Google")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .buttonStyle(RossAuthPrimaryButtonStyle())
                        .disabled(authController.isStartingSignIn)
                    }
                    .frame(
                        minHeight: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom,
                        alignment: .top
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
                }
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

                VStack(alignment: .leading, spacing: 22) {
                    RossAuthWordmark()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome back")
                            .font(.system(size: 31, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.rossInk)

                        Text(session.displayLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)

                        Text("Unlock Ross with \(authController.quickUnlockSummary.lowercased()) to open your local matters, files, and chats.")
                            .font(.title3)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Spacer(minLength: 0)

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

                    Button("Sign out") {
                        authController.signOut()
                    }
                    .buttonStyle(RossAuthSecondaryButtonStyle())
                }
                .frame(
                    minHeight: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom,
                    alignment: .top
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
            }
        }
    }
}

private struct RossAuthWordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("RossLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(4)
                .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.rossShadow.opacity(0.45), radius: 10, y: 4)

            Text("ROSS")
                .font(.caption.weight(.bold))
                .tracking(2.4)
                .foregroundStyle(Color.rossAccent)
        }
    }
}

private struct RossAuthBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.rossGroupedBackground,
                    Color.rossSecondaryGroupedBackground,
                    Color.rossGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.rossBackdropGlow, Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 340
            )
            .offset(x: -30, y: -90)

            Circle()
                .fill(Color.rossAccent.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: 120, y: 240)
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
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.rossAccent.opacity(configuration.isPressed ? 0.82 : 0.94),
                                Color.rossAccent.opacity(configuration.isPressed ? 0.72 : 0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.rossGlassStroke.opacity(0.46), lineWidth: 1)
            }
            .shadow(color: Color.rossShadow.opacity(configuration.isPressed ? 0.18 : 0.28), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct RossAuthSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Color.rossInk.opacity(configuration.isPressed ? 0.72 : 0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.rossGlassFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.rossGlassStroke.opacity(0.86), lineWidth: 1)
            }
            .shadow(color: Color.rossShadow.opacity(configuration.isPressed ? 0.12 : 0.2), radius: configuration.isPressed ? 6 : 12, y: configuration.isPressed ? 3 : 7)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

@MainActor
@main
struct RossApp: App {
    private let launchMode = RossLaunchMode.current
    @State private var authController = RossAuthController()

    var body: some Scene {
        WindowGroup {
            switch launchMode {
            case .interactive:
                RossAuthRootView(authController: authController)
            case .screenshotExport:
                ScreenshotExportView()
            }
        }
    }
}
