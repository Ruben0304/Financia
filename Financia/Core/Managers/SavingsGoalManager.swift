//
//  SavingsGoalManager.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import Foundation

class SavingsGoalManager: ObservableObject {
    static let shared = SavingsGoalManager()

    @Published var savingsGoals: [SavingsGoal] = []
    private let persistenceManager = PersistenceManager.shared
    private let fileName = "savings_goals.json"

    private init() {
        loadSavingsGoals()
    }

    // MARK: - Persistence

    func loadSavingsGoals() {
        savingsGoals = persistenceManager.load(fileName: fileName) ?? []
    }

    private func save() {
        persistenceManager.save(savingsGoals, fileName: fileName)
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
}
