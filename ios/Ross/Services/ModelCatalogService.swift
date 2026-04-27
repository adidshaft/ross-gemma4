import Foundation

protocol ModelCatalogProviding: Sendable {
    func availablePacks() async -> [ModelPack]
}
