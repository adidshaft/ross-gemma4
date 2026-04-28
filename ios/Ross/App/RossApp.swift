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
private let rossQuickUnlockEnabledKey = "ross.quick_unlock.enabled"
private let rossBackendBaseURLOverrideKey = "ross.backend.base_url.override"

func rossHasSelectedLanguage() -> Bool {
    UserDefaults.standard.bool(forKey: rossLanguageSelectedKey)
}

func rossSaveLanguageSelection(code: String) {
    UserDefaults.standard.set(true, forKey: rossLanguageSelectedKey)
    UserDefaults.standard.set(code, forKey: rossSelectedLanguageCodeKey)
}

func rossSelectedLanguageCode() -> String {
    UserDefaults.standard.string(forKey: rossSelectedLanguageCodeKey) ?? "en"
}

func rossLanguageDisplayName(code: String) -> String {
    switch code {
    case "en": "English"
    case "hi": "Hindi"
    case "ta": "Tamil"
    case "te": "Telugu"
    case "kn": "Kannada"
    case "ml": "Malayalam"
    case "mr": "Marathi"
    case "bn": "Bengali"
    default: code.uppercased()
    }
}

func rossQuickUnlockEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: rossQuickUnlockEnabledKey)
}

func rossSetQuickUnlockEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: rossQuickUnlockEnabledKey)
}

func rossBackendBaseURLOverride() -> String? {
    let normalized = UserDefaults.standard.string(forKey: rossBackendBaseURLOverrideKey)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return (normalized?.isEmpty == false) ? normalized : nil
}

func rossSetBackendBaseURLOverride(_ rawValue: String?) {
    guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !normalized.isEmpty else {
        UserDefaults.standard.removeObject(forKey: rossBackendBaseURLOverrideKey)
        return
    }
    UserDefaults.standard.set(normalized, forKey: rossBackendBaseURLOverrideKey)
}

private func rossAuthTopHeaderPadding(_ safeAreaTop: CGFloat) -> CGFloat {
    max(safeAreaTop - 14, 14)
}

private enum RossEmailAccessWorkspace: Equatable {
    case demo
    case fresh
}

private struct RossEmailAccessProfile: Identifiable {
    var id: String { email }
    let email: String
    let displayName: String
    let subject: String
    let title: String
    let detail: String
    let workspace: RossEmailAccessWorkspace
}

private let rossEmailAccessProfiles: [RossEmailAccessProfile] = [
    RossEmailAccessProfile(
        email: "advocate@ross.ai",
        displayName: "Advocate Ross",
        subject: "local_demo_advocate",
        title: "Try sample matter",
        detail: "Opens one sample case.",
        workspace: .demo
    ),
    RossEmailAccessProfile(
        email: "fresh@ross.ai",
        displayName: "Fresh Ross Account",
        subject: "local_fresh_default",
        title: "Start empty",
        detail: "Creates a clean workspace.",
        workspace: .fresh
    )
]

private func rossEmailAccessProfile(for email: String) -> RossEmailAccessProfile? {
    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return rossEmailAccessProfiles.first { $0.email == normalized }
}

