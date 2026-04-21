import AuthenticationServices
import Foundation
import LocalAuthentication
import Security
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Language Preference

private let rossLanguageSelectedKey = "ross.language.selected"
private let rossSelectedLanguageCodeKey = "ross.language.code"

func rossHasSelectedLanguage() -> Bool {
    UserDefaults.standard.bool(forKey: rossLanguageSelectedKey)
}

func rossSaveLanguageSelection(code: String) {
    UserDefaults.standard.set(true, forKey: rossLanguageSelectedKey)
    UserDefaults.standard.set(code, forKey: rossSelectedLanguageCodeKey)
}

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
    var hasSelectedLanguage: Bool = rossHasSelectedLanguage()

    func markLanguageSelected(code: String) {
        rossSaveLanguageSelection(code: code)
        hasSelectedLanguage = true
    }

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
                if authController.hasSelectedLanguage {
                    RossSignInScreen(authController: authController)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    RossLanguageSelectionScreen(authController: authController)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            case .unlockRequired(let session):
                RossQuickUnlockScreen(authController: authController, session: session)
            case .signedIn:
                AlphaRossRootView(authController: authController)
            }
        }
        .animation(.easeInOut(duration: 0.38), value: authController.hasSelectedLanguage)
        .task {
            await authController.loadIfNeeded()
        }
    }
}

// MARK: - Language Selection Screen

private struct RossLanguageOption: Identifiable {
    let id: String  // language code
    let nativeName: String
    let englishName: String
    let flag: String
}

private let rossLanguageOptions: [RossLanguageOption] = [
    RossLanguageOption(id: "en", nativeName: "English", englishName: "English", flag: "🇬🇧"),
    RossLanguageOption(id: "hi", nativeName: "हिन्दी", englishName: "Hindi", flag: "🇮🇳"),
    RossLanguageOption(id: "ta", nativeName: "தமிழ்", englishName: "Tamil", flag: "🇮🇳"),
    RossLanguageOption(id: "te", nativeName: "తెలుగు", englishName: "Telugu", flag: "🇮🇳"),
    RossLanguageOption(id: "kn", nativeName: "ಕನ್ನಡ", englishName: "Kannada", flag: "🇮🇳"),
    RossLanguageOption(id: "ml", nativeName: "മലയാളം", englishName: "Malayalam", flag: "🇮🇳"),
    RossLanguageOption(id: "mr", nativeName: "मराठी", englishName: "Marathi", flag: "🇮🇳"),
    RossLanguageOption(id: "bn", nativeName: "বাংলা", englishName: "Bengali", flag: "🇮🇳"),
]

private struct RossLanguageSelectionScreen: View {
    @Bindable var authController: RossAuthController
    @State private var selectedCode: String? = nil
    @State private var appeared = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RossAuthBackdrop()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            RossAuthHeroMark(size: 62)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ROSS")
                                    .font(.system(size: 14, weight: .semibold))
                                    .tracking(3.4)
                                    .foregroundStyle(Color.rossAccent)

                                Text("Set your starting language")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Color.rossInk.opacity(0.78))
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.top, max(proxy.safeAreaInsets.top + 12, 28))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -10)

                        RossAuthGlassPanel(cornerRadius: 34, padding: 20) {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Choose your language")
                                        .font(.system(size: 38, weight: .light))
                                        .tracking(-1.6)
                                        .foregroundStyle(Color.rossInk)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("Ross starts here. You can change it later in Settings.")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color.rossInk.opacity(0.64))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(Array(rossLanguageOptions.enumerated()), id: \.element.id) { index, option in
                                        RossLanguageTile(
                                            option: option,
                                            isSelected: selectedCode == option.id
                                        ) {
                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                                selectedCode = option.id
                                            }
                                        }
                                        .opacity(appeared ? 1 : 0)
                                        .offset(y: appeared ? 0 : 12)
                                        .animation(
                                            .spring(response: 0.48, dampingFraction: 0.82).delay(Double(index) * 0.04 + 0.08),
                                            value: appeared
                                        )
                                    }
                                }
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                        Button {
                            guard let code = selectedCode else { return }
                            authController.markLanguageSelected(code: code)
                        } label: {
                            Text("Continue")
                        }
                        .rossPrimaryButtonStyle()
                        .disabled(selectedCode == nil)
                        .opacity(selectedCode == nil ? 0.48 : 1)
                        .animation(.easeOut(duration: 0.18), value: selectedCode == nil)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 24))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}

