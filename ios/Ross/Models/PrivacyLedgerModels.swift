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
            "Local only"
        case .entitlementDelivery:
            "Entitlement and delivery"
        case .modelDelivery:
            "Model delivery"
        case .publicLaw:
            "Public-law search"
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
            "Local only"
        case .noCaseData:
            "No case data"
        case .accountToken:
            "Account token"
        case .sanitizedPublicQuery:
            "Sanitized public query"
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
            title: "Local indexing pass completed",
            detail: "Document indexing stayed on-device and refreshed the case workspace.",
            boundary: .localOnly,
            dataClass: .localOnly,
            direction: .onDevice
        ),
        PrivacyLedgerEntry(
            timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: .now) ?? .now,
            title: "Model catalog checked",
            detail: "Pack availability was checked without sending case materials.",
            boundary: .entitlementDelivery,
            dataClass: .noCaseData,
            direction: .outbound
        ),
        PrivacyLedgerEntry(
            timestamp: Calendar.current.date(byAdding: .minute, value: -35, to: .now) ?? .now,
            title: "Prior public-law search cached",
            detail: "A sanitized public query returned citations and snippets for later local review.",
            boundary: .publicLaw,
            dataClass: .sanitizedPublicQuery,
            direction: .inbound
        )
    ]
}