func rossBackendBaseURL() -> URL {
    let environment = ProcessInfo.processInfo.environment
    let rawURL = rossBackendBaseURLOverride()
        ?? environment["ROSS_BACKEND_BASE_URL"]
        ?? environment["ROSS_BACKEND_URL"]
        ?? "http://127.0.0.1:8080"
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

fileprivate enum RossExternalSignInProvider: Equatable {
    case google
    case apple
}

private enum RossUnlockTrigger {
    case automatic
    case manual
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
final class RossAuthController: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    @ObservationIgnored private let store = RossAuthSessionStore()
    @ObservationIgnored private var webAuthenticationSession: ASWebAuthenticationSession?
    @ObservationIgnored private var appleAuthorizationController: ASAuthorizationController?
    @ObservationIgnored private let isoFormatter = ISO8601DateFormatter()
    @ObservationIgnored private let canEvaluateDeviceUnlock: () -> Bool
    @ObservationIgnored private let biometryTypeProvider: () -> LABiometryType
    @ObservationIgnored private let evaluateDeviceUnlock: (_ localizedReason: String, _ completion: @escaping @Sendable (Bool, Error?) -> Void) -> Void
    @ObservationIgnored private var pendingQuickRelockSession: RossAuthSession?
    @ObservationIgnored private var pendingAutomaticUnlock = false
    @ObservationIgnored private var didLoad = false

    var phase: RossAuthPhase = .loading
    fileprivate var activeExternalProvider: RossExternalSignInProvider?
    var authErrorMessage: String?
    var hasSelectedLanguage: Bool = rossHasSelectedLanguage()
    var quickUnlockEnabled: Bool = rossQuickUnlockEnabled()
    var privacyShieldVisible = false
    var isUnlocking = false

    override init() {
        self.canEvaluateDeviceUnlock = RossAuthController.defaultCanEvaluateDeviceUnlock
        self.biometryTypeProvider = RossAuthController.defaultBiometryType
        self.evaluateDeviceUnlock = RossAuthController.defaultEvaluateDeviceUnlock
        super.init()
    }

    init(
        canEvaluateDeviceUnlock: @escaping () -> Bool,
        biometryTypeProvider: @escaping () -> LABiometryType,
        evaluateDeviceUnlock: @escaping (_ localizedReason: String, _ completion: @escaping @Sendable (Bool, Error?) -> Void) -> Void
    ) {
        self.canEvaluateDeviceUnlock = canEvaluateDeviceUnlock
        self.biometryTypeProvider = biometryTypeProvider
        self.evaluateDeviceUnlock = evaluateDeviceUnlock
        super.init()
    }

    var isStartingSignIn: Bool {
        activeExternalProvider != nil
    }

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

    var canUseQuickUnlock: Bool {
        shouldRequireUnlock()
    }

    private func setSignedIn(_ session: RossAuthSession) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            phase = .signedIn(session)
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
            phase = quickUnlockEnabled && shouldRequireUnlock() ? .unlockRequired(activeSession) : .signedIn(activeSession)
            if case .unlockRequired = phase {
                privacyShieldVisible = true
                pendingAutomaticUnlock = true
                attemptAutomaticUnlockIfNeeded()
            } else {
                clearUnlockPresentationState()
            }
        } catch {
            store.clearSession()
            RossAuthSessionSnapshot.shared.update(nil)
            clearUnlockPresentationState()
            phase = .signedOut
            authErrorMessage = nil
        }
    }

    func startGoogleSignIn() {
        guard activeExternalProvider == nil else { return }
        authErrorMessage = nil
        activeExternalProvider = .google

        guard let callbackScheme = rossMobileAuthRedirectURL().scheme else {
            activeExternalProvider = nil
            authErrorMessage = "Could not sign in. Please try again."
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
            activeExternalProvider = nil
            authErrorMessage = "Could not sign in. Please try again."
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
            activeExternalProvider = nil
            authErrorMessage = "Could not sign in. Please try again."
        }
    }

    func startAppleSignIn() {
        guard activeExternalProvider == nil else { return }
        authErrorMessage = nil
        activeExternalProvider = .apple

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        appleAuthorizationController = controller
        controller.performRequests()
    }

    func signInWithEmailAccess(_ email: String) {
        authErrorMessage = nil

        guard let profile = rossEmailAccessProfile(for: email) else {
            authErrorMessage = "Use advocate@ross.ai for demo or fresh@ross.ai for a fresh workspace."
            return
        }

        let session = RossAuthSession(
            accessToken: "local_access_\(profile.subject)",
            refreshToken: "local_refresh_\(profile.subject)",
            accountToken: "local_account_\(profile.subject)",
            email: profile.email,
            displayName: profile.displayName,
            subject: profile.subject,
            expiresAt: Date().addingTimeInterval(3600 * 24 * 365)
        )

        try? store.saveSession(session)
        RossAuthSessionSnapshot.shared.update(session)
        clearUnlockPresentationState()
        setSignedIn(session)
    }

    func unlockSession() {
        startUnlock(trigger: .manual)
    }

    func signOut() {
        webAuthenticationSession?.cancel()
        webAuthenticationSession = nil
        appleAuthorizationController = nil
        activeExternalProvider = nil
        store.clearSession()
        RossAuthSessionSnapshot.shared.update(nil)
        clearUnlockPresentationState()
        authErrorMessage = nil
        phase = .signedOut
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            if let pendingQuickRelockSession {
                phase = .unlockRequired(pendingQuickRelockSession)
                self.pendingQuickRelockSession = nil
            }

            if case .unlockRequired = phase {
                privacyShieldVisible = true
                attemptAutomaticUnlockIfNeeded()
            } else {
                privacyShieldVisible = false
            }
        case .inactive:
            guard quickUnlockEnabled, shouldRequireUnlock(), session != nil else { return }
            privacyShieldVisible = true
            authErrorMessage = nil
        case .background:
            guard quickUnlockEnabled, shouldRequireUnlock(), case .signedIn(let session) = phase else { return }
            pendingQuickRelockSession = session
            pendingAutomaticUnlock = true
            privacyShieldVisible = true
            authErrorMessage = nil
        @unknown default:
            break
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        activePresentationAnchor()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        activePresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer {
            appleAuthorizationController = nil
            activeExternalProvider = nil
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        let displayName = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackAlias = "apple-\(credential.user.prefix(6))@local.ross"

        let session = RossAuthSession(
            accessToken: "apple_local_access_\(credential.user)",
            refreshToken: "apple_local_refresh_\(credential.user)",
            accountToken: "apple_local_account_\(credential.user)",
            email: credential.email ?? fallbackAlias,
            displayName: displayName.isEmpty ? "Apple profile" : displayName,
            subject: "apple_\(credential.user)",
            expiresAt: Date().addingTimeInterval(3600 * 24 * 365)
        )

        do {
            try store.saveSession(session)
            RossAuthSessionSnapshot.shared.update(session)
            clearUnlockPresentationState()
            authErrorMessage = nil
            setSignedIn(session)
        } catch {
            authErrorMessage = "Could not sign in. Please try again."
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        defer {
            appleAuthorizationController = nil
            activeExternalProvider = nil
        }

        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }

        authErrorMessage = "Could not sign in. Please try again."
    }

    private func activePresentationAnchor() -> ASPresentationAnchor {
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

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return session
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw NSError(domain: "RossAuthController", code: httpResponse.statusCode, userInfo: nil)
                }
                return session
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
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .timedOut,
                 .dnsLookupFailed:
                return session
            default:
                throw error
            }
        }
    }

    private func finishGoogleSignIn(callbackURL: URL?, error: Error?) {
        defer {
            webAuthenticationSession = nil
            activeExternalProvider = nil
        }

        if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
            return
        }

        if error != nil {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        guard let callbackURL else {
            authErrorMessage = "Could not sign in. Please try again."
            return
        }

        let callbackItems = parseCallbackItems(from: callbackURL)
        if callbackItems["error"] != nil {
            authErrorMessage = "Could not sign in. Please try again."
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
            authErrorMessage = "Could not sign in. Please try again."
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
            setSignedIn(session)
        } catch {
            authErrorMessage = "Could not sign in. Please try again."
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
        canEvaluateDeviceUnlock()
    }

    func setQuickUnlockEnabled(_ enabled: Bool) {
        quickUnlockEnabled = enabled
        rossSetQuickUnlockEnabled(enabled)
        guard !enabled else { return }
        pendingQuickRelockSession = nil
        pendingAutomaticUnlock = false
        privacyShieldVisible = false
        isUnlocking = false
        authErrorMessage = nil
        if case .unlockRequired(let session) = phase {
            setSignedIn(session)
        }
    }

    private func currentBiometryType() -> LABiometryType {
        biometryTypeProvider()
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

    private func attemptAutomaticUnlockIfNeeded() {
        guard pendingAutomaticUnlock else { return }
        guard case .unlockRequired = phase else { return }
        guard !isUnlocking else { return }
        pendingAutomaticUnlock = false
        startUnlock(trigger: .automatic)
    }

    private func startUnlock(trigger: RossUnlockTrigger) {
        guard case .unlockRequired(let pendingSession) = phase else { return }
        guard !isUnlocking else { return }

        authErrorMessage = nil
        privacyShieldVisible = true
        isUnlocking = true

        guard shouldRequireUnlock() else {
            isUnlocking = false
            privacyShieldVisible = false
            authErrorMessage = "Quick unlock is not available on this device."
            return
        }

        evaluateDeviceUnlock(
            "Unlock Ross to access your local matters, files, and chats."
        ) { [weak self] success, evaluationError in
            Task { @MainActor [weak self] in
                self?.finishUnlockAttempt(
                    success: success,
                    evaluationError: evaluationError,
                    session: pendingSession,
                    trigger: trigger
                )
            }
        }
    }

    private func finishUnlockAttempt(
        success: Bool,
        evaluationError: Error?,
        session: RossAuthSession,
        trigger: RossUnlockTrigger
    ) {
        isUnlocking = false

        guard case .unlockRequired = phase else {
            privacyShieldVisible = false
            return
        }

        if success {
            authErrorMessage = nil
            pendingQuickRelockSession = nil
            pendingAutomaticUnlock = false
            privacyShieldVisible = false
            setSignedIn(session)
            return
        }

        let errorCode = localAuthenticationErrorCode(from: evaluationError)
        switch errorCode {
        case .appCancel, .systemCancel, .notInteractive:
            pendingAutomaticUnlock = true
            privacyShieldVisible = true
            authErrorMessage = nil
        case .userCancel, .userFallback:
            privacyShieldVisible = false
            authErrorMessage = nil
        case .authenticationFailed:
            privacyShieldVisible = false
            authErrorMessage = "Could not confirm your identity. Try again."
        case .biometryLockout:
            privacyShieldVisible = false
            authErrorMessage = "Use your device passcode to continue."
        case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
            privacyShieldVisible = false
            authErrorMessage = "Quick unlock is not available on this device."
        default:
            privacyShieldVisible = false
            authErrorMessage = trigger == .manual ? "Could not unlock. Please try again." : nil
        }

        phase = .unlockRequired(session)
    }

    private func clearUnlockPresentationState() {
        pendingQuickRelockSession = nil
        pendingAutomaticUnlock = false
        privacyShieldVisible = false
        isUnlocking = false
    }

    private func localAuthenticationErrorCode(from error: Error?) -> LAError.Code? {
        if let localAuthenticationError = error as? LAError {
            return localAuthenticationError.code
        }

        let nsError = error as NSError?
        guard nsError?.domain == LAError.errorDomain,
              let rawCode = nsError?.code,
              let code = LAError.Code(rawValue: rawCode) else {
            return nil
        }
        return code
    }

    private static func defaultCanEvaluateDeviceUnlock() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    private static func defaultBiometryType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return context.biometryType
    }

    private static func defaultEvaluateDeviceUnlock(
        localizedReason: String,
        completion: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        let context = LAContext()
        context.localizedFallbackTitle = "Use device passcode"
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: localizedReason,
            reply: completion
        )
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
                        .transition(.opacity)
                } else {
                    RossLanguageSelectionScreen(authController: authController)
                        .transition(.opacity)
                }
            case .unlockRequired, .signedIn:
                RossAuthenticatedShell(authController: authController)
            }
        }
        .transaction { transaction in
            if case .signedIn = authController.phase {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .animation(.easeOut(duration: 0.18), value: authController.hasSelectedLanguage)
        .task {
            await authController.loadIfNeeded()
        }
    }
}

