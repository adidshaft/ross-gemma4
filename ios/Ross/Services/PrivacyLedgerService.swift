import Foundation
import Observation

@MainActor
@Observable
final class PrivacyLedgerService {
    private(set) var entries: [PrivacyLedgerEntry]

    init(seed: [PrivacyLedgerEntry] = []) {
        entries = seed.sorted { $0.timestamp > $1.timestamp }
    }

    func recordLocal(title: String, detail: String) {
        record(
            PrivacyLedgerEntry(
                timestamp: Date(),
                title: title,
                detail: detail,
                boundary: .localOnly,
                dataClass: .localOnly,
                direction: .onDevice
            )
        )
    }

    func recordNetwork(
        title: String,
        detail: String,
        boundary: PrivacyBoundaryKind,
        dataClass: PrivacyDataClass,
        direction: PrivacyDirection
    ) {
        record(
            PrivacyLedgerEntry(
                timestamp: Date(),
                title: title,
                detail: detail,
                boundary: boundary,
                dataClass: dataClass,
                direction: direction
            )
        )
    }

    private func record(_ entry: PrivacyLedgerEntry) {
        entries.insert(entry, at: 0)
    }
}
