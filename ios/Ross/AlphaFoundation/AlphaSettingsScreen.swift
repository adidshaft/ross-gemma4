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
    private let languageOptions = rossLanguageOptions

    var body: some View {
        let storageSnapshot = alphaStorageSnapshot(model)
        ScrollView {
            RossGlassGroup(spacing: alphaSectionSpacing) {
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

                RossSectionCard(title: "My assistant") {
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
                                title: "Open My assistant",
                                detail: "Use this when answers are unavailable or setup is paused.",
                                systemImage: "gearshape.2"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                RossSectionCard(title: "Ross Routines") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Routines run locally from saved matters, files, dates, tasks, drafts, and accepted corrections.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        AlphaRoutineToggleRow(title: "Morning brief", detail: "On app open, once per day.", isOn: Binding(
                            get: { model.routineSettings.morningBriefEnabled },
                            set: { value in model.updateRoutineSettings { $0.morningBriefEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: "After document import", detail: "Update case memory and review items after extraction.", isOn: Binding(
                            get: { model.routineSettings.afterDocumentImportEnabled },
                            set: { value in model.updateRoutineSettings { $0.afterDocumentImportEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: "Before hearing", detail: "Prepare checklist, missing facts, and hearing note prompt.", isOn: Binding(
                            get: { model.routineSettings.beforeHearingEnabled },
                            set: { value in model.updateRoutineSettings { $0.beforeHearingEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: "Missing facts scan", detail: "Find gaps and weak support in source-backed matter memory.", isOn: Binding(
                            get: { model.routineSettings.missingFactsScanEnabled },
                            set: { value in model.updateRoutineSettings { $0.missingFactsScanEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: "Draft refresh", detail: "Refresh local drafts from latest files and corrections.", isOn: Binding(
                            get: { model.routineSettings.draftRefreshEnabled },
                            set: { value in model.updateRoutineSettings { $0.draftRefreshEnabled = value } }
                        ))
                        Divider()
                        AlphaSettingsValueRow(label: "Public-law search", value: "Approval required")
                        Text("Ross may prepare a sanitized query preview. It must not search the web until you approve it.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
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
                    DisclosureGroup("Support details") {
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
            }
            .padding(alphaScreenPadding)
            .padding(.top, 56)
        }
        .rossHideNavigationBarIfSupported()
    }
}

struct AlphaRoutineToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color.rossAccent)
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
    let options: [RossLanguageOption]
    @Binding var selectedCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    selectedCode = option.id
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.nativeName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rossInk)

                            if option.nativeName != option.englishName {
                                Text(option.englishName)
                                    .font(.caption2)
                                    .foregroundStyle(Color.rossInk.opacity(0.62))
                            }
                        }

                        Spacer(minLength: 8)

                        Image(systemName: selectedCode == option.id ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selectedCode == option.id ? Color.rossAccent : Color.rossInk.opacity(0.18))
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
        .rossGlassSurface(cornerRadius: 16, interactive: true, shadowOpacity: 0.07, shadowRadius: 7, shadowY: 3, fillOpacity: 0.8, strokeOpacity: 0.46)
    }
}
