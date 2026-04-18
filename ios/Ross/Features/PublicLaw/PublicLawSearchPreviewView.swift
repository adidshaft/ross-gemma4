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
                    PublicLawBoundaryCard(requireApproval: settingsStore.settings.requirePublicLawApproval)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prepare a public-law query")
                            .font(.headline)
                        TextEditor(text: $state.publicLawDraftText)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.rossSecondaryGroupedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Text("Never send case identifiers, filenames, OCR text, or chat history.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(22)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button(action: buildPreview) {
                        Text("Generate Query Preview")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)

                    if let preview = state.publicLawPreview {
                        PublicLawPreviewCard(preview: preview)

                        Button(action: confirmSearch) {
                            if isRunningSearch {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text("Run Public-Law Search")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunningSearch)
                    }

                    if !state.publicLawResults.isEmpty {
                        PublicLawResultsCard(results: state.publicLawResults)
                    }
                }
                .padding(20)
            }
            .background(Color.rossGroupedBackground)
            .navigationTitle("Public-Law Search")
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

private struct PublicLawBoundaryCard: View {
    let requireApproval: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Public boundary")
                .font(.headline)
            Text("Public-law search is optional and distinct from private case work.")
                .foregroundStyle(.secondary)
            Text(requireApproval ? "Approval is required before every query leaves the device." : "Approval is currently relaxed in settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PublicLawPreviewCard: View {
    let preview: SanitizedPublicQueryPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sanitized query preview")
                .font(.headline)

            Text(preview.publicQuery)
                .font(.body.weight(.medium))

            Text(preview.purpose)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Removed before network")
                    .font(.subheadline.weight(.semibold))
                ForEach(preview.removedElements, id: \.self) { removed in
                    Label(removed, systemImage: "minus.circle")
                        .font(.footnote)
                }
            }

            Text(preview.confirmationNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
            Text("Preview results")
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
