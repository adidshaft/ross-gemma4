import Foundation

protocol ModelCatalogProviding: Sendable {
    func availablePacks() async -> [ModelPack]
}

struct FixtureModelCatalogService: ModelCatalogProviding {
    func availablePacks() async -> [ModelPack] {
        .fixtureCatalog
    }
}
