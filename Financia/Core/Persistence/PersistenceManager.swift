import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class WalletEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var currencyRaw: String
    var balance: Double
    var icon: String
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorOpacity: Double

    init(
        id: UUID,
        name: String,
        currencyRaw: String,
        balance: Double,
        icon: String,
        colorRed: Double,
        colorGreen: Double,
        colorBlue: Double,
        colorOpacity: Double
    ) {
        self.id = id
        self.name = name
        self.currencyRaw = currencyRaw
        self.balance = balance
        self.icon = icon
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
        self.colorOpacity = colorOpacity
    }
}

@Model
final class CategoryEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var isIncome: Bool
    var icon: String
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorOpacity: Double
    var subcategoriesData: Data

    init(
        id: UUID,
        name: String,
        isIncome: Bool,
        icon: String,
        colorRed: Double,
        colorGreen: Double,
        colorBlue: Double,
        colorOpacity: Double,
        subcategoriesData: Data
    ) {
        self.id = id
        self.name = name
        self.isIncome = isIncome
        self.icon = icon
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
        self.colorOpacity = colorOpacity
        self.subcategoriesData = subcategoriesData
    }
}

@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var amount: Double
    var date: Date
    var categoryId: UUID
    var categoryName: String
    var subcategoryId: UUID
    var subcategoryName: String
    var detailText: String
    var walletId: UUID
    var createdAt: Date
    var lugarData: Data?
    var subitemsData: Data?
    var assetId: UUID?
    var jobId: UUID?
    var liabilityId: UUID?

    init(
        id: UUID,
        typeRaw: String,
        amount: Double,
        date: Date,
        categoryId: UUID,
        categoryName: String,
        subcategoryId: UUID,
        subcategoryName: String,
        detailText: String,
        walletId: UUID,
        createdAt: Date,
        lugarData: Data?,
        subitemsData: Data?,
        assetId: UUID?,
        jobId: UUID?,
        liabilityId: UUID?
    ) {
        self.id = id
        self.typeRaw = typeRaw
        self.amount = amount
        self.date = date
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.subcategoryId = subcategoryId
        self.subcategoryName = subcategoryName
        self.detailText = detailText
        self.walletId = walletId
        self.createdAt = createdAt
        self.lugarData = lugarData
        self.subitemsData = subitemsData
        self.assetId = assetId
        self.jobId = jobId
        self.liabilityId = liabilityId
    }
}

@Model
final class LugarEntity {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var visualKeywordsData: Data?
    var backendId: String?

    init(id: UUID, nombre: String, visualKeywordsData: Data?, backendId: String?) {
        self.id = id
        self.nombre = nombre
        self.visualKeywordsData = visualKeywordsData
        self.backendId = backendId
    }
}

@Model
final class DebtEntity {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var motivo: String
    var monto: Double
    var monedaRaw: String
    var plazoMeses: Int?
    var createdAt: Date
    var lastEstimateData: Data?
    var montoOriginal: Double
    var pagosData: Data

    init(
        id: UUID,
        nombre: String,
        motivo: String,
        monto: Double,
        monedaRaw: String,
        plazoMeses: Int?,
        createdAt: Date,
        lastEstimateData: Data?,
        montoOriginal: Double,
        pagosData: Data
    ) {
        self.id = id
        self.nombre = nombre
        self.motivo = motivo
        self.monto = monto
        self.monedaRaw = monedaRaw
        self.plazoMeses = plazoMeses
        self.createdAt = createdAt
        self.lastEstimateData = lastEstimateData
        self.montoOriginal = montoOriginal
        self.pagosData = pagosData
    }
}

@Model
final class ProfileEntity {
    @Attribute(.unique) var key: String
    var nombre: String
    var avatarData: Data?
    var situacionFinanciera: String
    var estrategiaFinanciera: String
    var accentColorHex: String?

    init(
        key: String,
        nombre: String,
        avatarData: Data?,
        situacionFinanciera: String,
        estrategiaFinanciera: String,
        accentColorHex: String?
    ) {
        self.key = key
        self.nombre = nombre
        self.avatarData = avatarData
        self.situacionFinanciera = situacionFinanciera
        self.estrategiaFinanciera = estrategiaFinanciera
        self.accentColorHex = accentColorHex
    }
}

@Model
final class SavingsGoalEntity {
    @Attribute(.unique) var id: UUID
    var nombre: String
    var descripcionText: String
    var precioObjetivo: Double
    var monedaRaw: String
    var imagenData: Data?
    var productURL: String?
    var ahorrado: Double
    var createdAt: Date
    var contribucionesData: Data

    init(
        id: UUID,
        nombre: String,
        descripcionText: String,
        precioObjetivo: Double,
        monedaRaw: String,
        imagenData: Data?,
        productURL: String?,
        ahorrado: Double,
        createdAt: Date,
        contribucionesData: Data
    ) {
        self.id = id
        self.nombre = nombre
        self.descripcionText = descripcionText
        self.precioObjetivo = precioObjetivo
        self.monedaRaw = monedaRaw
        self.imagenData = imagenData
        self.productURL = productURL
        self.ahorrado = ahorrado
        self.createdAt = createdAt
        self.contribucionesData = contribucionesData
    }
}

@Model
final class AssetEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var monthlyEstimatesData: Data
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, notes: String, monthlyEstimatesData: Data, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.notes = notes
        self.monthlyEstimatesData = monthlyEstimatesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class JobEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var monthlyEstimatesData: Data
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, notes: String, monthlyEstimatesData: Data, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.notes = notes
        self.monthlyEstimatesData = monthlyEstimatesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class LiabilityEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var monthlyEstimatesData: Data
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, notes: String, monthlyEstimatesData: Data, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.notes = notes
        self.monthlyEstimatesData = monthlyEstimatesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ExchangeRateCacheEntity {
    @Attribute(.unique) var key: String
    var ratesData: Data
    var lastUpdated: Date

    init(key: String, ratesData: Data, lastUpdated: Date) {
        self.key = key
        self.ratesData = ratesData
        self.lastUpdated = lastUpdated
    }
}

@Model
final class ManualUsdRateEntity {
    @Attribute(.unique) var key: String
    var usdToCup: Double

    init(key: String, usdToCup: Double) {
        self.key = key
        self.usdToCup = usdToCup
    }
}

@Model
final class ExpenseAnalysisEntity {
    @Attribute(.unique) var key: String
    var analysis: String

    init(key: String, analysis: String) {
        self.key = key
        self.analysis = analysis
    }
}

final class PersistenceManager {
    static let shared = PersistenceManager()

    let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(
                for: WalletEntity.self,
                CategoryEntity.self,
                TransactionEntity.self,
                LugarEntity.self,
                DebtEntity.self,
                ProfileEntity.self,
                SavingsGoalEntity.self,
                AssetEntity.self,
                JobEntity.self,
                LiabilityEntity.self,
                ExchangeRateCacheEntity.self,
                ManualUsdRateEntity.self,
                ExpenseAnalysisEntity.self
            )
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }
}

enum SwiftDataBridge {
    static func encode<T: Codable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(value)) ?? Data()
    }

    static func decode<T: Codable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data, !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    static func components(from color: Color) -> (red: Double, green: Double, blue: Double, opacity: Double) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        return (Double(red), Double(green), Double(blue), Double(opacity))
    }

    static func color(red: Double, green: Double, blue: Double, opacity: Double) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
