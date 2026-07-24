import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class WalletEntity {
    var id: UUID = UUID()
    var name: String = ""
    var currencyRaw: String = ""
    var balance: Double = 0
    var icon: String = ""
    var colorRed: Double = 0
    var colorGreen: Double = 0
    var colorBlue: Double = 0
    var colorOpacity: Double = 1
    /// JSON-encoded [String: Int] — denominación: cantidad de billetes dañados
    var billetesData: Data?

    init(
        id: UUID,
        name: String,
        currencyRaw: String,
        balance: Double,
        icon: String,
        colorRed: Double,
        colorGreen: Double,
        colorBlue: Double,
        colorOpacity: Double,
        billetesData: Data? = nil
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
        self.billetesData = billetesData
    }
}

@Model
final class CategoryEntity {
    var id: UUID = UUID()
    var name: String = ""
    var isIncome: Bool = false
    var icon: String = ""
    var colorRed: Double = 0
    var colorGreen: Double = 0
    var colorBlue: Double = 0
    var colorOpacity: Double = 1
    var subcategoriesData: Data = Data()

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
    var id: UUID = UUID()
    var typeRaw: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var categoryId: UUID = UUID()
    var categoryName: String = ""
    var subcategoryId: UUID = UUID()
    var subcategoryName: String = ""
    var detailText: String = ""
    var walletId: UUID = UUID()
    var createdAt: Date = Date()
    var lugarData: Data?
    var subitemsData: Data?
    var cambioData: Data?
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
        liabilityId: UUID?,
        cambioData: Data? = nil
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
        self.cambioData = cambioData
        self.assetId = assetId
        self.jobId = jobId
        self.liabilityId = liabilityId
    }
}

@Model
final class AutomatedTransactionDraftEntity {
    var id: UUID = UUID()
    var sourceKindRaw: String = ""
    var typeRaw: String = ""
    var amount: Double = 0
    var currencyRaw: String = ""
    var occurredAt: Date = Date()
    var rawMessage: String = ""
    var suggestedName: String?
    var counterpartyName: String?
    var note: String?
    var externalIdentifier: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID,
        sourceKindRaw: String,
        typeRaw: String,
        amount: Double,
        currencyRaw: String,
        occurredAt: Date,
        rawMessage: String,
        suggestedName: String?,
        counterpartyName: String?,
        note: String?,
        externalIdentifier: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sourceKindRaw = sourceKindRaw
        self.typeRaw = typeRaw
        self.amount = amount
        self.currencyRaw = currencyRaw
        self.occurredAt = occurredAt
        self.rawMessage = rawMessage
        self.suggestedName = suggestedName
        self.counterpartyName = counterpartyName
        self.note = note
        self.externalIdentifier = externalIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class LugarEntity {
    var id: UUID = UUID()
    var nombre: String = ""
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
    var id: UUID = UUID()
    var nombre: String = ""
    var motivo: String = ""
    var monto: Double = 0
    var monedaRaw: String = ""
    var plazoMeses: Int?
    var createdAt: Date = Date()
    var lastEstimateData: Data?
    var montoOriginal: Double = 0
    var pagosData: Data = Data()

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
    var key: String = ""
    var nombre: String = ""
    var avatarData: Data?
    var situacionFinanciera: String = ""
    var estrategiaFinanciera: String = ""
    var accentColorHex: String?
    var automationWalletId: UUID?

    init(
        key: String,
        nombre: String,
        avatarData: Data?,
        situacionFinanciera: String,
        estrategiaFinanciera: String,
        accentColorHex: String?,
        automationWalletId: UUID?
    ) {
        self.key = key
        self.nombre = nombre
        self.avatarData = avatarData
        self.situacionFinanciera = situacionFinanciera
        self.estrategiaFinanciera = estrategiaFinanciera
        self.accentColorHex = accentColorHex
        self.automationWalletId = automationWalletId
    }
}

@Model
final class SavingsGoalEntity {
    var id: UUID = UUID()
    var nombre: String = ""
    var descripcionText: String = ""
    var precioObjetivo: Double = 0
    var monedaRaw: String = ""
    var imagenData: Data?
    var productURL: String?
    var ahorrado: Double = 0
    var createdAt: Date = Date()
    var contribucionesData: Data = Data()
    var aporteInicialModeRaw: String = SavingsProjectionMode.percentage.rawValue
    var baseInicialManual: Double = 0
    var aporteInicialPorcentaje: Double = 0
    var aporteInicialCantidadManual: Double = 0
    var aportePronosticoModeRaw: String = SavingsProjectionMode.percentage.rawValue
    var aportePronosticoPorcentaje: Double = 0
    var aportePronosticoCantidadManual: Double = 0

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
        contribucionesData: Data,
        aporteInicialModeRaw: String,
        baseInicialManual: Double,
        aporteInicialPorcentaje: Double,
        aporteInicialCantidadManual: Double,
        aportePronosticoModeRaw: String,
        aportePronosticoPorcentaje: Double,
        aportePronosticoCantidadManual: Double
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
        self.aporteInicialModeRaw = aporteInicialModeRaw
        self.baseInicialManual = baseInicialManual
        self.aporteInicialPorcentaje = aporteInicialPorcentaje
        self.aporteInicialCantidadManual = aporteInicialCantidadManual
        self.aportePronosticoModeRaw = aportePronosticoModeRaw
        self.aportePronosticoPorcentaje = aportePronosticoPorcentaje
        self.aportePronosticoCantidadManual = aportePronosticoCantidadManual
    }
}

