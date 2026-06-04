//
//  SavingsModels.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import Foundation
import SwiftUI

enum SavingsProjectionMode: String, Codable, CaseIterable {
    case percentage
    case manualAmount
}

struct SavingsGoal: Identifiable, Codable {
    var id: UUID
    var nombre: String
    var descripcion: String
    var precioObjetivo: Double
    var moneda: Currency
    var imagenData: Data?          // Foto local opcional
    var productURL: String?         // URL del producto (opcional)
    var ahorrado: Double            // Progreso actual
    var createdAt: Date
    var contribuciones: [SavingsContribution]
    var aporteInicialMode: SavingsProjectionMode
    var baseInicialManual: Double
    var aporteInicialPorcentaje: Double
    var aporteInicialCantidadManual: Double
    var aportePronosticoMode: SavingsProjectionMode
    var aportePronosticoPorcentaje: Double
    var aportePronosticoCantidadManual: Double

    init(
        id: UUID = UUID(),
        nombre: String,
        descripcion: String = "",
        precioObjetivo: Double,
        moneda: Currency,
        imagenData: Data? = nil,
        productURL: String? = nil,
        ahorrado: Double = 0.0,
        createdAt: Date = Date(),
        contribuciones: [SavingsContribution] = [],
        aporteInicialMode: SavingsProjectionMode = .percentage,
        baseInicialManual: Double = 0,
        aporteInicialPorcentaje: Double = 0,
        aporteInicialCantidadManual: Double = 0,
        aportePronosticoMode: SavingsProjectionMode = .percentage,
        aportePronosticoPorcentaje: Double = 0,
        aportePronosticoCantidadManual: Double = 0
    ) {
        self.id = id
        self.nombre = nombre
        self.descripcion = descripcion
        self.precioObjetivo = precioObjetivo
        self.moneda = moneda
        self.imagenData = imagenData
        self.productURL = productURL
        self.ahorrado = ahorrado
        self.createdAt = createdAt
        self.contribuciones = contribuciones
        self.aporteInicialMode = aporteInicialMode
        self.baseInicialManual = baseInicialManual
        self.aporteInicialPorcentaje = aporteInicialPorcentaje
        self.aporteInicialCantidadManual = aporteInicialCantidadManual
        self.aportePronosticoMode = aportePronosticoMode
        self.aportePronosticoPorcentaje = aportePronosticoPorcentaje
        self.aportePronosticoCantidadManual = aportePronosticoCantidadManual
    }

    // Porcentaje de progreso
    var porcentajeCompletado: Double {
        guard precioObjetivo > 0 else { return 0 }
        return min((ahorrado / precioObjetivo) * 100, 100)
    }

    // Cantidad restante
    var montoPendiente: Double {
        max(precioObjetivo - ahorrado, 0)
    }

    // Estado alcanzado
    var alcanzado: Bool {
        ahorrado >= precioObjetivo
    }
}

struct SavingsContribution: Identifiable, Codable {
    var id: UUID
    var monto: Double
    var fecha: Date
    var walletId: UUID
    var nota: String?

    init(
        id: UUID = UUID(),
        monto: Double,
        fecha: Date = Date(),
        walletId: UUID,
        nota: String? = nil
    ) {
        self.id = id
        self.monto = monto
        self.fecha = fecha
        self.walletId = walletId
        self.nota = nota
    }
}