private struct RossAuthenticatedShell: View {
    @Bindable var authController: RossAuthController

    private var lockedSession: RossAuthSession? {
        if case .unlockRequired(let session) = authController.phase {
            return session
        }
        return nil
    }

    private var requiresWorkspaceShield: Bool {
        authController.privacyShieldVisible || authController.isUnlocking || lockedSession != nil
    }

    var body: some View {
        ZStack {
            AlphaRossRootView(authController: authController)
                .allowsHitTesting(!requiresWorkspaceShield)

            if requiresWorkspaceShield {
                RossWorkspacePrivacyShield(isUnlocking: authController.isUnlocking)
            }

            if let lockedSession, !authController.isUnlocking {
                RossQuickUnlockScreen(
                    authController: authController,
                    session: lockedSession
                )
            }
        }
    }
}

private struct RossWorkspacePrivacyShield: View {
    let isUnlocking: Bool

    var body: some View {
        ZStack {
            RossAuthBackdrop()

            VStack(spacing: 12) {
                RossAuthHeroMark(size: 54)

                if isUnlocking {
                    ProgressView()
                        .tint(Color.rossAccent)
                        .scaleEffect(1.02)

                    Text("Unlocking Ross")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                } else {
                    Text("Workspace locked")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                }
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Language Selection Screen

private struct RossLanguageOption: Identifiable {
    let id: String  // language code
    let nativeName: String
    let englishName: String
}

private let rossLanguageOptions: [RossLanguageOption] = [
    RossLanguageOption(id: "en", nativeName: "English", englishName: "English"),
    RossLanguageOption(id: "hi", nativeName: "हिन्दी", englishName: "Hindi"),
    RossLanguageOption(id: "ta", nativeName: "தமிழ்", englishName: "Tamil"),
    RossLanguageOption(id: "te", nativeName: "తెలుగు", englishName: "Telugu"),
    RossLanguageOption(id: "kn", nativeName: "ಕನ್ನಡ", englishName: "Kannada"),
    RossLanguageOption(id: "ml", nativeName: "മലയാളം", englishName: "Malayalam"),
    RossLanguageOption(id: "mr", nativeName: "मराठी", englishName: "Marathi"),
    RossLanguageOption(id: "bn", nativeName: "বাংলা", englishName: "Bengali"),
]

private struct RossLanguageSelectionScreen: View {
    @Bindable var authController: RossAuthController
    @State private var selectedCode: String? = nil

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            RossAuthHeroMark(size: 62)

                            Text("ROSS")
                                .font(.system(size: 15, weight: .bold))
                                .tracking(3.8)
                                .foregroundStyle(Color.rossAccent)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, rossAuthTopHeaderPadding(proxy.safeAreaInsets.top))

                        RossAuthGlassPanel(cornerRadius: 20, padding: 18) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Choose your preferred language")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.rossInk)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Ross can answer in this language where supported.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)

                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(rossLanguageOptions) { option in
                                        RossLanguageTile(
                                            option: option,
                                            isSelected: selectedCode == option.id
                                        ) {
                                            withAnimation(.easeOut(duration: 0.14)) {
                                                selectedCode = option.id
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 144)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                }
            }
            .background {
                RossAuthBackdrop()
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
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

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
                            ? Color.white.opacity(0.82)
                            : Color.rossInk.opacity(0.7)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background {
                if isSelected {
                    shape
                        .fill(Color.rossPillGradient.opacity(colorScheme == .dark ? 0.88 : 1))
                        .background(.thinMaterial, in: shape)
                        .shadow(color: Color.rossAccent.opacity(0.24), radius: 12, y: 8)
                } else {
                    shape
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.22))
                        .background(.ultraThinMaterial, in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            isSelected
                                ? Color.white.opacity(0.32)
                                : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.38),
                            isSelected
                                ? Color.white.opacity(0.12)
                                : Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.34 : 0.72)
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
    @State private var emailAccessAddress = "advocate@ross.ai"
    @State private var signInCardExpanded = false
    @State private var emailOptionExpanded = false

    private var reservedSheetHeight: CGFloat {
        if emailOptionExpanded {
            return 430
        }
        return signInCardExpanded ? 274 : 128
    }

    var body: some View {
        GeometryReader { proxy in
            let heroPanelWidth = min(proxy.size.width - 24, 430)
            let signInPanelWidth = min(proxy.size.width - 24, 440)
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 14) {
                        RossAuthHeroMark(size: 58)

                        Text("ROSS")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(3.6)
                            .foregroundStyle(Color.rossAccent)

                        Spacer(minLength: 0)
                    }
                        .padding(.top, rossAuthTopHeaderPadding(proxy.safeAreaInsets.top))

                    RossAuthGlassPanel(cornerRadius: 24, padding: 22, forcedWidth: heroPanelWidth) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Private legal work.\nOn this phone.")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundStyle(Color.rossInk.opacity(0.96))
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Your matters stay private on this device.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.rossInk.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.bottom, reservedSheetHeight)

                VStack {
                    Spacer(minLength: 0)

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        RossAuthSignInSheet(
                            authController: authController,
                            emailAddress: $emailAccessAddress,
                            isExpanded: $signInCardExpanded,
                            isEmailExpanded: $emailOptionExpanded,
                            panelWidth: signInPanelWidth,
                            bottomInset: proxy.safeAreaInsets.bottom
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .background {
                RossAuthBackdrop()
            }
        }
        .onChange(of: authController.authErrorMessage) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                signInCardExpanded = true
            }
        }
    }
}

private struct RossAuthSignInSheet: View {
    @Bindable var authController: RossAuthController
    @Binding var emailAddress: String
    @Binding var isExpanded: Bool
    @Binding var isEmailExpanded: Bool
    let panelWidth: CGFloat
    let bottomInset: CGFloat

