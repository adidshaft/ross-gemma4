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

let alphaSettingsAssistantStorageLabel = "Assistant setup"
let alphaSettingsAssistantStorageSupportLabel = "Assistant setup files"

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
                    RossSectionCard(title: rossLocalized("account")) {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaSettingsValueRow(label: rossLocalized("signed_in_as"), value: session.displayLabel)
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
                                AlphaSettingsValueRow(label: rossLocalized("language"), value: rossLanguageDisplayName(code: selectedLanguageCode))
                            }
                            .tint(Color.rossAccent)
                            Divider()
                            if authController.canUseQuickUnlock {
                                Toggle(
                                    rossLocalized("use_device_unlock"),
                                    isOn: Binding(
                                        get: { authController.quickUnlockEnabled },
                                        set: { authController.setQuickUnlockEnabled($0) }
                                    )
                                )
                                .tint(Color.rossAccent)

                                Text(
                                    authController.quickUnlockEnabled
                                        ? rossLocalized("device_unlock_enabled_detail")
                                        : rossLocalized("device_unlock_disabled_detail"),
                                    )
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.rossInk.opacity(0.78))
                            } else {
                                AlphaSettingsValueRow(label: rossLocalized("unlock"), value: rossLocalized("quick_unlock_unavailable_detail"))
                            }
                            Divider()
                            if session.subject.hasPrefix("local_demo_") {
                                Button {
                                    model.resetDemoWorkspace(for: session.subject)
                                } label: {
                                    AlphaSettingsNavigationRow(
                                        title: rossLocalized("reset_demo_data"),
                                        detail: rossLocalized("reset_demo_data_detail"),
                                        systemImage: "arrow.counterclockwise"
                                    )
                                }
                                .buttonStyle(.plain)

                                Text(rossLocalized("demo_matter_sample_data_only"))
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
                                        .rossNativeGlassSurface(
                                            tint: .red,
                                            shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                                            fallbackFillOpacity: 0.70,
                                            fallbackStrokeOpacity: 0.38
                                        )

                                    Text(rossLocalized("sign_out_destructive"))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.rossInk)

                                    Spacer(minLength: 8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RossSectionCard(title: rossLocalized("settings_privacy")) {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaSettingsValueRow(label: rossLocalized("legal_search"), value: rossLocalized("review_required"))
                        Divider()
                        Text(rossLocalized("settings_privacy_detail"))
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        NavigationLink(value: AlphaRoute.privacyLedger) {
                            AlphaSettingsNavigationRow(
                                title: rossLocalized("activity_log"),
                                detail: rossLocalized("activity_log_detail"),
                                systemImage: "checklist"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                RossSectionCard(title: rossLocalized("settings_appearance")) {
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
                        AlphaSettingsValueRow(label: rossLocalized("theme"), value: model.persisted.settings.appearanceMode.title)
                    }
                    .tint(Color.rossAccent)
                }

                RossSectionCard(title: rossLocalized("my_assistant")) {
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
                                title: rossLocalized("open_my_assistant"),
                                detail: rossLocalized("open_my_assistant_detail"),
                                systemImage: "gearshape.2"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                RossSectionCard(title: rossLocalized("ross_routines")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(rossLocalized("ross_routines_detail"))
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        AlphaRoutineToggleRow(title: rossLocalized("morning_brief"), detail: rossLocalized("morning_brief_detail"), isOn: Binding(
                            get: { model.routineSettings.morningBriefEnabled },
                            set: { value in model.updateRoutineSettings { $0.morningBriefEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: rossLocalized("after_document_import"), detail: rossLocalized("after_document_import_detail"), isOn: Binding(
                            get: { model.routineSettings.afterDocumentImportEnabled },
                            set: { value in model.updateRoutineSettings { $0.afterDocumentImportEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: rossLocalized("before_hearing"), detail: rossLocalized("before_hearing_detail"), isOn: Binding(
                            get: { model.routineSettings.beforeHearingEnabled },
                            set: { value in model.updateRoutineSettings { $0.beforeHearingEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: rossLocalized("missing_facts_scan"), detail: rossLocalized("missing_facts_scan_detail"), isOn: Binding(
                            get: { model.routineSettings.missingFactsScanEnabled },
                            set: { value in model.updateRoutineSettings { $0.missingFactsScanEnabled = value } }
                        ))
                        Divider()
                        AlphaRoutineToggleRow(title: rossLocalized("draft_refresh"), detail: rossLocalized("draft_refresh_detail"), isOn: Binding(
                            get: { model.routineSettings.draftRefreshEnabled },
                            set: { value in model.updateRoutineSettings { $0.draftRefreshEnabled = value } }
                        ))
                        Divider()
                        AlphaSettingsValueRow(label: rossLocalized("public_law_search"), value: rossLocalized("approval_required"))
                        Text(rossLocalized("public_law_search_detail"))
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                RossSectionCard(title: rossLocalized("storage")) {
                    DisclosureGroup(isExpanded: $storageExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaSettingsValueRow(label: rossLocalized("case_files"), value: "\(storageSnapshot.documentCount) • \(alphaFileSizeLabel(storageSnapshot.documentBytes))")
                            Divider()
                            AlphaSettingsValueRow(label: rossLocalized("drafts"), value: "\(storageSnapshot.exportCount) • \(alphaFileSizeLabel(storageSnapshot.exportBytes))")
                            Divider()
                            AlphaSettingsValueRow(label: alphaSettingsAssistantStorageLabel, value: alphaFileSizeLabel(storageSnapshot.assistantBytes))
                            Divider()
                            Text(rossLocalized("stored_on_phone_unless_shared"))
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        }
                        .padding(.top, 10)
                    } label: {
                        AlphaSettingsValueRow(label: rossLocalized("used_on_this_iphone"), value: alphaFileSizeLabel(storageSnapshot.totalBytes))
                    }
                    .tint(Color.rossAccent)
                }

                RossSectionCard(title: rossLocalized("help")) {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaSettingsValueRow(label: rossLocalized("start"), value: rossLocalized("help_start_detail"))
                        Divider()
                        Text(rossLocalized("help_sharing_detail"))
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                #if DEBUG
                RossSectionCard(title: rossLocalized("settings_advanced")) {
                    DisclosureGroup(rossLocalized("settings_support_details")) {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaSettingsValueRow(label: alphaSettingsAssistantStorageSupportLabel, value: alphaFileSizeLabel(storageSnapshot.assistantBytes))
                            Divider()
                            AlphaSettingsValueRow(label: rossLocalized("settings_current_server"), value: rossBackendBaseURL().absoluteString)

                            TextField("http://127.0.0.1:8080", text: $backendAddressDraft)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .rossNativeGlassSurface(
                                    tint: Color.rossAccent,
                                    shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                                    interactive: true,
                                    fallbackFillOpacity: 0.84,
                                    fallbackStrokeOpacity: 0.46
                                )
                                .shadow(color: Color.rossShadow.opacity(0.04), radius: 4, y: 1)

                            Text(rossLocalized("settings_test_server_detail"))
                                .font(.caption2)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)

                            RossGlassGroup(spacing: 10) {
                                HStack(spacing: 10) {
                                    Button(rossLocalized("settings_save_test_server")) {
                                        let normalized = backendAddressDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                        backendAddressDraft = normalized
                                        rossSetBackendBaseURLOverride(normalized)
                                    }
                                    .rossGlassButtonStyle(tint: Color.rossAccent)

                                    Button(rossLocalized("settings_use_default_address")) {
                                        backendAddressDraft = ""
                                        rossSetBackendBaseURLOverride(nil)
                                    }
                                    .rossGlassButtonStyle(tint: Color.rossHighlight, expandsHorizontally: false)
                                }
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
                .rossNativeGlassSurface(
                    tint: Color.rossAccent,
                    shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    fallbackFillOpacity: 0.70,
                    fallbackStrokeOpacity: 0.38
                )

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
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            interactive: true,
            fallbackFillOpacity: 0.80,
            fallbackStrokeOpacity: 0.46
        )
        .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
    }
}
