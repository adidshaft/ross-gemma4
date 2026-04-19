import Foundation

enum PrivacyBoundaryKind: String, CaseIterable, Hashable, Identifiable, Sendable {
    case localOnly
    case entitlementDelivery
    case modelDelivery
    case publicLaw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localOnly:
            "Stayed on phone"
        case .entitlementDelivery:
            "Account check"
        case .modelDelivery:
            "App setup"
        case .publicLaw:
            "Law search only"
        }
    }
}

enum PrivacyDataClass: String, Hashable, Sendable {
    case localOnly
    case noCaseData
    case accountToken
    case sanitizedPublicQuery

    var title: String {
        switch self {
        case .localOnly:
            "On this phone"
        case .noCaseData:
            "No case details"
        case .accountToken:
            "Account token"
        case .sanitizedPublicQuery:
            "Law topic only"
        }
    }
}

enum PrivacyDirection: String, Hashable, Sendable {
    case onDevice
    case outbound
    case inbound

    var title: String {
        switch self {
        case .onDevice:
            "On device"
        case .outbound:
            "Outbound"
        case .inbound:
            "Inbound"
        }
    }
}

struct PrivacyLedgerEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String
    let boundary: PrivacyBoundaryKind
    let dataClass: PrivacyDataClass
    let direction: PrivacyDirection

    init(
        id: UUID = UUID(),
        timestamp: Date,
        title: String,
        detail: String,
        boundary: PrivacyBoundaryKind,
        dataClass: PrivacyDataClass,
        direction: PrivacyDirection
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.boundary = boundary
        self.dataClass = dataClass
        self.direction = direction
    }
}

extension PrivacyLedgerEntry {
    static let seedEntries: [PrivacyLedgerEntry] = [
        PrivacyLedgerEntry(
            timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now,
            title: "Reviewed case files on this phone",
            detail: "Ross checked your documents on this device and refreshed the case workspace.",
            boundary: .localOnly,
            dataClass: .localOnly,
            direction: .onDevice
        ),
        PrivacyLedgerEntry(
            timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: .now) ?? .now,
            title: "Checked assistant availability",
            detail: "Ross checked setup availability without sending case materials.",
            boundary: .entitlementDelivery,
            dataClass: .noCaseData,
            direction: .outbound
        ),
        PrivacyLedgerEntry(
            timestamp: Calendar.current.date(byAdding: .minute, value: -35, to: .now) ?? .now,
            title: "Looked up a law",
            detail: "Ross returned public-law references without sending anything from your case files.",
            boundary: .publicLaw,
            dataClass: .sanitizedPublicQuery,
            direction: .inbound
        )
    ]
}