private struct RossLanguageTile: View {
    let option: RossLanguageOption
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(option.nativeName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.rossInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(option.englishName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(
                        isSelected
                            ? Color.white.opacity(0.78)
                            : Color.rossInk.opacity(0.56)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(.horizontal, 16)
            .background {
                if isSelected {
                    shape
                        .fill(Color.rossPillGradient.opacity(colorScheme == .dark ? 0.88 : 1))
                        .background(.thinMaterial, in: shape)
                        .shadow(color: Color.rossAccent.opacity(0.24), radius: 12, y: 8)
                } else {
                    shape
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.18))
                        .background(.ultraThinMaterial, in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            isSelected
                                ? Color.white.opacity(0.32)
                                : Color.white.opacity(colorScheme == .dark ? 0.08 : 0.34),
                            isSelected
                                ? Color.white.opacity(0.12)
                                : Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.26 : 0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .scaleEffect(isSelected ? 1.01 : 1)
        }
        .buttonStyle(.plain)
    }
}

private struct RossSignInScreen: View {
    @Bindable var authController: RossAuthController
    @State private var appeared = false

    private var anyAuthInProgress: Bool {
        authController.isStartingSignIn
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RossAuthBackdrop()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            RossAuthHeroMark(size: 62)

                            Text("ROSS")
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(3.6)
                                .foregroundStyle(Color.rossAccent)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, max(proxy.safeAreaInsets.top + 12, 28))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -10)

                        RossAuthGlassPanel(cornerRadius: 36, padding: 24) {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Private legal work.\nOn this phone.")
                                    .font(.system(size: 46, weight: .light))
                                    .tracking(-1.8)
                                    .foregroundStyle(Color.rossInk)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Sign in once and keep every matter, file, and chat on this device.")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(Color.rossInk.opacity(0.66))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                        HStack(spacing: 12) {
                            RossAuthFeatureTile(
                                icon: .lock,
                                variant: .highlight,
                                fallbackSystemImage: "lock.fill",
                                title: "Files stay local",
                                detail: "Matters, files, and chats stay on this device."
                            )

                            RossAuthFeatureTile(
                                icon: .gearKeyhole,
                                variant: .accent,
                                fallbackSystemImage: "faceid",
                                title: "Quick unlock",
                                detail: "Use Face ID, Touch ID, or your passcode when you return."
                            )
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                        if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                            RossAuthGlassPanel(cornerRadius: 24, padding: 14) {
                                HStack(alignment: .top, spacing: 10) {
                                    RossGlassIconView(
                                        .triangleWarning,
                                        variant: .highlight,
                                        size: 16,
                                        fallbackSystemImage: "exclamationmark.triangle.fill"
                                    )

                                    Text(errorMessage)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Button {
                            authController.startGoogleSignIn()
                        } label: {
                            HStack(spacing: 12) {
                                RossGlassIconView(.earth, variant: .highlight, size: 18, fallbackSystemImage: "globe")
                                    .frame(width: 22, height: 22)

                                Text(authController.isStartingSignIn ? "Opening secure sign-in..." : "Continue with Google")
                                    .frame(maxWidth: .infinity, alignment: .center)

                                Color.clear
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .rossPrimaryButtonStyle()
                        .disabled(anyAuthInProgress)
                        .opacity(anyAuthInProgress ? 0.82 : 1)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 20, 32))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.68, dampingFraction: 0.84)) {
                appeared = true
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            RossAuthHeroMark(size: 62)

                            Text("ROSS")
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(3.6)
                                .foregroundStyle(Color.rossAccent)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, max(proxy.safeAreaInsets.top + 12, 28))

                        RossAuthGlassPanel(cornerRadius: 36, padding: 24) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Welcome back")
                                    .font(.system(size: 44, weight: .light))
                                    .tracking(-1.4)
                                    .foregroundStyle(Color.rossInk)

                                Text(session.displayLabel)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.rossInk.opacity(0.76))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(authController.quickUnlockSummary)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color.rossInk.opacity(0.6))
                            }
                        }

                        if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                            RossAuthGlassPanel(cornerRadius: 24, padding: 14) {
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Button {
                            authController.unlockSession()
                        } label: {
                            HStack(spacing: 12) {
                                RossGlassIconView(.gearKeyhole, variant: .accent, size: 18, fallbackSystemImage: authController.unlockSymbolName)
                                    .frame(width: 22, height: 22)

                                Text(authController.unlockButtonTitle)
                                    .frame(maxWidth: .infinity, alignment: .center)

                                Color.clear
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .rossPrimaryButtonStyle()

                        Button("Remove local sign-in") {
                            authController.signOut()
                        }
                        .buttonStyle(RossAuthTextButtonStyle())
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 20, 32))
                }
            }
        }
    }
}

private struct RossAuthHeroMark: View {
    var size: CGFloat = 132

    var body: some View {
        Image("RossLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.white.opacity(0.12), radius: 12, y: -2)
            .shadow(color: Color.rossShadow.opacity(0.2), radius: 24, y: 16)
    }
}

struct RossAuthBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0.04, green: 0.06, blue: 0.09),
                        Color(red: 0.08, green: 0.09, blue: 0.14),
                        Color(red: 0.07, green: 0.05, blue: 0.11)
                    ]
                    : [
                        Color(red: 0.74, green: 0.88, blue: 0.92),
                        Color(red: 0.93, green: 0.96, blue: 0.97),
                        Color(red: 0.88, green: 0.88, blue: 0.84)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                Color(red: 0.22, green: 0.43, blue: 0.64).opacity(0.42),
                                Color.clear
                            ]
                            : [
                                Color.white.opacity(0.74),
                                Color.clear
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 620, height: 320)
                .rotationEffect(.degrees(-18))
                .blur(radius: 34)
                .offset(x: -40, y: -260)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [
                                Color(red: 0.54, green: 0.42, blue: 0.82).opacity(0.22),
                                Color.clear
                            ]
                            : [
                                Color(red: 0.96, green: 0.82, blue: 0.65).opacity(0.34),
                                Color.clear
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 48)
                .offset(x: 170, y: 250)

            Circle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.26))
                .frame(width: 320, height: 320)
                .blur(radius: 76)
                .offset(x: 148, y: -210)
        }
        .ignoresSafeArea()
    }
}

private struct RossAuthGlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background {
                shape
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.26))
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.36),
                                        Color.white.opacity(colorScheme == .dark ? 0.04 : 0.14),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.48),
                            Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.28 : 0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.rossShadow.opacity(colorScheme == .dark ? 0.32 : 0.14),
                radius: colorScheme == .dark ? 18 : 28,
                y: colorScheme == .dark ? 10 : 18
            )
    }
}

private struct RossAuthFeatureTile: View {
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let fallbackSystemImage: String
    let title: String
    let detail: String

    var body: some View {
        RossAuthGlassPanel(cornerRadius: 26, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    RossGlassIconView(icon, variant: variant, size: 16, fallbackSystemImage: fallbackSystemImage)
                }
                .frame(width: 34, height: 34)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
