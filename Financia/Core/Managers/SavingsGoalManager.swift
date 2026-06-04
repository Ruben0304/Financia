//
//  SavingsGoalManager.swift
//  Financia
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
class SavingsGoalManager: ObservableObject {
    static let shared = SavingsGoalManager()

    @Published var savingsGoals: [SavingsGoal] = []
    @Published var lastError: String?

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/savings-goals/"

    private init() {
        loadFromCache()
        Task { await refreshFromBackend() }
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            savingsGoals = try context.fetch(FetchDescriptor<SavingsGoalEntity>()).map(Self.makeGoal(from:))
        } catch { print("SavingsGoalManager cache read failed: \(error)") }
    }

    func refreshFromBackend() async {
        do {
            let remote: [SavingsGoal] = try await api.getList(endpoint)
            savingsGoals = remote
            replaceCache(with: remote)
        } catch APIError.networkUnavailable {
        } catch { lastError = error.localizedDescription }
    }

    func loadSavingsGoals() { Task { await refreshFromBackend() } }

    // MARK: - CRUD

    func addSavingsGoal(_ goal: SavingsGoal) {
        savingsGoals.append(goal)
        insertCache(goal)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.post(self.endpoint, body: goal) }
            catch {
                self.savingsGoals.removeAll { $0.id == goal.id }
                self.deleteCache(id: goal.id)
                self.lastError = error.localizedDescription
            }
        }
    }

    func updateSavingsGoal(_ goal: SavingsGoal) {
        guard let i = savingsGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        let previous = savingsGoals[i]
        savingsGoals[i] = goal
        insertCache(goal)
        Task { [weak self] in
            guard let self else { return }
            do { let _: Empty = try await self.api.put("\(self.endpoint)\(goal.id.uuidString)", body: goal) }
            catch {
                if let j = self.savingsGoals.firstIndex(where: { $0.id == previous.id }) {
                    self.savingsGoals[j] = previous
                    self.insertCache(previous)
                }
                self.lastError = error.localizedDescription
            }
        }
    }

    func deleteSavingsGoal(_ goal: SavingsGoal) {
        savingsGoals.removeAll { $0.id == goal.id }
        deleteCache(id: goal.id)
        Task { [weak self] in
            guard let self else { return }
            do { _ = try await self.api.delete("\(self.endpoint)\(goal.id.uuidString)") }
            catch {
                self.savingsGoals.append(goal)
                self.insertCache(goal)
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Contributions
    //
    // We update the local model + cache optimistically, then PUT the
    // whole goal (rather than calling the specific `/contributions`
    // endpoint) — this keeps the iOS rollback logic simpler. The atomic
    // endpoint exists primarily for the MCP server.

    func addContribution(to goalId: UUID, contribution: SavingsContribution) {
        guard let i = savingsGoals.firstIndex(where: { $0.id == goalId }) else { return }
        var goal = savingsGoals[i]
        goal.contribuciones.append(contribution)
        goal.ahorrado = max(goal.ahorrado + contribution.monto, 0)
        updateSavingsGoal(goal)
    }

    func removeContribution(from goalId: UUID, contributionId: UUID) {
        guard let gi = savingsGoals.firstIndex(where: { $0.id == goalId }),
              let ci = savingsGoals[gi].contribuciones.firstIndex(where: { $0.id == contributionId }) else { return }
        var goal = savingsGoals[gi]
        let contrib = goal.contribuciones[ci]
        goal.ahorrado = max(goal.ahorrado - contrib.monto, 0)
        goal.contribuciones.remove(at: ci)
        updateSavingsGoal(goal)
    }

    func updateProjectionSettings(
        for goalId: UUID,
        aporteInicialMode: SavingsProjectionMode,
        baseInicialManual: Double,
        aporteInicialPorcentaje: Double,
        aporteInicialCantidadManual: Double,
        aportePronosticoMode: SavingsProjectionMode,
        aportePronosticoPorcentaje: Double,
        aportePronosticoCantidadManual: Double
    ) {
        guard let i = savingsGoals.firstIndex(where: { $0.id == goalId }) else { return }
        var goal = savingsGoals[i]
        goal.aporteInicialMode = aporteInicialMode
        goal.baseInicialManual = max(baseInicialManual, 0)
        goal.aporteInicialPorcentaje = min(max(aporteInicialPorcentaje, 0), 100)
        goal.aporteInicialCantidadManual = max(aporteInicialCantidadManual, 0)
        goal.aportePronosticoMode = aportePronosticoMode
        goal.aportePronosticoPorcentaje = min(max(aportePronosticoPorcentaje, 0), 100)
        goal.aportePronosticoCantidadManual = max(aportePronosticoCantidadManual, 0)
        updateSavingsGoal(goal)
    }

    // MARK: - Statistics (unchanged)

    func totalSaved(in currency: Currency) -> Double {
        savingsGoals.filter { $0.moneda == currency }.reduce(0) { $0 + $1.ahorrado }
    }

    func totalGoalAmount(in currency: Currency) -> Double {
        savingsGoals.filter { $0.moneda == currency }.reduce(0) { $0 + $1.precioObjetivo }
    }

    func projectedCurrentReservation(for goal: SavingsGoal, availableCurrent: Double) -> Double {
        switch goal.aporteInicialMode {
        case .percentage:
            return max(availableCurrent, 0) * (goal.aporteInicialPorcentaje / 100)
        case .manualAmount:
            return min(max(goal.aporteInicialCantidadManual, 0), max(availableCurrent, 0))
        }
    }

    func totalProjectedCurrentReservation(in currency: Currency, availableCurrent: Double, excludingGoalId: UUID? = nil) -> Double {
        savingsGoals.filter { $0.moneda == currency && $0.id != excludingGoalId }
            .reduce(0) { $0 + projectedCurrentReservation(for: $1, availableCurrent: availableCurrent) }
    }

    func achievedGoals() -> [SavingsGoal] { savingsGoals.filter { $0.alcanzado } }
    func activeGoals() -> [SavingsGoal] { savingsGoals.filter { !$0.alcanzado } }

    // MARK: - Cache

    private func replaceCache(with items: [SavingsGoal]) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<SavingsGoalEntity>()).forEach { context.delete($0) }
            items.map(Self.makeEntity).forEach { context.insert($0) }
            try context.save()
        } catch { print("SavingsGoalManager cache replace failed: \(error)") }
    }

    private func insertCache(_ g: SavingsGoal) {
        let context = ModelContext(container)
        let id = g.id
        do {
            try context.fetch(FetchDescriptor<SavingsGoalEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            context.insert(Self.makeEntity(from: g))
            try context.save()
        } catch { print("SavingsGoalManager cache upsert failed: \(error)") }
    }

    private func deleteCache(id: UUID) {
        let context = ModelContext(container)
        do {
            try context.fetch(FetchDescriptor<SavingsGoalEntity>(predicate: #Predicate { $0.id == id }))
                .forEach { context.delete($0) }
            try context.save()
        } catch { print("SavingsGoalManager cache delete failed: \(error)") }
    }

    private static func makeGoal(from e: SavingsGoalEntity) -> SavingsGoal {
        SavingsGoal(
            id: e.id, nombre: e.nombre, descripcion: e.descripcionText,
            precioObjetivo: e.precioObjetivo, moneda: Currency(rawValue: e.monedaRaw) ?? .cup,
            imagenData: e.imagenData, productURL: e.productURL, ahorrado: e.ahorrado,
            createdAt: e.createdAt,
            contribuciones: SwiftDataBridge.decode([SavingsContribution].self, from: e.contribucionesData) ?? [],
            aporteInicialMode: SavingsProjectionMode(rawValue: e.aporteInicialModeRaw) ?? .percentage,
            baseInicialManual: e.baseInicialManual,
            aporteInicialPorcentaje: e.aporteInicialPorcentaje,
            aporteInicialCantidadManual: e.aporteInicialCantidadManual,
            aportePronosticoMode: SavingsProjectionMode(rawValue: e.aportePronosticoModeRaw) ?? .percentage,
            aportePronosticoPorcentaje: e.aportePronosticoPorcentaje,
            aportePronosticoCantidadManual: e.aportePronosticoCantidadManual
        )
    }

    private static func makeEntity(from g: SavingsGoal) -> SavingsGoalEntity {
        SavingsGoalEntity(
            id: g.id, nombre: g.nombre, descripcionText: g.descripcion,
            precioObjetivo: g.precioObjetivo, monedaRaw: g.moneda.rawValue,
            imagenData: g.imagenData, productURL: g.productURL, ahorrado: g.ahorrado,
            createdAt: g.createdAt,
            contribucionesData: SwiftDataBridge.encode(g.contribuciones),
            aporteInicialModeRaw: g.aporteInicialMode.rawValue,
            baseInicialManual: g.baseInicialManual,
            aporteInicialPorcentaje: g.aporteInicialPorcentaje,
            aporteInicialCantidadManual: g.aporteInicialCantidadManual,
            aportePronosticoModeRaw: g.aportePronosticoMode.rawValue,
            aportePronosticoPorcentaje: g.aportePronosticoPorcentaje,
            aportePronosticoCantidadManual: g.aportePronosticoCantidadManual
        )
    }
}

// MARK: - SavingsGoalAnalysisManager (unchanged — pure UI/AI orchestration)

@MainActor
final class SavingsGoalAnalysisManager: ObservableObject {
    @Published var selectedGoalIDs: Set<UUID> = []
    @Published var latestAnalysis: String?
    @Published var isAnalyzing: Bool = false
    @Published var activeSummary: String?
    @Published var lastErrorMessage: String?

    private let chatService: ChatService
    private let contextBuilder: FinancialAIContextBuilder
    private let savingsGoalManager: SavingsGoalManager
    private let walletManager: WalletManager
    private let wealthManager: WealthManager
    private var analysisTask: Task<Void, Never>?

    init(
        chatService: ChatService = ChatService(),
        contextBuilder: FinancialAIContextBuilder = FinancialAIContextBuilder(),
        savingsGoalManager: SavingsGoalManager = .shared,
        walletManager: WalletManager = .shared,
        wealthManager: WealthManager = .shared
    ) {
        self.chatService = chatService
        self.contextBuilder = contextBuilder
        self.savingsGoalManager = savingsGoalManager
        self.walletManager = walletManager
        self.wealthManager = wealthManager
    }

    deinit { analysisTask?.cancel() }

    func toggleSelection(for goalID: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            if selectedGoalIDs.contains(goalID) { selectedGoalIDs.remove(goalID) }
            else { selectedGoalIDs.insert(goalID) }
        }
    }

    func clearSelection() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selectedGoalIDs.removeAll() }
    }

    func analyzeSingleGoal(_ goal: SavingsGoal) {
        activeSummary = "Análisis individual de \(goal.nombre)"
        analyze(goals: [goal], transactionFilter: .ambos, timePeriod: .all)
    }

    func analyzeSelectedGoals(from goals: [SavingsGoal]) {
        let selectedGoals = goals.filter { selectedGoalIDs.contains($0.id) }
        guard !selectedGoals.isEmpty else { return }
        if selectedGoals.count == 1, let goal = selectedGoals.first {
            activeSummary = "Análisis individual de \(goal.nombre)"
        } else {
            activeSummary = "Análisis conjunto de \(selectedGoals.count) metas"
        }
        analyze(goals: selectedGoals, transactionFilter: .ambos, timePeriod: .all)
    }

    func analyzeActiveGoals(_ goals: [SavingsGoal]) {
        guard !goals.isEmpty else { return }
        activeSummary = "Análisis conjunto de todas las metas activas"
        analyze(goals: goals, transactionFilter: .ambos, timePeriod: .all)
    }

    private func analyze(goals: [SavingsGoal], transactionFilter: TransactionFilter, timePeriod: TimePeriod) {
        analysisTask?.cancel()
        latestAnalysis = nil
        lastErrorMessage = nil
        isAnalyzing = true

        let prompt = buildPrompt(for: goals, transactionFilter: transactionFilter, timePeriod: timePeriod)

        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try await chatService.sendMessage(prompt)
                for try await chunk in stream {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.latestAnalysis = (self.latestAnalysis ?? "") + chunk }
                }
                await MainActor.run { self.isAnalyzing = false }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isAnalyzing = false
                    self.lastErrorMessage = self.errorMessage(for: error)
                }
            }
        }
    }

    private func buildPrompt(for goals: [SavingsGoal], transactionFilter: TransactionFilter, timePeriod: TimePeriod) -> String {
        let baseContext = contextBuilder.buildTransactionContext(transactionFilter: transactionFilter, timePeriod: timePeriod)
        let snapshots = goals.map(makeSnapshot(for:))
        let groupedByCurrency = Dictionary(grouping: snapshots, by: \.goal.moneda)

        var prompt = """
        === ANÁLISIS IA DE METAS DE AHORRO ===

        Vas a analizar metas de ahorro de un usuario usando el contexto financiero completo de la app y los datos detallados de proyección de cada meta.

        \(baseContext)

        === METAS SELECCIONADAS PARA ANALIZAR ===
        Cantidad de metas: \(snapshots.count)

        """

        for snapshot in snapshots {
            let goal = snapshot.goal
            let recentContributions = snapshot.recentContributions.isEmpty
                ? "Sin aportes recientes"
                : snapshot.recentContributions.joined(separator: " | ")
            let forecastEvents = snapshot.forecastEventLines.isEmpty
                ? "Sin cobros pronosticados"
                : snapshot.forecastEventLines.joined(separator: "\n")

            prompt += """
            - Meta: \(goal.nombre)
              Moneda: \(goal.moneda.rawValue)
              Objetivo: \(String(format: "%.2f", goal.precioObjetivo))
              Ahorrado actual: \(String(format: "%.2f", goal.ahorrado))
              Restante real: \(String(format: "%.2f", goal.montoPendiente))
              Descripción: \(goal.descripcion.isEmpty ? "Sin descripción" : goal.descripcion)
              Fecha de creación: \(snapshot.createdAtLabel)
              URL asociada: \(goal.productURL ?? "Sin link")
              Aportes registrados: \(goal.contribuciones.count)
              Historial reciente: \(recentContributions)
              Disponible actual en carteras de la misma moneda: \(String(format: "%.2f", snapshot.totalAvailableNow))
              Reservado hoy por otras metas: \(String(format: "%.2f", snapshot.reservedByOtherGoals))
              Disponible real para esta meta: \(String(format: "%.2f", snapshot.availableForThisGoal))
              Configuración aporte inicial: \(snapshot.initialModeLabel)
              Aporte inicial estimado desde saldo actual: \(String(format: "%.2f", snapshot.initialContribution))
              Configuración aporte desde pronóstico: \(snapshot.forecastModeLabel)
              Pronóstico mensual disponible: \(String(format: "%.2f", snapshot.monthlyForecastIncome))
              Aporte mensual estimado desde pronóstico: \(String(format: "%.2f", snapshot.monthlyForecastContribution))
              Progreso si aplica el aporte inicial: \(String(format: "%.2f", snapshot.progressAfterInitialContribution))
              Restante tras aporte inicial: \(String(format: "%.2f", snapshot.remainingAfterInitialContribution))
              Fecha estimada de cumplimiento con configuración actual: \(snapshot.estimatedCompletionLabel)
              Cobros proyectados relevantes:
            \(forecastEvents)

            """
        }

        prompt += "=== RESUMEN COMBINADO ===\n"
        for currency in groupedByCurrency.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let currencySnapshots = groupedByCurrency[currency] ?? []
            let totalGoal = currencySnapshots.reduce(0) { $0 + $1.goal.precioObjetivo }
            let totalSaved = currencySnapshots.reduce(0) { $0 + $1.goal.ahorrado }
            let totalRemaining = currencySnapshots.reduce(0) { $0 + $1.goal.montoPendiente }
            let totalInitial = currencySnapshots.reduce(0) { $0 + $1.initialContribution }
            let totalForecast = currencySnapshots.reduce(0) { $0 + $1.monthlyForecastContribution }

            prompt += """
            - Moneda \(currency.rawValue):
              Objetivo total: \(String(format: "%.2f", totalGoal))
              Ahorrado total: \(String(format: "%.2f", totalSaved))
              Restante total: \(String(format: "%.2f", totalRemaining))
              Aporte inicial conjunto proyectado: \(String(format: "%.2f", totalInitial))
              Aporte mensual conjunto proyectado: \(String(format: "%.2f", totalForecast))

            """
        }

        prompt += """
        Instrucciones de respuesta:
        - Responde en español.
        - Si es una sola meta, evalúa viabilidad, fecha probable, principal fricción y ajuste recomendado.
        - Si son varias metas, analiza choques entre metas, prioridad sugerida, secuencia recomendada y si la distribución actual del dinero pronosticado tiene sentido.
        - Usa markdown corto con estos bloques:
          ## Diagnóstico
          ## Riesgos
          ## Recomendación accionable
        - Sé concreto, no hagas preguntas y no menciones que eres una IA.
        """

        return prompt
    }

    private func makeSnapshot(for goal: SavingsGoal) -> SavingsGoalProjectionSnapshot {
        let incomeEvents = wealthManager.incomeEvents(in: goal.moneda)
        let totalAvailableNow = walletManager.wallets
            .filter { $0.currency == goal.moneda }
            .reduce(0) { partial, wallet in partial + walletManager.calculateBalance(for: wallet) }

        let reservedByOtherGoals = savingsGoalManager.totalProjectedCurrentReservation(
            in: goal.moneda, availableCurrent: totalAvailableNow, excludingGoalId: goal.id
        )
        let availableForThisGoal = max(totalAvailableNow - reservedByOtherGoals, 0)
        let initialContribution: Double
        switch goal.aporteInicialMode {
        case .percentage:
            initialContribution = max(totalAvailableNow, 0) * (goal.aporteInicialPorcentaje / 100)
        case .manualAmount:
            initialContribution = min(max(goal.aporteInicialCantidadManual, 0), availableForThisGoal)
        }

        let monthlyForecastIncome = wealthManager.forecastedMonthlyIncome(in: goal.moneda)
        let monthlyForecastContribution: Double
        switch goal.aportePronosticoMode {
        case .percentage:
            monthlyForecastContribution = monthlyForecastIncome * (goal.aportePronosticoPorcentaje / 100)
        case .manualAmount:
            monthlyForecastContribution = Double(incomeEvents.count) * max(goal.aportePronosticoCantidadManual, 0)
        }

        let progressAfterInitialContribution = min(goal.ahorrado + max(initialContribution, 0), goal.precioObjetivo)
        let remainingAfterInitialContribution = max(goal.precioObjetivo - (goal.ahorrado + max(initialContribution, 0)), 0)

        let estimatedCompletionLabel = projectedGoalDate(
            for: goal, startingRemaining: remainingAfterInitialContribution, incomeEvents: incomeEvents
        )?.formatted(date: .abbreviated, time: .omitted) ?? "Sin fecha clara"

        let forecastEventLines = incomeEvents.map { income in
            let projectedAmount = projectedAmount(for: goal, income: income)
            let reservedByOtherGoalsForIncome = reservedForecastAmountByOtherGoals(for: goal, income: income)
            return "    - \(income.sourceName) día \(income.dayOfMonth): cobra \(String(format: "%.2f", income.amount)), reservado por otras metas \(String(format: "%.2f", reservedByOtherGoalsForIncome)), destinarías \(String(format: "%.2f", projectedAmount))"
        }

        let dateFormatter = DateFormatter(); dateFormatter.dateStyle = .medium
        let contributionFormatter = DateFormatter(); contributionFormatter.dateStyle = .short

        let recentContributions = goal.contribuciones.sorted { $0.fecha > $1.fecha }.prefix(3).map {
            "\($0.monto.formatted(.number.precision(.fractionLength(0...2)))) \(goal.moneda.rawValue) el \(contributionFormatter.string(from: $0.fecha))\($0.nota.map { " (\($0))" } ?? "")"
        }

        return SavingsGoalProjectionSnapshot(
            goal: goal, createdAtLabel: dateFormatter.string(from: goal.createdAt),
            totalAvailableNow: totalAvailableNow, reservedByOtherGoals: reservedByOtherGoals,
            availableForThisGoal: availableForThisGoal,
            initialModeLabel: projectionModeLabel(mode: goal.aporteInicialMode, percentage: goal.aporteInicialPorcentaje, amount: goal.aporteInicialCantidadManual, suffix: "del saldo actual"),
            initialContribution: initialContribution,
            forecastModeLabel: projectionModeLabel(mode: goal.aportePronosticoMode, percentage: goal.aportePronosticoPorcentaje, amount: goal.aportePronosticoCantidadManual, suffix: "por cobro futuro"),
            monthlyForecastIncome: monthlyForecastIncome, monthlyForecastContribution: monthlyForecastContribution,
            progressAfterInitialContribution: progressAfterInitialContribution,
            remainingAfterInitialContribution: remainingAfterInitialContribution,
            estimatedCompletionLabel: estimatedCompletionLabel,
            recentContributions: recentContributions, forecastEventLines: forecastEventLines
        )
    }

    private func projectedGoalDate(for goal: SavingsGoal, startingRemaining: Double, incomeEvents: [ProjectedIncomeEvent]) -> Date? {
        if startingRemaining <= 0 { return Date() }
        let scheduledEvents = incomeEvents.compactMap { income -> ScheduledSavingsContribution? in
            let amount = projectedAmount(for: goal, income: income)
            guard amount > 0 else { return nil }
            return ScheduledSavingsContribution(dayOfMonth: income.dayOfMonth, amount: amount)
        }.sorted { $0.dayOfMonth < $1.dayOfMonth }
        guard !scheduledEvents.isEmpty else { return nil }

        let calendar = Calendar.current
        let startDate = Date()
        var accumulated = 0.0
        for monthOffset in 0..<36 {
            let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: startDate) ?? startDate
            let range = calendar.range(of: .day, in: .month, for: monthDate) ?? (1..<32)
            for event in scheduledEvents {
                let day = min(max(event.dayOfMonth, 1), range.count)
                guard let eventDate = calendar.date(bySetting: .day, value: day, of: monthDate) else { continue }
                if eventDate < startDate { continue }
                accumulated += event.amount
                if accumulated >= startingRemaining { return eventDate }
            }
        }
        return nil
    }

    private func projectedAmount(for goal: SavingsGoal, income: ProjectedIncomeEvent) -> Double {
        switch goal.aportePronosticoMode {
        case .percentage: return income.amount * (goal.aportePronosticoPorcentaje / 100)
        case .manualAmount: return max(goal.aportePronosticoCantidadManual, 0)
        }
    }

    private func reservedForecastAmountByOtherGoals(for goal: SavingsGoal, income: ProjectedIncomeEvent) -> Double {
        savingsGoalManager.savingsGoals
            .filter { $0.moneda == goal.moneda && $0.id != goal.id }
            .reduce(0) { $0 + reservedForecastAmount(for: $1, income: income) }
    }

    private func reservedForecastAmount(for goal: SavingsGoal, income: ProjectedIncomeEvent) -> Double {
        switch goal.aportePronosticoMode {
        case .percentage: return income.amount * (goal.aportePronosticoPorcentaje / 100)
        case .manualAmount: return max(goal.aportePronosticoCantidadManual, 0)
        }
    }

    private func projectionModeLabel(mode: SavingsProjectionMode, percentage: Double, amount: Double, suffix: String) -> String {
        switch mode {
        case .percentage: return "\(String(format: "%.0f", percentage))% \(suffix)"
        case .manualAmount: return "\(String(format: "%.2f", amount)) \(suffix)"
        }
    }

    private func errorMessage(for error: Error) -> String {
        if let apiError = error as? ChatAPIError {
            switch apiError {
            case .serverError(let detail): return detail
            case .invalidResponse: return "La respuesta del análisis no fue válida."
            case .encodingError: return "No se pudo preparar el análisis."
            case .networkError(let underlying): return "Error de red: \(underlying.localizedDescription)"
            }
        }
        return "No se pudo completar el análisis: \(error.localizedDescription)"
    }
}

private struct SavingsGoalProjectionSnapshot {
    let goal: SavingsGoal
    let createdAtLabel: String
    let totalAvailableNow: Double
    let reservedByOtherGoals: Double
    let availableForThisGoal: Double
    let initialModeLabel: String
    let initialContribution: Double
    let forecastModeLabel: String
    let monthlyForecastIncome: Double
    let monthlyForecastContribution: Double
    let progressAfterInitialContribution: Double
    let remainingAfterInitialContribution: Double
    let estimatedCompletionLabel: String
    let recentContributions: [String]
    let forecastEventLines: [String]
}

private struct ScheduledSavingsContribution {
    let dayOfMonth: Int
    let amount: Double
}
