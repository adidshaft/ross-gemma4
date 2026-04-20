import SwiftUI

// MARK: - Case Switcher Sheet (tapping the nav title chevron)

struct CaseSwitcherSheet: View {
    let caseFiles: [CaseFile]
    let selectedCaseID: CaseFile.ID?
    let onSelect: (CaseFile.ID) -> Void

    var body: some View {
        NavigationStack {
            List(caseFiles) { caseFile in
                Button { onSelect(caseFile.id) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(caseFile.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                                .lineLimit(1)
                            Text("\(caseFile.forum) · \(caseFile.stage.title)")
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.5))
                        }

                        Spacer()

                        if let hearing = caseFile.nextHearing {
                            Text(hearing.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.rossAccent)
                        } else {
                            Text("—")
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.3))
                        }

                        if caseFile.id == selectedCaseID {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.rossAccent)
                                .padding(.leading, 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Open matters")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
