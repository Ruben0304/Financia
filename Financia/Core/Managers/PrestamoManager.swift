import Foundation
import Combine
import SwiftData

@MainActor
class PrestamoManager: ObservableObject {
    static let shared = PrestamoManager()

    @Published var prestamos: [Prestamo] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/prestamos/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do { prestamos = try context.fetch(FetchDescriptor<PrestamoEntity>()).map(Self.makePrestamo(from:)) }
        catch { print("PrestamoManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        do {
            let remote: [Prestamo] = try await api.getList(endpoint)
            prestamos = remote
            replaceCache(with: remote)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadPrestamos() { Task { await refreshFromBackend() } }

    func addPrestamo(_ prestamo: Prestamo) {
        prestamos.append(prestamo)
        insertCache(prestamo)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.endpoint, body: prestamo) }
            catch {
                self.prestamos.removeAll { $0.id == prestamo.id }
                self.deleteCache(id: prestamo.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updatePrestamo(_ prestamo: Prestamo) {
        guard let i = prestamos.firstIndex(where: { $0.id == prestamo.id }) else { return }
        let previous = prestamos[i]
        prestamos[i] = prestamo
        insertCache(prestamo)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.endpoint)\(prestamo.id.uuidString)", body: prestamo) }
            catch {
                if let j = self.prestamos.firstIndex(where: { $0.id == previous.id }) {
                    self.prestamos[j] = previous
                    self.insertCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deletePrestamo(_ prestamo: Prestamo) {
        prestamos.removeAll { $0.id == prestamo.id }
        deleteCache(id: prestamo.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.endpoint)\(prestamo.id.uuidString)") }
            catch {
                self.prestamos.append(prestamo)
                self.insertCache(prestamo)
                self.lastError = error.localizedDescription
            }
        }
    }

    private func replaceCache(with items: [Prestamo]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<PrestamoEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("PrestamoManager cache replace failed: \(error)") }
    }

    private func insertCache(_ p: Prestamo) {
        let context = ModelContext(container); let id = p.id
        do {
            try context.fetch(FetchDescriptor<PrestamoEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: p))
            try context.save()
        } catch { print("PrestamoManager cache upsert failed: \(error)") }
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<PrestamoEntity>(predicate: #Predicate { $0.id == id })).forEach { context.delete($0) }
            try context.save()
        } catch {}
    }

    private static func makePrestamo(from e: PrestamoEntity) -> Prestamo {
        Prestamo(id: e.id, nombre: e.nombre, motivo: e.motivo, monto: e.monto,
                 moneda: Currency(rawValue: e.monedaRaw) ?? .cup,
                 fechaPrestamo: e.fechaPrestamo, fechaDevolucion: e.fechaDevolucion,
                 montoOriginal: e.montoOriginal,
                 cobros: SwiftDataBridge.decode([PrestamoCobro].self, from: e.cobrosData) ?? [],
                 createdAt: e.createdAt)
    }

    private static func makeEntity(from p: Prestamo) -> PrestamoEntity {
        PrestamoEntity(id: p.id, nombre: p.nombre, motivo: p.motivo, monto: p.monto,
                       monedaRaw: p.moneda.rawValue,
                       fechaPrestamo: p.fechaPrestamo, fechaDevolucion: p.fechaDevolucion,
                       montoOriginal: p.montoOriginal,
                       cobrosData: SwiftDataBridge.encode(p.cobros),
                       createdAt: p.createdAt)
    }
}