@Model
final class AssetEntity {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var monthlyEstimatesData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var monthlyEstimatesData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var monthlyEstimatesData: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
final class ValuableObjectEntity {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var estimatedValue: Double = 0
    var currencyRaw: String = ""
    var forSale: Bool = false
    var imageData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(id: UUID, name: String, notes: String, estimatedValue: Double, currencyRaw: String, forSale: Bool, imageData: Data?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.notes = notes
        self.estimatedValue = estimatedValue
        self.currencyRaw = currencyRaw
        self.forSale = forSale
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PrestamoEntity {
    var id: UUID = UUID()
    var nombre: String = ""
    var motivo: String = ""
    var monto: Double = 0
    var monedaRaw: String = ""
    var fechaPrestamo: Date = Date()
    var fechaDevolucion: Date?
    var montoOriginal: Double = 0
    var cobrosData: Data = Data()
    var createdAt: Date = Date()

    init(
        id: UUID,
        nombre: String,
        motivo: String,
        monto: Double,
        monedaRaw: String,
        fechaPrestamo: Date,
        fechaDevolucion: Date?,
        montoOriginal: Double,
        cobrosData: Data,
        createdAt: Date
    ) {
        self.id = id
        self.nombre = nombre
        self.motivo = motivo
        self.monto = monto
        self.monedaRaw = monedaRaw
        self.fechaPrestamo = fechaPrestamo
        self.fechaDevolucion = fechaDevolucion
        self.montoOriginal = montoOriginal
        self.cobrosData = cobrosData
        self.createdAt = createdAt
    }
}

@Model
final class ExchangeRateCacheEntity {
    var key: String = ""
    var ratesData: Data = Data()
    var lastUpdated: Date = Date()

    init(key: String, ratesData: Data, lastUpdated: Date) {
        self.key = key
        self.ratesData = ratesData
        self.lastUpdated = lastUpdated
    }
}

@Model
final class ManualUsdRateEntity {
    var key: String = ""
    var usdToCup: Double = 0

    init(key: String, usdToCup: Double) {
        self.key = key
        self.usdToCup = usdToCup
    }
}

@Model
final class ExpenseAnalysisEntity {
    var key: String = ""
    var analysis: String = ""

    init(key: String, analysis: String) {
        self.key = key
        self.analysis = analysis
    }
}

@Model
final class SubscriptionEntity {
    var id: UUID = UUID()
    var platformName: String = ""
    var planName: String = ""
    var price: Double = 0
    var currencyRaw: String = ""
    var logoImageData: Data?
    var logoURLString: String?
    var logoImageFormat: String?
    var isShared: Bool = false
    var sharedPeopleCount: Int = 0
    var splitEqually: Bool = false
    var personalShareAmount: Double?
    var billingDay: Int = 1
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID,
        platformName: String,
        planName: String,
        price: Double,
        currencyRaw: String,
        logoImageData: Data?,
        logoURLString: String?,
        logoImageFormat: String?,
        isShared: Bool,
        sharedPeopleCount: Int,
        splitEqually: Bool,
        personalShareAmount: Double?,
        billingDay: Int,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.platformName = platformName
        self.planName = planName
        self.price = price
        self.currencyRaw = currencyRaw
        self.logoImageData = logoImageData
        self.logoURLString = logoURLString
        self.logoImageFormat = logoImageFormat
        self.isShared = isShared
        self.sharedPeopleCount = sharedPeopleCount
        self.splitEqually = splitEqually
        self.personalShareAmount = personalShareAmount
        self.billingDay = billingDay
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BudgetAllocationPresetEntity {
    var id: UUID = UUID()
    var nombre: String = ""
    var porcentajesData: Data = Data()
    var createdAt: Date = Date()

    init(id: UUID, nombre: String, porcentajesData: Data, createdAt: Date) {
        self.id = id
        self.nombre = nombre
        self.porcentajesData = porcentajesData
        self.createdAt = createdAt
    }
}

@Model
final class BudgetCategoryEntity {
    var id: UUID = UUID()
    var nombre: String = ""
    var descripcionText: String?
    var asignacionUSD: Double?
    var asignacionEUR: Double?
    var asignacionCUP: Double?
    var createdAt: Date = Date()

    init(
        id: UUID,
        nombre: String,
        descripcionText: String?,
        asignacionUSD: Double?,
        asignacionEUR: Double?,
        asignacionCUP: Double?,
        createdAt: Date
    ) {
        self.id = id
        self.nombre = nombre
        self.descripcionText = descripcionText
        self.asignacionUSD = asignacionUSD
        self.asignacionEUR = asignacionEUR
        self.asignacionCUP = asignacionCUP
        self.createdAt = createdAt
    }
}

@Model
final class SubscriptionTemplateEntity {
    var id: UUID = UUID()
    var platformName: String = ""
    var planName: String = ""
    var price: Double = 0
    var currencyRaw: String = ""
    var logoImageData: Data?
    var logoURLString: String?
    var logoImageFormat: String?
    var isShared: Bool = false
    var sharedPeopleCount: Int = 0
    var splitEqually: Bool = false
    var personalShareAmount: Double?
    var billingDay: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID,
        platformName: String,
        planName: String,
        price: Double,
        currencyRaw: String,
        logoImageData: Data?,
        logoURLString: String?,
        logoImageFormat: String?,
        isShared: Bool,
        sharedPeopleCount: Int,
        splitEqually: Bool,
        personalShareAmount: Double?,
        billingDay: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.platformName = platformName
        self.planName = planName
        self.price = price
        self.currencyRaw = currencyRaw
        self.logoImageData = logoImageData
        self.logoURLString = logoURLString
        self.logoImageFormat = logoImageFormat
        self.isShared = isShared
        self.sharedPeopleCount = sharedPeopleCount
        self.splitEqually = splitEqually
        self.personalShareAmount = personalShareAmount
        self.billingDay = billingDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

final class PersistenceManager {
    static let shared = PersistenceManager()

    enum SyncMode {
        case cloudKit
        case localFallback(String)
    }

    private static let cloudKitContainerIdentifier = "iCloud.com.ruben.Financia"

    let container: ModelContainer
    let syncMode: SyncMode

    private init() {
        // SwiftData is now a *local cache* of the FinancIA backend. The
        // backend is the source of truth across devices and for the MCP
        // server, so CloudKit sync is intentionally disabled: running
        // both would double-sync and create reconciliation headaches.
        let appSchema = Schema([
            WalletEntity.self,
            CategoryEntity.self,
            TransactionEntity.self,
            AutomatedTransactionDraftEntity.self,
            LugarEntity.self,
            DebtEntity.self,
            ProfileEntity.self,
            SavingsGoalEntity.self,
            AssetEntity.self,
            JobEntity.self,
            LiabilityEntity.self,
            ValuableObjectEntity.self,
            PrestamoEntity.self,
            ExchangeRateCacheEntity.self,
            ManualUsdRateEntity.self,
            ExpenseAnalysisEntity.self,
            SubscriptionEntity.self,
            SubscriptionTemplateEntity.self,
            BudgetCategoryEntity.self,
            BudgetAllocationPresetEntity.self
        ])

        let localConfiguration = ModelConfiguration(
            "LocalCache",
            schema: appSchema,
            cloudKitDatabase: .none
        )

        do {
            container = try ModelContainer(
                for: appSchema,
                configurations: [localConfiguration]
            )
            syncMode = .localFallback("Backend is the sync layer; SwiftData is local cache only.")
        } catch {
            fatalError("Could not create SwiftData container. \(Self.describe(error: error))")
        }
    }

    private static func describe(error: Error) -> String {
        let nsError = error as NSError
        return "[\(nsError.domain) code=\(nsError.code)] \(nsError.localizedDescription)"
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
