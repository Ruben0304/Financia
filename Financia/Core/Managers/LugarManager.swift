import Foundation
import Combine

class LugarManager: ObservableObject {
    static let shared = LugarManager()

    @Published var lugares: [Lugar] = []

    private let persistence = PersistenceManager.shared
    private let filename = "lugares.json"

    private init() {
        loadLugares()
    }

    func loadLugares() {
        guard persistence.fileExists(filename) else {
            lugares = []
            return
        }

        do {
            lugares = try persistence.load(from: filename, as: [Lugar].self)
        } catch {
            print("Error loading lugares: \(error)")
            lugares = []
        }
    }

    private func saveLugares() {
        do {
            try persistence.save(lugares, to: filename)
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
}