    private var externalSignInDisabled: Bool {
        authController.isStartingSignIn
    }

    private var selectedEmailProfile: RossEmailAccessProfile? {
        rossEmailAccessProfile(for: emailAddress)
    }

    var body: some View {
        RossAuthGlassPanel(cornerRadius: 24, padding: 18, forcedWidth: panelWidth) {
            VStack(alignment: .leading, spacing: isExpanded ? 14 : 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .center, spacing: 8) {
                        RossAuthSheetCue(isExpanded: isExpanded)

                        VStack(spacing: 4) {
                            Text(isExpanded ? "Sign in" : "Get Started")
                                .font(.system(size: isExpanded ? 19 : 24, weight: isExpanded ? .semibold : .semibold))
                                .foregroundStyle(Color.rossInk)
                                .multilineTextAlignment(.center)

                            Text(isExpanded ? "Start with a demo or your account." : "Tap to sign in.")
                                .font(.system(size: isExpanded ? 13 : 14, weight: .regular))
                                .foregroundStyle(Color.rossInk.opacity(0.62))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        if isEmailExpanded {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Email access")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.rossInk)

                                    Spacer(minLength: 10)

                                    Button {
                                        withAnimation(.easeOut(duration: 0.16)) {
                                            isEmailExpanded = false
                                        }
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.rossInk.opacity(0.72))
                                            .frame(width: 30, height: 30)
                                            .background(Color.white.opacity(0.1), in: Circle())
                                            .overlay {
                                                Circle()
                                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Back")
                                }

                                VStack(spacing: 8) {
                                    ForEach(rossEmailAccessProfiles) { profile in
                                        RossEmailAccessPresetRow(
                                            profile: profile,
                                            isSelected: selectedEmailProfile?.id == profile.id
                                        ) {
                                            emailAddress = profile.email
                                        }
                                    }
                                }

                                RossAuthInputField(
                                    title: "Email",
                                    text: $emailAddress,
                                    placeholder: "advocate@ross.ai",
                                    iconSystemName: "envelope.fill",
                                    onSubmit: {
                                        authController.signInWithEmailAccess(emailAddress)
                                    }
                                )

                                Text("Use the sample matter or enter your email.")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    authController.signInWithEmailAccess(emailAddress)
                                } label: {
                                    RossAuthActionLabel(
                                        title: "Continue",
                                        tone: .secondary
                                    ) {
                                        RossGlassIconView(.userMsg, variant: .neutral, size: 17, fallbackSystemImage: "envelope.fill")
                                    }
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 20)
                            }
                            .transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    authController.startGoogleSignIn()
                                } label: {
                                    RossAuthActionLabel(
                                        title: authController.activeExternalProvider == .google ? "Connecting to Google" : "Continue with Google",
                                        tone: .secondary
                                    ) {
                                        RossGoogleMark(size: 17)
                                    }
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 20)
                                .disabled(externalSignInDisabled)
                                .opacity(externalSignInDisabled && authController.activeExternalProvider != .google ? 0.78 : 1)

                                Button {
                                    authController.startAppleSignIn()
                                } label: {
                                    RossAuthActionLabel(
                                        title: authController.activeExternalProvider == .apple ? "Connecting to Apple" : "Continue with Apple",
                                        tone: .secondary
                                    ) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .rossGlassButtonStyle(cornerRadius: 20)
                                .disabled(externalSignInDisabled)
                                .opacity(externalSignInDisabled && authController.activeExternalProvider != .apple ? 0.78 : 1)

                                Button {
                                    authController.authErrorMessage = nil
                                    withAnimation(.easeOut(duration: 0.16)) {
                                        isEmailExpanded = true
                                    }
                                } label: {
                                    RossAuthActionLabel(
                                        title: "Continue with email",
                                        subtitle: "Sample matter or empty workspace",
                                        tone: .secondary
                                    ) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                }
                                .rossGlassButtonStyle(cornerRadius: 20)

                                Text("Demo data is sample only.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            RossGlassIconView(
                                .triangleWarning,
                                variant: .highlight,
                                size: 16,
                                fallbackSystemImage: "exclamationmark.triangle.fill"
                            )

                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(red: 0.63, green: 0.37, blue: 0.17))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.96, green: 0.67, blue: 0.38).opacity(0.14))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(red: 0.84, green: 0.55, blue: 0.28).opacity(0.34), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.bottom, max(bottomInset - 2, 12))
            .animation(.easeOut(duration: 0.16), value: isExpanded)
            .animation(.easeOut(duration: 0.16), value: isEmailExpanded)
        }
    }
}

