import Foundation
import Combine
import SwiftData

class LugarManager: ObservableObject {
    static let shared = LugarManager()

    @Published var lugares: [Lugar] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadLugares()
    }

    func loadLugares() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LugarEntity>()

        do {
            lugares = try context.fetch(descriptor).map(Self.makeLugar(from:))
        } catch {
            print("Error loading lugares: \(error)")
            lugares = []
        }
    }

    private func saveLugares() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LugarEntity>()

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            lugares.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving lugares: \(error)")
        }
    }

    func lugar(for backendId: String) -> Lugar? {
        return lugares.first { $0.backendId == backendId }
    }

    func addLugar(_ lugar: Lugar) {
        lugares.append(lugar)
        saveLugares()
    }

    func updateLugar(_ lugar: Lugar) {
        if let index = lugares.firstIndex(where: { $0.id == lugar.id }) {
            lugares[index] = lugar
            saveLugares()
        }
    }

    func deleteLugar(_ lugar: Lugar) {
        lugares.removeAll { $0.id == lugar.id }
        saveLugares()
    }

    func upsertLugar(apiLugar: LugarAPI, userProvidedName: String?) -> Lugar {
        let trimmedName = userProvidedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameCandidate = (trimmedName?.isEmpty == false ? trimmedName : nil)
        let keywords = mergeKeywords(existing: nil, incoming: apiLugar.palabrasClave)

        if let backendId = apiLugar.id {
            if let index = lugares.firstIndex(where: { $0.backendId == backendId }) {
                let existing = lugares[index]
                let mergedKeywords = mergeKeywords(existing: existing.visualKeywords, incoming: apiLugar.palabrasClave)
                let finalName = nameCandidate ?? existing.nombre
                lugares[index] = Lugar(
                    id: existing.id,
                    nombre: finalName,
                    visualKeywords: mergedKeywords,
                    backendId: backendId
                )
                saveLugares()
                return lugares[index]
            } else {
                let finalName = nameCandidate ?? apiLugar.nombre ?? "Lugar"
                let nuevoLugar = Lugar(
                    nombre: finalName,
                    visualKeywords: keywords,
                    backendId: backendId
                )
                lugares.append(nuevoLugar)
                saveLugares()
                return nuevoLugar
            }
        } else {
            let finalName = nameCandidate ?? apiLugar.nombre ?? "Lugar"
            let nuevoLugar = Lugar(
                nombre: finalName,
                visualKeywords: keywords,
                backendId: nil
            )
            lugares.append(nuevoLugar)
            saveLugares()
            return nuevoLugar
        }
    }

    private func mergeKeywords(existing: [String]?, incoming: [String]) -> [String] {
        let normalizedExisting = existing ?? []
        var merged = normalizedExisting
        for keyword in incoming {
            if !merged.contains(keyword) {
                merged.append(keyword)
            }
        }
        return merged
    }

    private static func makeLugar(from entity: LugarEntity) -> Lugar {
        Lugar(
            id: entity.id,
            nombre: entity.nombre,
            visualKeywords: SwiftDataBridge.decode([String].self, from: entity.visualKeywordsData),
            backendId: entity.backendId
        )
    }

    private static func makeEntity(from lugar: Lugar) -> LugarEntity {
        LugarEntity(
            id: lugar.id,
            nombre: lugar.nombre,
            visualKeywordsData: lugar.visualKeywords.map(SwiftDataBridge.encode),
            backendId: lugar.backendId
        )
    }
}
