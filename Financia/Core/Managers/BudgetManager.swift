import Foundation
import Combine
import SwiftData

@MainActor
class BudgetManager: ObservableObject {
    static let shared = BudgetManager()

    @Published var categories: [BudgetCategory] = []
    @Published var presets: [BudgetAllocationPreset] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/budget-categories/"

    private init() {
        loadFromCache()
        loadPresetsFromCache()
        Task { await refreshFromBackend() }
    }

    // MARK: - Backend sync

    func refreshFromBackend() async {
        do {
            let items: [BudgetCategory] = try await api.getList(endpoint)
            categories = items
            replaceCache(with: items)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addCategory(_ category: BudgetCategory) {
        categories.append(category)
        insertCache(category)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await api.post(endpoint, body: category)
            } catch {
                categories.removeAll { $0.id == category.id }
                deleteCache(id: category.id)
                lastError = error.localizedDescription
            }
        }
    }

    func updateCategory(_ category: BudgetCategory) {
        guard let i = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let previous = categories[i]
        categories[i] = category
        insertCache(category)
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: Empty = try await api.put("\(endpoint)\(category.id.uuidString)", body: category)
            } catch {
                if let j = categories.firstIndex(where: { $0.id == previous.id }) {
                    categories[j] = previous
                    insertCache(previous)
                }
                lastError = error.localizedDescription
            }
        }
    }

    func deleteCategory(_ category: BudgetCategory) {
        categories.removeAll { $0.id == category.id }
        deleteCache(id: category.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await api.delete("\(endpoint)\(category.id.uuidString)")
            } catch {
                categories.append(category)
                insertCache(category)
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Presets (local only)

    func addPreset(_ preset: BudgetAllocationPreset) {
        presets.append(preset)
        insertPresetCache(preset)
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        deletePresetCache(id: id)
    }

    // MARK: - Category cache

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            categories = try context.fetch(FetchDescriptor<BudgetCategoryEntity>())
                .map(Self.makeCategory(from:))
        } catch {
            print("BudgetManager cache read failed: \(error)")
        }
    }

    private func replaceCache(with items: [BudgetCategory]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<BudgetCategoryEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity(from:)).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("BudgetManager cache replace failed: \(error)")
        }
    }

    private func insertCache(_ category: BudgetCategory) {
        let context = ModelContext(container)
        do {
            let id = category.id
            let pred = #Predicate<BudgetCategoryEntity> { $0.id == id }
            try context.fetch(FetchDescriptor<BudgetCategoryEntity>(predicate: pred)).forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: category))
            try context.save()
        } catch {
            print("BudgetManager cache insert failed: \(error)")
        }
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            let pred = #Predicate<BudgetCategoryEntity> { $0.id == id }
            try context.fetch(FetchDescriptor<BudgetCategoryEntity>(predicate: pred)).forEach { context.delete($0) }
            try context.save()
        } catch {
            print("BudgetManager cache delete failed: \(error)")
        }
    }

    // MARK: - Preset cache

    private func loadPresetsFromCache() {
        let context = ModelContext(container)
        do {
            presets = try context.fetch(FetchDescriptor<BudgetAllocationPresetEntity>())
                .compactMap(Self.makePreset(from:))
        } catch {
            print("BudgetManager preset cache read failed: \(error)")
        }
    }

    private func insertPresetCache(_ preset: BudgetAllocationPreset) {
        let context = ModelContext(container)
        do {
            let id = preset.id
            let pred = #Predicate<BudgetAllocationPresetEntity> { $0.id == id }
            try context.fetch(FetchDescriptor<BudgetAllocationPresetEntity>(predicate: pred)).forEach { context.delete($0) }
            context.insert(Self.makePresetEntity(from: preset))
            try context.save()
        } catch {
            print("BudgetManager preset insert failed: \(error)")
        }
    }

    private func deletePresetCache(id: UUID) {
        let context = ModelContext(container)
        do {
            let pred = #Predicate<BudgetAllocationPresetEntity> { $0.id == id }
            try context.fetch(FetchDescriptor<BudgetAllocationPresetEntity>(predicate: pred)).forEach { context.delete($0) }
            try context.save()
        } catch {
            print("BudgetManager preset delete failed: \(error)")
        }
    }

    // MARK: - Conversions

    private static func makeCategory(from entity: BudgetCategoryEntity) -> BudgetCategory {
        BudgetCategory(
            id: entity.id,
            nombre: entity.nombre,
            descripcion: entity.descripcionText,
            asignaciones: BudgetAsignaciones(
                usd: entity.asignacionUSD,
                eur: entity.asignacionEUR,
                cup: entity.asignacionCUP
            ),
            createdAt: entity.createdAt
        )
    }

    private static func makeEntity(from category: BudgetCategory) -> BudgetCategoryEntity {
        BudgetCategoryEntity(
            id: category.id,
            nombre: category.nombre,
            descripcionText: category.descripcion,
            asignacionUSD: category.asignaciones.usd,
            asignacionEUR: category.asignaciones.eur,
            asignacionCUP: category.asignaciones.cup,
            createdAt: category.createdAt
        )
    }

    private static func makePreset(from entity: BudgetAllocationPresetEntity) -> BudgetAllocationPreset? {
        guard let porcentajes = SwiftDataBridge.decode([String: Double].self, from: entity.porcentajesData) else { return nil }
        return BudgetAllocationPreset(
            id: entity.id,
            nombre: entity.nombre,
            porcentajes: porcentajes,
            createdAt: entity.createdAt
        )
    }

    private static func makePresetEntity(from preset: BudgetAllocationPreset) -> BudgetAllocationPresetEntity {
        BudgetAllocationPresetEntity(
            id: preset.id,
            nombre: preset.nombre,
            porcentajesData: SwiftDataBridge.encode(preset.porcentajes),
            createdAt: preset.createdAt
        )
    }
}
