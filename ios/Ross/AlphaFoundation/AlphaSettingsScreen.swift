import CryptoKit
import Observation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct AlphaSettingsScreen: View {
    @Bindable var model: AlphaRossModel
    let authController: RossAuthController?
    @State private var backendAddressDraft = rossBackendBaseURLOverride() ?? ""
    @State private var selectedLanguageCode = rossSelectedLanguageCode()
    @State private var languageExpanded = false
    @State private var appearanceExpanded = false
    @State private var storageExpanded = false
    private let languageOptions: [(String, String)] = [
        ("en", "English"),
        ("hi", "Hindi"),
        ("ta", "Tamil"),
        ("te", "Telugu"),
        ("kn", "Kannada"),
        ("ml", "Malayalam"),
        ("mr", "Marathi"),
        ("bn", "Bengali")
    ]

    var body: some View {
        let storageSnapshot = alphaStorageSnapshot(model)
        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                if let activeJob = alphaActiveSetupJob(model) {
                    NavigationLink(value: AlphaRoute.privateAISettings) {
                        AlphaAssistantActivityStrip(
                            title: alphaAssistantActivityTitle(for: activeJob),
                            detail: alphaAssistantActivityDetail(for: activeJob.state),
                            statusLabel: alphaAssistantStateLabel(activeJob.state),
                            tint: Color.rossAccent,
                            progressValue: alphaDownloadProgressValue(activeJob),
                            showsIndeterminateProgress: alphaDownloadShowsIndeterminateProgress(activeJob)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let authController, let session = authController.session {
                    RossSectionCard(title: "Account") {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaSettingsValueRow(label: "Signed in as", value: session.displayLabel)
                            Divider()
                            DisclosureGroup(isExpanded: $languageExpanded) {
                                AlphaSettingsLanguageGrid(
                                    options: languageOptions,
                                    selectedCode: $selectedLanguageCode
                                )
                                .padding(.top, 10)
                                .onChange(of: selectedLanguageCode) { _, newValue in
                                    rossSaveLanguageSelection(code: newValue)
                                }
                            } label: {
                                AlphaSettingsValueRow(label: "Language", value: rossLanguageDisplayName(code: selectedLanguageCode))
                            }
                            .tint(Color.rossAccent)
                            Divider()
                            if authController.canUseQuickUnlock {
                                Toggle(
                                    "Use device unlock",
                                    isOn: Binding(
                                        get: { authController.quickUnlockEnabled },
                                        set: { authController.setQuickUnlockEnabled($0) }
                                    )
                                )
                                .tint(Color.rossAccent)

                                Text(
                                    authController.quickUnlockEnabled
                                        ? "Ross asks for device unlock when you come back."
                                        : "Turn this on to reopen Ross with Face ID, Touch ID, or device passcode.",
                                    )
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.rossInk.opacity(0.78))
                            } else {
                                AlphaSettingsValueRow(label: "Unlock", value: "Quick unlock is not available on this device.")
                            }
                            Divider()
                            if session.subject.hasPrefix("local_demo_") {
                                Button {
                                    model.resetDemoWorkspace(for: session.subject)
                                } label: {
                                    AlphaSettingsNavigationRow(
                                        title: "Reset demo data",
                                        detail: "Restore the sample matter, tasks, files, and review items.",
                                        systemImage: "arrow.counterclockwise"
                                    )
                                }
                                .buttonStyle(.plain)

                                Text("Demo matter uses sample data only.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                Divider()
                            }
                            Button(role: .destructive, action: authController.signOut) {
                                HStack(spacing: 12) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .frame(width: 30, height: 30)
                                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                                    Text("Sign Out")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.rossInk)

                                    Spacer(minLength: 8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RossSectionCard(title: "Privacy") {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaSettingsValueRow(label: "Legal Search", value: "Review required")
                        Divider()
                        Text("Ross shows the Legal Search wording first. Matter files stay on this iPhone.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        NavigationLink(value: AlphaRoute.privacyLedger) {
                            AlphaSettingsNavigationRow(
                                title: "Activity Log",
                                detail: "Local work and Legal Search, separated.",
                                systemImage: "checklist"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                RossSectionCard(title: "Appearance") {
                    DisclosureGroup(isExpanded: $appearanceExpanded) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(AlphaAppearanceMode.allCases.enumerated()), id: \.element) { index, mode in
                                Button {
                                    model.updateSettings { settings in
                                        settings.appearanceMode = mode
                                    }
                                } label: {
                                    AlphaAppearanceOptionRow(
                                        mode: mode,
                                        isSelected: model.persisted.settings.appearanceMode == mode
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < AlphaAppearanceMode.allCases.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        AlphaSettingsValueRow(label: "Theme", value: model.persisted.settings.appearanceMode.title)
                    }
                    .tint(Color.rossAccent)
                }

                RossSectionCard(title: "Ross assistant") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(alphaPrivateAIStatus(model))
                            .font(.headline)
                            .foregroundStyle(Color.rossInk)

                        Text(alphaAssistantStatusSnapshot(model).detail)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        NavigationLink(value: AlphaRoute.privateAISettings) {
                            AlphaSettingsNavigationRow(
                                title: "Set up Ross assistant",
                                detail: "Use this when answers are unavailable or setup is paused.",
                                systemImage: "gearshape.2"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                RossSectionCard(title: "Storage") {
                    DisclosureGroup(isExpanded: $storageExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaSettingsValueRow(label: "Case files", value: "\(storageSnapshot.documentCount) • \(alphaFileSizeLabel(storageSnapshot.documentBytes))")
                            Divider()
                            AlphaSettingsValueRow(label: "Drafts", value: "\(storageSnapshot.exportCount) • \(alphaFileSizeLabel(storageSnapshot.exportBytes))")
                            Divider()
                            AlphaSettingsValueRow(label: "Assistant files", value: alphaFileSizeLabel(storageSnapshot.assistantBytes))
                            Divider()
                            Text("Stored on this iPhone unless you share it.")
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        }
                        .padding(.top, 10)
                    } label: {
                        AlphaSettingsValueRow(label: "Used on this iPhone", value: alphaFileSizeLabel(storageSnapshot.totalBytes))
                    }
                    .tint(Color.rossAccent)
                }

                RossSectionCard(title: "Help") {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaSettingsValueRow(label: "Start", value: "Add a matter, import a file, then ask Ross.")
                        Divider()
                        Text("For sharing, open Notes & Drafts and use the system share sheet.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                #if DEBUG
                RossSectionCard(title: "Advanced") {
                    DisclosureGroup("Technical diagnostics") {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaSettingsValueRow(label: "Assistant files", value: alphaFileSizeLabel(storageSnapshot.assistantBytes))
                            Divider()
                            AlphaSettingsValueRow(label: "Current server", value: rossBackendBaseURL().absoluteString)

                            TextField("http://127.0.0.1:8080", text: $backendAddressDraft)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.rossGroupedBackground)
                                )

                            Text("For internal testing only. iPhone Simulator usually uses 127.0.0.1, Android emulator uses 10.0.2.2, and a physical device needs your Mac's LAN IP.")
                                .font(.caption2)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                Button("Save test server") {
                                    let normalized = backendAddressDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    backendAddressDraft = normalized
                                    rossSetBackendBaseURLOverride(normalized)
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent)

                                Button("Use default address") {
                                    backendAddressDraft = ""
                                    rossSetBackendBaseURLOverride(nil)
                                }
                                .buttonStyle(.plain)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                            }
                        }
                        .padding(.top, 12)
                    }
                    .tint(Color.rossAccent)
                }
                #endif
            }
            .padding(alphaScreenPadding)
            .padding(.top, 56)
        }
        .rossHideNavigationBarIfSupported()
    }
}

struct AlphaSettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.7))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
}

struct AlphaAppearanceOptionRow: View {
    let mode: AlphaAppearanceMode
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(mode.detail)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.18))
        }
        .padding(.vertical, 10)
    }
}

struct AlphaSettingsNavigationRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.rossAccent)
                .frame(width: 30, height: 30)
                .background(Color.rossAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossInk.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct AlphaSettingsLanguageGrid: View {
    let options: [(String, String)]
    @Binding var selectedCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.0) { index, option in
                let code = option.0
                let label = option.1
                Button {
                    selectedCode = code
                } label: {
                    HStack(spacing: 12) {
                        Text(label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Spacer(minLength: 8)

                        Image(systemName: selectedCode == code ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selectedCode == code ? Color.rossAccent : Color.rossInk.opacity(0.18))
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Color.rossGlassSubtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