private struct RossAuthSheetCue: View {
    let isExpanded: Bool
    @State private var pulse = false

    var body: some View {
        Image(systemName: isExpanded ? "chevron.down" : "arrow.up")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.rossInk.opacity(isExpanded ? 0.46 : (pulse ? 0.76 : 0.32)))
            .frame(width: 28, height: 18)
            .onAppear {
                guard !isExpanded else { return }
                withAnimation(.easeInOut(duration: 0.74).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: isExpanded) { _, expanded in
                pulse = false
                guard !expanded else { return }
                withAnimation(.easeInOut(duration: 0.74).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

private enum RossAuthActionTone {
    case primary
    case secondary
}

private struct RossEmailAccessPresetRow: View {
    let profile: RossEmailAccessProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: profile.workspace == .demo ? "briefcase.fill" : "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.44))
                    .frame(width: 24, height: 24)
                    .background(
                        (isSelected ? Color.rossAccent.opacity(0.12) : Color.white.opacity(0.12)),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(profile.detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.rossInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.26))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                (isSelected ? Color.rossAccent.opacity(0.08) : Color.white.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.rossAccent.opacity(0.2) : Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RossAuthActionLabel<Icon: View>: View {
    let title: String
    let subtitle: String?
    let tone: RossAuthActionTone
    let icon: Icon

    init(
        title: String,
        subtitle: String? = nil,
        tone: RossAuthActionTone,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone == .primary ? Color.white : Color.rossInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            tone == .primary
                                ? Color.white.opacity(0.76)
                                : Color.rossInk.opacity(0.58)
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RossAuthNotice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rossInk.opacity(0.62))
                .frame(width: 18, height: 18)

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.rossSecondaryGroupedBackground.opacity(0.68))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.72), lineWidth: 1)
        }
    }
}

private struct RossGoogleMark: View {
    let size: CGFloat

