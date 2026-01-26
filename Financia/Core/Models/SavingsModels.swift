//
//  SavingsModels.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import Foundation
import SwiftUI

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
        contribuciones: [SavingsContribution] = []
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
