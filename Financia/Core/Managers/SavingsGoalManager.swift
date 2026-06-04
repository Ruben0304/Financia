//
//  SavingsGoalManager.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import Foundation
import Combine
import SwiftData

class SavingsGoalManager: ObservableObject {
    static let shared = SavingsGoalManager()

    @Published var savingsGoals: [SavingsGoal] = []

    private let container = PersistenceManager.shared.container

    private init() {
        loadSavingsGoals()
    }

    // MARK: - Persistence

    func loadSavingsGoals() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SavingsGoalEntity>()

        do {
            savingsGoals = try context.fetch(descriptor).map(Self.makeGoal(from:))
        } catch {
            print("Error loading savings goals: \(error)")
            savingsGoals = []
        }
    }

    private func save() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SavingsGoalEntity>()

        do {
            let existing = try context.fetch(descriptor)
            existing.forEach { context.delete($0) }
            savingsGoals.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch {
            print("Error saving savings goals: \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addSavingsGoal(_ goal: SavingsGoal) {
        savingsGoals.append(goal)
        save()
    }

    func updateSavingsGoal(_ goal: SavingsGoal) {
        if let index = savingsGoals.firstIndex(where: { $0.id == goal.id }) {
            savingsGoals[index] = goal
            save()
        }
    }

    func deleteSavingsGoal(_ goal: SavingsGoal) {
        savingsGoals.removeAll { $0.id == goal.id }
        save()
    }

    // MARK: - Contribution Operations

    func addContribution(to goalId: UUID, contribution: SavingsContribution) {
        if let index = savingsGoals.firstIndex(where: { $0.id == goalId }) {
            savingsGoals[index].contribuciones.append(contribution)
            savingsGoals[index].ahorrado += contribution.monto
            save()
        }
    }

    func removeContribution(from goalId: UUID, contributionId: UUID) {
        if let goalIndex = savingsGoals.firstIndex(where: { $0.id == goalId }),
           let contribIndex = savingsGoals[goalIndex].contribuciones.firstIndex(where: { $0.id == contributionId }) {
            let contribution = savingsGoals[goalIndex].contribuciones[contribIndex]
            savingsGoals[goalIndex].ahorrado -= contribution.monto
            savingsGoals[goalIndex].contribuciones.remove(at: contribIndex)
            save()
        }
    }

    // MARK: - Statistics

    func totalSaved(in currency: Currency) -> Double {
        savingsGoals
            .filter { $0.moneda == currency }
            .reduce(0) { $0 + $1.ahorrado }
    }

    func totalGoalAmount(in currency: Currency) -> Double {
        savingsGoals
            .filter { $0.moneda == currency }
            .reduce(0) { $0 + $1.precioObjetivo }
    }

    func achievedGoals() -> [SavingsGoal] {
        savingsGoals.filter { $0.alcanzado }
    }

    func activeGoals() -> [SavingsGoal] {
        savingsGoals.filter { !$0.alcanzado }
    }

    private static func makeGoal(from entity: SavingsGoalEntity) -> SavingsGoal {
        SavingsGoal(
            id: entity.id,
            nombre: entity.nombre,
            descripcion: entity.descripcionText,
            precioObjetivo: entity.precioObjetivo,
            moneda: Currency(rawValue: entity.monedaRaw) ?? .cup,
            imagenData: entity.imagenData,
            productURL: entity.productURL,
            ahorrado: entity.ahorrado,
            createdAt: entity.createdAt,
            contribuciones: SwiftDataBridge.decode([SavingsContribution].self, from: entity.contribucionesData) ?? []
        )
    }

    private static func makeEntity(from goal: SavingsGoal) -> SavingsGoalEntity {
        SavingsGoalEntity(
            id: goal.id,
            nombre: goal.nombre,
            descripcionText: goal.descripcion,
            precioObjetivo: goal.precioObjetivo,
            monedaRaw: goal.moneda.rawValue,
            imagenData: goal.imagenData,
            productURL: goal.productURL,
            ahorrado: goal.ahorrado,
            createdAt: goal.createdAt,
            contribucionesData: SwiftDataBridge.encode(goal.contribuciones)
        )
    }
}
