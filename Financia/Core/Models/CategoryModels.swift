import Foundation
import SwiftUI

// Modelo para una categoría de transacción (Ingreso o Gasto)
struct TransactionCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var subcategories: [Subcategory]
    var icon: String = "tag.fill" // Default icon
    var color: Color = .blue // Default color

    enum CodingKeys: String, CodingKey {
        case id, name, subcategories, icon, color
    }
    
    struct CodableColor: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
    }

    init(id: UUID = UUID(), name: String, subcategories: [Subcategory], icon: String = "tag.fill", color: Color = .blue) {
        self.id = id
        self.name = name
        self.subcategories = subcategories
        self.icon = icon
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        subcategories = try container.decode([Subcategory].self, forKey: .subcategories)
        icon = try container.decode(String.self, forKey: .icon)
        let codableColor = try container.decode(CodableColor.self, forKey: .color)
        color = Color(.sRGB, red: codableColor.red, green: codableColor.green, blue: codableColor.blue, opacity: codableColor.opacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(subcategories, forKey: .subcategories)
        try container.encode(icon, forKey: .icon)
        
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        
        let codableColor = CodableColor(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(opacity))
        try container.encode(codableColor, forKey: .color)
    }

    static func == (lhs: TransactionCategory, rhs: TransactionCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Modelo para una subcategoría
struct Subcategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String

    static func == (lhs: Subcategory, rhs: Subcategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
