import Foundation
import Combine
import SwiftData

@MainActor
class LugarManager: ObservableObject {
    static let shared = LugarManager()

    @Published var lugares: [Lugar] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/lugares/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            lugares = try context.fetch(FetchDescriptor<LugarEntity>()).map(Self.makeLugar(from:))
        } catch { print("LugarManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        do {
            let remote: [Lugar] = try await api.getList(endpoint)
            lugares = remote
            replaceCache(with: remote)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadLugares() { Task { await refreshFromBackend() } }

    func lugar(for backendId: String) -> Lugar? {
        lugares.first { $0.backendId == backendId }
    }

    // MARK: - CRUD

    func addLugar(_ lugar: Lugar) {
        lugares.append(lugar)
        insertCache(lugar)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.endpoint, body: lugar) }
            catch {
                self.lugares.removeAll { $0.id == lugar.id }
                self.deleteCache(id: lugar.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateLugar(_ lugar: Lugar) {
        guard let i = lugares.firstIndex(where: { $0.id == lugar.id }) else { return }
        let previous = lugares[i]
        lugares[i] = lugar
        insertCache(lugar)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.endpoint)\(lugar.id.uuidString)", body: lugar) }
            catch {
                if let j = self.lugares.firstIndex(where: { $0.id == previous.id }) {
                    self.lugares[j] = previous
                    self.insertCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteLugar(_ lugar: Lugar) {
        lugares.removeAll { $0.id == lugar.id }
        deleteCache(id: lugar.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.endpoint)\(lugar.id.uuidString)") }
            catch {
                self.lugares.append(lugar)
                self.insertCache(lugar)
                self.lastError = error.localizedDescription
            }
        }
    }

    /// Merges an API lugar (from receipt extraction) with the local store,
    /// preserving user renames and accumulating visualKeywords.
    func upsertLugar(apiLugar: LugarAPI, userProvidedName: String?) -> Lugar {
        let trimmedName = userProvidedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameCandidate = (trimmedName?.isEmpty == false ? trimmedName : nil)
        let keywords = mergeKeywords(existing: nil, incoming: apiLugar.palabrasClave)

        if let backendId = apiLugar.id {
            if let i = lugares.firstIndex(where: { $0.backendId == backendId }) {
                let existing = lugares[i]
                let merged = mergeKeywords(existing: existing.visualKeywords, incoming: apiLugar.palabrasClave)
                let finalName = nameCandidate ?? existing.nombre
                let updated = Lugar(id: existing.id, nombre: finalName, visualKeywords: merged, backendId: backendId)
                updateLugar(updated)
                return updated
            } else {
                let finalName = nameCandidate ?? apiLugar.nombre ?? "Lugar"
                let nuevo = Lugar(nombre: finalName, visualKeywords: keywords, backendId: backendId)
                addLugar(nuevo)
                return nuevo
            }
        } else {
            let finalName = nameCandidate ?? apiLugar.nombre ?? "Lugar"
            let nuevo = Lugar(nombre: finalName, visualKeywords: keywords, backendId: nil)
            addLugar(nuevo)
            return nuevo
        }
    }

    private func mergeKeywords(existing: [String]?, incoming: [String]) -> [String] {
        var merged = existing ?? []
        for keyword in incoming where !merged.contains(keyword) { merged.append(keyword) }
        return merged
    }

    // MARK: - Cache

    private func replaceCache(with items: [Lugar]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<LugarEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("LugarManager cache replace failed: \(error)") }
    }

    private func insertCache(_ l: Lugar) {
        let context = ModelContext(container)
        let id = l.id
        do {
            try context.fetch(FetchDescriptor<LugarEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: l))
            try context.save()
        } catch { print("LugarManager cache upsert failed: \(error)") }
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<LugarEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            try context.save()
        } catch { print("LugarManager cache delete failed: \(error)") }
    }

    private static func makeLugar(from e: LugarEntity) -> Lugar {
        Lugar(id: e.id, nombre: e.nombre,
              visualKeywords: SwiftDataBridge.decode([String].self, from: e.visualKeywordsData),
              backendId: e.backendId)
    }

    private static func makeEntity(from l: Lugar) -> LugarEntity {
        LugarEntity(id: l.id, nombre: l.nombre,
                    visualKeywordsData: l.visualKeywords.map(SwiftDataBridge.encode),
                    backendId: l.backendId)
    }
}
