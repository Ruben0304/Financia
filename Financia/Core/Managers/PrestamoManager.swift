import Foundation
import Combine
import SwiftData

class PrestamoManager: ObservableObject {
    static let shared = PrestamoManager()

    @Published var prestamos: [Prestamo] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadPrestamos()
    }

    func loadPrestamos() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PrestamoEntity>()
        do {
            prestamos = try context.fetch(descriptor).map(Self.makePrestamo(from:))
        } catch {
            print("Error loading prestamos: \(error)")
            prestamos = []
        }
    }

    private func savePrestamos() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PrestamoEntity>()
        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            prestamos.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving prestamos: \(error)")
        }
    }

    func addPrestamo(_ prestamo: Prestamo) {
        prestamos.append(prestamo)
        savePrestamos()
    }

    func updatePrestamo(_ prestamo: Prestamo) {
        if let index = prestamos.firstIndex(where: { $0.id == prestamo.id }) {
            prestamos[index] = prestamo
            savePrestamos()
        }
    }

    func deletePrestamo(_ prestamo: Prestamo) {
        prestamos.removeAll { $0.id == prestamo.id }
        savePrestamos()
    }

    private static func makePrestamo(from entity: PrestamoEntity) -> Prestamo {
        Prestamo(
            id: entity.id,
            nombre: entity.nombre,
            motivo: entity.motivo,
            monto: entity.monto,
            moneda: Currency(rawValue: entity.monedaRaw) ?? .cup,
            fechaPrestamo: entity.fechaPrestamo,
            fechaDevolucion: entity.fechaDevolucion,
            montoOriginal: entity.montoOriginal,
            cobros: SwiftDataBridge.decode([PrestamoCobro].self, from: entity.cobrosData) ?? [],
            createdAt: entity.createdAt
        )
    }

    private static func makeEntity(from prestamo: Prestamo) -> PrestamoEntity {
        PrestamoEntity(
            id: prestamo.id,
            nombre: prestamo.nombre,
            motivo: prestamo.motivo,
            monto: prestamo.monto,
            monedaRaw: prestamo.moneda.rawValue,
            fechaPrestamo: prestamo.fechaPrestamo,
            fechaDevolucion: prestamo.fechaDevolucion,
            montoOriginal: prestamo.montoOriginal,
            cobrosData: SwiftDataBridge.encode(prestamo.cobros),
            createdAt: prestamo.createdAt
        )
    }
}
