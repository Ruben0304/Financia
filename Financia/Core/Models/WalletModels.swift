import Foundation
import SwiftUI

enum Currency: String, CaseIterable, Codable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case cup = "CUP"

    var id: String { self.rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .cup: return "$"
        }
    }
}

struct Wallet: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var currency: Currency
    var balance: Double
    var icon: String
    var color: Color
    /// Billetes dañados: clave = denominación como String (ej. "100"), valor = cantidad
    var billesDañados: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case id, name, currency, balance, icon, color, billesDañados
    }

    struct CodableColor: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
    }

    init(id: UUID = UUID(), name: String, currency: Currency, balance: Double, icon: String, color: Color, billesDañados: [String: Int]? = nil) {
        self.id = id
        self.name = name
        self.currency = currency
        self.balance = balance
        self.icon = icon
        self.color = color
        self.billesDañados = billesDañados
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        currency = try container.decode(Currency.self, forKey: .currency)
        balance = try container.decode(Double.self, forKey: .balance)
        icon = try container.decode(String.self, forKey: .icon)
        let codableColor = try container.decode(CodableColor.self, forKey: .color)
        color = Color(.sRGB, red: codableColor.red, green: codableColor.green, blue: codableColor.blue, opacity: codableColor.opacity)
        billesDañados = try container.decodeIfPresent([String: Int].self, forKey: .billesDañados)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(currency, forKey: .currency)
        try container.encode(balance, forKey: .balance)
        try container.encode(icon, forKey: .icon)

        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)

        let codableColor = CodableColor(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(opacity))
        try container.encode(codableColor, forKey: .color)
        try container.encodeIfPresent(billesDañados, forKey: .billesDañados)
    }

    /// Suma total de billetes dañados en la moneda de la cartera
    var totalBillesDañados: Double {
        guard let billetes = billesDañados else { return 0 }
        return billetes.reduce(0) { total, entry in
            let denom = Double(entry.key) ?? 0
            return total + denom * Double(entry.value)
        }
    }
}
