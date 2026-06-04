import Foundation
import Combine
import SwiftData

struct ExchangeRateCache: Codable {
    let rates: [String: Double]
    let lastUpdated: Date
}

struct ManualUsdRateCache: Codable {
    let usdToCup: Double
}

/// Exchange rate manager — talks to the FinancIA backend's
/// `/exchange-rates/` endpoint, which itself caches ElToque server-side.
///
/// We still keep a local SwiftData cache so the UI has instant rates on
/// boot. The "manual USD" override is stored locally only (it's purely
/// a user preference for offline conversion in CUP).
@MainActor
class ExchangeRateManager: ObservableObject {

    static let shared = ExchangeRateManager()

    @Published var rates: [String: Double] = [:]
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var manualUsdToCupRate: Double? { didSet { saveManualUsdRate() } }

    private let container = PersistenceManager.shared.container
    private let api = APIClient.shared
    private let endpoint = "/exchange-rates/"
    private let cacheKey = "exchange_rates"
    private let manualUsdRateKey = "manual_usd_rate"
    private let cacheExpirationDays = 1

    private init() {
        loadFromCache()
        loadManualUsdRate()
        checkAndUpdateIfNeeded()
    }

    /// Kept for backward compatibility with the previous direct ElToque
    /// client. The new backend handles auth itself; this is a no-op.
    func configure(token: String) {
        _ = token
    }

    private func loadFromCache() {
        let context = ModelContext(container)
        do {
            if let e = try context.fetch(FetchDescriptor<ExchangeRateCacheEntity>(predicate: #Predicate { $0.key == "exchange_rates" })).first {
                rates = SwiftDataBridge.decode([String: Double].self, from: e.ratesData) ?? [:]
                lastUpdated = e.lastUpdated
            }
        } catch { print("ExchangeRateManager cache read failed: \(error)") }
    }

    private func saveToCache() {
        guard let lastUpdated else { return }
        let context = ModelContext(container)
        do {
            if let e = try context.fetch(FetchDescriptor<ExchangeRateCacheEntity>(predicate: #Predicate { $0.key == "exchange_rates" })).first {
                e.ratesData = SwiftDataBridge.encode(rates)
                e.lastUpdated = lastUpdated
            } else {
                context.insert(ExchangeRateCacheEntity(key: cacheKey, ratesData: SwiftDataBridge.encode(rates), lastUpdated: lastUpdated))
            }
            try context.save()
        } catch { print("ExchangeRateManager cache save failed: \(error)") }
    }

    private func loadManualUsdRate() {
        let context = ModelContext(container)
        do {
            manualUsdToCupRate = try context.fetch(FetchDescriptor<ManualUsdRateEntity>(predicate: #Predicate { $0.key == "manual_usd_rate" })).first?.usdToCup
        } catch { print("ExchangeRateManager manual rate read failed: \(error)") }
    }

    private func saveManualUsdRate() {
        let context = ModelContext(container)
        do {
            if let existing = try context.fetch(FetchDescriptor<ManualUsdRateEntity>(predicate: #Predicate { $0.key == "manual_usd_rate" })).first {
                if let rate = manualUsdToCupRate, rate > 0 { existing.usdToCup = rate }
                else { context.delete(existing) }
            } else if let rate = manualUsdToCupRate, rate > 0 {
                context.insert(ManualUsdRateEntity(key: manualUsdRateKey, usdToCup: rate))
            }
            try context.save()
        } catch { print("ExchangeRateManager manual rate save failed: \(error)") }
    }

    private func shouldUpdate() -> Bool {
        guard let lastUpdated else { return true }
        let days = Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
        return days >= cacheExpirationDays
    }

    func checkAndUpdateIfNeeded() {
        guard shouldUpdate() else { return }
        refreshRates()
    }

    func refreshRates() {
        Task { [weak self] in
            guard let self else { return }
            await self.fetchRates(force: true)
        }
    }

    private func fetchRates(force: Bool) async {
        isLoading = true
        error = nil
        do {
            let response: ExchangeRatesResponse = try await api.get("\(endpoint)?force_refresh=\(force)")
            // The backend wraps ElToque's response inside `rates`. We
            // accept a couple of shapes here so the UI works whether
            // the backend returns a flat dict or a nested ElToque payload.
            if let flat = response.flatRates {
                self.rates = flat
            } else if let elToque = response.rates as? [String: Any], let tasas = elToque["tasas"] as? [String: Double] {
                self.rates = tasas
            }
            self.lastUpdated = Date()
            self.saveToCache()
        } catch {
            self.error = "Error al obtener tasas: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func rate(for currency: String) -> Double? { rates[currency.uppercased()] }

    func effectiveUsdToCupRate() -> Double? {
        if let apiRate = rate(for: "USD"), apiRate > 0 { return apiRate }
        if let manual = manualUsdToCupRate, manual > 0 { return manual }
        return nil
    }

    func updateManualUsdToCupRate(_ rate: Double?) { manualUsdToCupRate = rate }

    func convert(amount: Double, from: Currency, to: Currency) -> Double? {
        guard from != to else { return amount }
        if from == .usd && to == .cup, let r = effectiveUsdToCupRate() { return amount * r }
        if from == .cup && to == .usd, let r = effectiveUsdToCupRate() { return amount / r }
        if from == .eur && to == .cup, let r = rate(for: "EUR") { return amount * r }
        if from == .cup && to == .eur, let r = rate(for: "EUR") { return amount / r }
        if from == .usd && to == .eur, let u = rate(for: "USD"), let e = rate(for: "EUR") {
            return (amount * u) / e
        }
        if from == .eur && to == .usd, let e = rate(for: "EUR"), let u = rate(for: "USD") {
            return (amount * e) / u
        }
        return nil
    }
}

/// Permissive response shape from `/exchange-rates/`. We tolerate either
/// a top-level `rates: {USD: 320, EUR: 350}` dict (flat) or a wrapped
/// `rates: { tasas: {...} }` object coming straight from ElToque.
private struct ExchangeRatesResponse: Codable {
    let id: String?
    let updatedAt: String?
    let rates: AnyCodableValue?

    var flatRates: [String: Double]? {
        guard case let .dictionary(dict) = rates else { return nil }
        var out: [String: Double] = [:]
        for (k, v) in dict {
            if case let .double(d) = v { out[k] = d }
            else if case let .int(i) = v { out[k] = Double(i) }
        }
        return out.isEmpty ? nil : out
    }
}

private enum AnyCodableValue: Codable {
    case dictionary([String: AnyCodableValue])
    case array([AnyCodableValue])
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyCodableValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyCodableValue].self) { self = .dictionary(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .dictionary(let v): try c.encode(v)
        }
    }
}
