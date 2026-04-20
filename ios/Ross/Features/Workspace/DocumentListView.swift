import SwiftUI

// MARK: - Document List (pushed from Cases or More)

struct DocumentListView: View {
    let documents: [CaseDocument]

    var body: some View {
        List(documents) { document in
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.rossInk)
                    Text("\(document.category) · \(document.pageCount) pages")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.45))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Image(systemName: document.isIndexedLocally ? "checkmark.circle.fill" : "clock")
                        .font(.subheadline)
                        .foregroundStyle(
                            document.isIndexedLocally
                                ? Color.rossSuccess
                                : Color.rossInk.opacity(0.3)
                        )
                    if !document.isIndexedLocally {
                        Text("Not yet read")
                            .font(.caption2)
                            .foregroundStyle(Color.rossHighlight)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .navigationTitle("Documents")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