    init(size: CGFloat = 18) {
        self.size = size
    }

    var body: some View {
        Text("G")
            .font(.system(size: size * 1.02, weight: .bold, design: .rounded))
            .foregroundStyle(
                AngularGradient(
                    colors: [
                        Color(red: 0.26, green: 0.52, blue: 0.96),
                        Color(red: 0.20, green: 0.66, blue: 0.33),
                        Color(red: 0.98, green: 0.74, blue: 0.18),
                        Color(red: 0.92, green: 0.26, blue: 0.21),
                        Color(red: 0.26, green: 0.52, blue: 0.96)
                    ],
                    center: .center
                )
            )
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.92), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.rossGlassStroke.opacity(0.72), lineWidth: 1)
            }
    }
}

private struct RossQuickUnlockScreen: View {
    @Bindable var authController: RossAuthController
    let session: RossAuthSession
    @State private var showingSignOutConfirmation = false

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(proxy.size.width - 32, 390)

            VStack(spacing: 22) {
                Spacer(minLength: max(proxy.safeAreaInsets.top + 18, 48))

                RossAuthHeroMark(size: 72)

                RossAuthGlassPanel(cornerRadius: 20, padding: 18, forcedWidth: panelWidth) {
                    VStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 6) {
                            Text("Ross is locked")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color.rossInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Text("Use \(authController.quickUnlockSummary) to continue.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.68))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(session.displayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.rossSecondaryGroupedBackground.opacity(0.82), in: Capsule())

                        if let errorMessage = authController.authErrorMessage, !errorMessage.isEmpty {
                            RossAuthNotice(text: errorMessage)
                        }

                        Button {
                            authController.unlockSession()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: authController.unlockSymbolName)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(authController.unlockButtonTitle)
                            }
                        }
                        .rossPrimaryButtonStyle()

                        Button("Sign out") {
                            showingSignOutConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                    }
                }

