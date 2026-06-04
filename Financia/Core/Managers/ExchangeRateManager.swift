import Foundation
import Combine
import SwiftData

// Modelo para caché de tasas de cambio
struct ExchangeRateCache: Codable {
    let rates: [String: Double]
    let lastUpdated: Date
}

struct ManualUsdRateCache: Codable {
    let usdToCup: Double
}

// Manager para tasas de cambio con caché local
class ExchangeRateManager: ObservableObject {

    static let shared = ExchangeRateManager()

    @Published var rates: [String: Double] = [:]
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var manualUsdToCupRate: Double? {
        didSet { saveManualUsdRate() }
    }

    private let container = PersistenceManager.shared.container
    private let cacheKey = "exchange_rates"
    private let manualUsdRateKey = "manual_usd_rate"
    private let cacheExpirationDays = 1
    private var api: ElToqueAPI?

    private init() {
        loadFromCache()
        loadManualUsdRate()
        checkAndUpdateIfNeeded()
    }

    // Configurar API token (llamar desde app init)
    func configure(token: String) {
        self.api = ElToqueAPI(token: token)
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ExchangeRateCacheEntity>(
            predicate: #Predicate { $0.key == "exchange_rates" }
        )

        do {
            if let entity = try context.fetch(descriptor).first {
                rates = SwiftDataBridge.decode([String: Double].self, from: entity.ratesData) ?? [:]
                lastUpdated = entity.lastUpdated
            }
        } catch {
            print("Error loading exchange rates cache: \(error)")
        }
    }

    private func saveToCache() {
        guard let lastUpdated = lastUpdated else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ExchangeRateCacheEntity>(
            predicate: #Predicate { $0.key == "exchange_rates" }
        )

        do {
            if let entity = try context.fetch(descriptor).first {
                entity.ratesData = SwiftDataBridge.encode(rates)
                entity.lastUpdated = lastUpdated
            } else {
                context.insert(
                    ExchangeRateCacheEntity(
                        key: cacheKey,
                        ratesData: SwiftDataBridge.encode(rates),
                        lastUpdated: lastUpdated
                    )
                )
            }
            try context.save()
        } catch {
            print("Error saving exchange rates cache: \(error)")
        }
    }

    private func loadManualUsdRate() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ManualUsdRateEntity>(
            predicate: #Predicate { $0.key == "manual_usd_rate" }
        )

        do {
            manualUsdToCupRate = try context.fetch(descriptor).first?.usdToCup
        } catch {
            print("Error loading manual USD rate: \(error)")
        }
    }

    private func saveManualUsdRate() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ManualUsdRateEntity>(
            predicate: #Predicate { $0.key == "manual_usd_rate" }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                if let rate = manualUsdToCupRate, rate > 0 {
                    existing.usdToCup = rate
                } else {
                    context.delete(existing)
                }
            } else if let rate = manualUsdToCupRate, rate > 0 {
                context.insert(ManualUsdRateEntity(key: manualUsdRateKey, usdToCup: rate))
            }
            try context.save()
        } catch {
            print("Error saving manual USD rate: \(error)")
        }
    }

    private func shouldUpdate() -> Bool {
        guard let lastUpdated = lastUpdated else { return true }

        let calendar = Calendar.current
        let daysSinceUpdate = calendar.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
        return daysSinceUpdate >= cacheExpirationDays
    }

    // MARK: - Public Methods

    // Actualizar automáticamente si pasó 1 día o más
    func checkAndUpdateIfNeeded() {
        guard shouldUpdate() else { return }
        fetchRates()
    }

    // Actualizar manualmente (forzar recarga)
    func refreshRates() {
        fetchRates()
    }

    private func fetchRates() {
        guard let api = api else {
            self.error = "API no configurada. Falta el token."
            return
        }

        isLoading = true
        error = nil

        api.fetchTasas { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let rates):
                    self?.rates = rates
                    self?.lastUpdated = Date()
                    self?.saveToCache()
                    self?.error = nil

                case .failure(let error):
                    self?.error = "Error al obtener tasas: \(error.localizedDescription)"
                }
            }
        }
    }

    // Obtener tasa específica
    func rate(for currency: String) -> Double? {
        return rates[currency.uppercased()]
    }

    func effectiveUsdToCupRate() -> Double? {
        if let apiRate = rate(for: "USD"), apiRate > 0 {
            return apiRate
        }
        if let manual = manualUsdToCupRate, manual > 0 {
            return manual
        }
        return nil
    }

    func updateManualUsdToCupRate(_ rate: Double?) {
        manualUsdToCupRate = rate
    }

    // Convertir de una moneda a otra
    func convert(amount: Double, from: Currency, to: Currency) -> Double? {
        // Si son la misma moneda, retornar el mismo monto
        guard from != to else { return amount }

        // USD a CUP
        if from == .usd && to == .cup, let rate = effectiveUsdToCupRate() {
            return amount * rate
        }

        // CUP a USD
        if from == .cup && to == .usd, let rate = effectiveUsdToCupRate() {
            return amount / rate
        }

        // EUR a CUP
        if from == .eur && to == .cup, let rate = rate(for: "EUR") {
            return amount * rate
        }

        // CUP a EUR
        if from == .cup && to == .eur, let rate = rate(for: "EUR") {
            return amount / rate
        }

        // USD a EUR o viceversa (a través de CUP)
        if from == .usd && to == .eur,
           let usdRate = rate(for: "USD"),
           let eurRate = rate(for: "EUR") {
            let cupAmount = amount * usdRate
            return cupAmount / eurRate
        }

        if from == .eur && to == .usd,
           let eurRate = rate(for: "EUR"),
           let usdRate = rate(for: "USD") {
            let cupAmount = amount * eurRate
            return cupAmount / usdRate
        }

        return nil
    }
}
