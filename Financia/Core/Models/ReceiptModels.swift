import Foundation

// MARK: - Request Models

/// Modelo para lugares conocidos que se envían al backend
struct KnownPlace: Codable {
    let id: String
    let nombre: String
    let palabrasClave: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case nombre
        case palabrasClave = "palabras_clave"
    }

    /// Inicializador desde el modelo Lugar local
    init(from lugar: Lugar) {
        self.id = lugar.backendId ?? lugar.id.uuidString
        self.nombre = lugar.nombre
        self.palabrasClave = lugar.visualKeywords ?? []
    }

    init(id: String, nombre: String, palabrasClave: [String]) {
        self.id = id
        self.nombre = nombre
        self.palabrasClave = palabrasClave
    }
}

// MARK: - Response Models

/// Respuesta de la API de extracción de vales
struct ReceiptExtraction: Codable {
    let monto: Double
    let lugar: LugarAPI
    let subitems: [SubItemAPI]?
    let moneda: String

    /// Convierte la respuesta de la API a modelos locales
    func toLugar() -> Lugar {
        let uuid = lugar.id.flatMap { UUID(uuidString: $0) }
        return Lugar(
            id: uuid ?? UUID(),
            nombre: lugar.nombre ?? "",
            visualKeywords: lugar.palabrasClave,
            backendId: lugar.id
        )
    }

    func toSubItems() -> [SubItem]? {
        return subitems?.map { apiItem in
            SubItem(
                nombre: apiItem.nombre,
                cantidad: apiItem.cantidad,
                precio: apiItem.precio
            )
        }
    }
}

/// Lugar según la respuesta del backend
struct LugarAPI: Codable {
    let id: String?
    let nombre: String?
    let palabrasClave: [String]

    /// True si es un lugar nuevo (no reconocido)
    var esNuevo: Bool {
        return id == nil && nombre != nil
    }

    /// True si coincidió con un lugar existente
    var esConocido: Bool {
        return id != nil
    }
}

/// SubItem según la respuesta del backend
struct SubItemAPI: Codable {
    let nombre: String
    let cantidad: Int
    let precio: Double?
}