                Spacer(minLength: max(proxy.safeAreaInsets.bottom + 18, 48))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
        .alert("Sign out of Ross?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                authController.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local sign-in from this device until you sign in again.")
        }
    }
}

struct RossAuthHeroMark: View {
    var size: CGFloat = 132

    var body: some View {
        Image("RossLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Color.rossBackdropGlow.opacity(0.18), radius: 12, y: -2)
            .shadow(color: Color.rossShadow.opacity(0.2), radius: 24, y: 16)
    }
}

struct RossAuthBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

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

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.rossBackdropGlow.opacity(colorScheme == .dark ? 0.36 : 0.48),
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
                        colors: [
                            Color.rossHighlight.opacity(colorScheme == .dark ? 0.16 : 0.14),
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
                .fill(Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.12 : 0.28))
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
    let forcedWidth: CGFloat?
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 24,
        forcedWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.forcedWidth = forcedWidth
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .frame(width: forcedWidth, alignment: .leading)
            .background {
                shape
                    .fill(Color.rossGlassFill.opacity(colorScheme == .dark ? 0.9 : 0.78))
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.rossBackdropGlow.opacity(colorScheme == .dark ? 0.12 : 0.22),
                                        Color.rossGlassSubtleFill.opacity(colorScheme == .dark ? 0.12 : 0.18),
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

private struct RossAuthInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let iconSystemName: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.rossInk.opacity(0.6))

            HStack(spacing: 12) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.44))
                    .frame(width: 18, height: 18)

                TextField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.rossInk)
                    .rossEmailFieldInputBehavior()
                    .focused($isFocused)
                    .onSubmit(onSubmit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused
                            ? Color.white.opacity(0.42)
                            : Color.white.opacity(0.18),
                        lineWidth: 1
                    )
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func rossEmailFieldInputBehavior() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .submitLabel(.done)
        #else
        self
        #endif
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
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            authController.handleScenePhase(newPhase)
                        }
                    }
            case .screenshotExport:
                ScreenshotExportView()
            case .localModelSmoke:
                RossLocalModelSmokeView()
            }
        }
    }
}
