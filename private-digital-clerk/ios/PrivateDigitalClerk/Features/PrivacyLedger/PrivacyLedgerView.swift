import SwiftUI

private enum LedgerFilter: String, CaseIterable, Identifiable {
    case all
    case localOnly
    case modelDelivery
    case entitlement
    case publicLaw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .localOnly:
            "Local"
        case .modelDelivery:
            "Model"
        case .entitlement:
            "Delivery"
        case .publicLaw:
            "Public law"
        }
    }
}

struct PrivacyLedgerView: View {
    @Bindable var privacyLedger: PrivacyLedgerService
    @State private var selectedFilter: LedgerFilter = .all

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(LedgerFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    ForEach(filteredEntries) { entry in
                        PrivacyLedgerRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Privacy Ledger")
        }
    }

    private var filteredEntries: [PrivacyLedgerEntry] {
        switch selectedFilter {
        case .all:
            return privacyLedger.entries
        case .localOnly:
            return privacyLedger.entries.filter { $0.boundary == .localOnly }
        case .modelDelivery:
            return privacyLedger.entries.filter { $0.boundary == .modelDelivery }
        case .entitlement:
            return privacyLedger.entries.filter { $0.boundary == .entitlementDelivery }
        case .publicLaw:
            return privacyLedger.entries.filter { $0.boundary == .publicLaw }
        }
    }
}

private struct PrivacyLedgerRow: View {
    let entry: PrivacyLedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.boundary.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(entry.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Label(entry.dataClass.title, systemImage: "lock")
                Spacer()
                Text(entry.direction.title)
                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
