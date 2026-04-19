import SwiftUI

struct PublicLawSearchPreviewView: View {
    let publicLawSearchService: any PublicLawSearchServicing
    let settingsStore: LocalSettingsStore
    @Bindable var state: AppState
    @State private var isRunningSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Ross removes your case details before any search goes online.", systemImage: "lock.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.75))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.rossSuccess.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What legal topic do you want to look up?")
                            .font(.headline)
                        TextEditor(text: $state.publicLawDraftText)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.rossSecondaryGroupedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Text("Ross automatically removes your case details before searching.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(22)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button(action: buildPreview) {
                        Text("Check before searching")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.bordered)

                    if let preview = state.publicLawPreview {
                        PublicLawPreviewCard(preview: preview)

                        Button(action: confirmSearch) {
                            if isRunningSearch {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text("Search now")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunningSearch)
                    }

                    if !state.publicLawResults.isEmpty {
                        PublicLawResultsCard(results: state.publicLawResults)
                    }
                }
                .padding(20)
            }
            .background(Color.rossGroupedBackground)
            .navigationTitle("Look up a law")
        }
    }

    private func buildPreview() {
        Task {
            let preview = await publicLawSearchService.buildPreview(
                for: state.publicLawDraftText,
                caseFile: state.selectedCase
            )

            await MainActor.run {
                state.publicLawPreview = preview
                state.publicLawResults = []
            }
        }
    }

    private func confirmSearch() {
        guard let preview = state.publicLawPreview else {
            return
        }

        isRunningSearch = true

        Task {
            let results = await publicLawSearchService.search(for: preview)

            await MainActor.run {
                state.publicLawResults = results
                isRunningSearch = false
            }
        }
    }
}

private struct PublicLawPreviewCard: View {
    let preview: SanitizedPublicQueryPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Public-law query to be sent")
                .font(.headline)

            Text(preview.publicQuery)
                .font(.body.weight(.medium))

            Text(preview.purpose)
                .foregroundStyle(.secondary)

            Label("Nothing from your case files will be sent.", systemImage: "checkmark.shield")
                .font(.footnote)
                .foregroundStyle(Color.rossSuccess)
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PublicLawResultsCard: View {
    let results: [PublicLawResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Results")
                .font(.headline)

            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.title)
                        .font(.subheadline.weight(.semibold))
                    Text(result.citation)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(result.snippet)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(result.sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
