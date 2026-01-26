import Foundation
import Combine

// Modelo para caché de tasas de cambio
struct ExchangeRateCache: Codable {
    let rates: [String: Double]
    let lastUpdated: Date
}

// Manager para tasas de cambio con caché local
class ExchangeRateManager: ObservableObject {

    static let shared = ExchangeRateManager()

    @Published var rates: [String: Double] = [:]
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let persistence = PersistenceManager.shared
    private let cacheFilename = "exchange_rates.json"
    private let cacheExpirationDays = 1
    private var api: ElToqueAPI?

    private init() {
        loadFromCache()
        checkAndUpdateIfNeeded()
    }

    // Configurar API token (llamar desde app init)
    func configure(token: String) {
        self.api = ElToqueAPI(token: token)
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        guard persistence.fileExists(cacheFilename) else { return }

        do {
            let cache = try persistence.load(from: cacheFilename, as: ExchangeRateCache.self)
            self.rates = cache.rates
            self.lastUpdated = cache.lastUpdated
        } catch {
            print("Error loading exchange rates cache: \(error)")
        }
    }

    private func saveToCache() {
        guard let lastUpdated = lastUpdated else { return }

        let cache = ExchangeRateCache(rates: rates, lastUpdated: lastUpdated)
        do {
            try persistence.save(cache, to: cacheFilename)
        } catch {
            print("Error saving exchange rates cache: \(error)")
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

    // Convertir de una moneda a otra
    func convert(amount: Double, from: Currency, to: Currency) -> Double? {
        // Si son la misma moneda, retornar el mismo monto
        guard from != to else { return amount }

        // USD a CUP
        if from == .usd && to == .cup, let rate = rate(for: "USD") {
            return amount * rate
        }

        // CUP a USD
        if from == .cup && to == .usd, let rate = rate(for: "USD") {
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
