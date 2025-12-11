import Foundation
import SwiftUI

struct CategoriesData {
    static let expenseCategories: [TransactionCategory] = [
        TransactionCategory(name: "Vivienda", subcategories: [
            Subcategory(name: "Alquiler"),
            Subcategory(name: "Hipoteca"),
            Subcategory(name: "Servicios (luz, agua, gas)"),
            Subcategory(name: "Internet y telefonía"),
            Subcategory(name: "Mantenimiento del hogar")
        ], icon: "house.fill", color: .blue),
        TransactionCategory(name: "Alimentación", subcategories: [
            Subcategory(name: "Supermercado"),
            Subcategory(name: "Restaurantes"),
            Subcategory(name: "Cafeterías"),
            Subcategory(name: "Snacks"),
            Subcategory(name: "Delivery")
        ], icon: "fork.knife.circle.fill", color: .yellow),
        TransactionCategory(name: "Transporte", subcategories: [
            Subcategory(name: "Combustible"),
            Subcategory(name: "Transporte público"),
            Subcategory(name: "Mantenimiento del vehículo"),
            Subcategory(name: "Peajes"),
            Subcategory(name: "Estacionamiento")
        ], icon: "car.fill", color: .orange),
        TransactionCategory(name: "Salud", subcategories: [
            Subcategory(name: "Consultas médicas"),
            Subcategory(name: "Medicamentos"),
            Subcategory(name: "Exámenes"),
            Subcategory(name: "Tratamientos"),
            Subcategory(name: "Seguro médico")
        ], icon: "heart.fill", color: .red),
        TransactionCategory(name: "Educación", subcategories: [
            Subcategory(name: "Matrícula"),
            Subcategory(name: "Libros"),
            Subcategory(name: "Material escolar"),
            Subcategory(name: "Cursos"),
            Subcategory(name: "Certificaciones")
        ], icon: "book.fill", color: .green),
        TransactionCategory(name: "Entretenimiento", subcategories: [
            Subcategory(name: "Cine"),
            Subcategory(name: "Eventos"),
            Subcategory(name: "Suscripciones"),
            Subcategory(name: "Videojuegos"),
            Subcategory(name: "Recreación")
        ], icon: "gamecontroller.fill", color: .purple),
        TransactionCategory(name: "Finanzas personales", subcategories: [
            Subcategory(name: "Intereses"),
            Subcategory(name: "Comisiones bancarias"),
            Subcategory(name: "Pagos de deudas"),
            Subcategory(name: "Multas"),
            Subcategory(name: "Seguros")
        ], icon: "banknote.fill", color: .indigo)
    ]

    static let incomeCategories: [TransactionCategory] = [
        TransactionCategory(name: "Salario", subcategories: [
            Subcategory(name: "Sueldo base"),
            Subcategory(name: "Horas extra"),
            Subcategory(name: "Bonificaciones"),
            Subcategory(name: "Comisiones"),
            Subcategory(name: "Ajustes salariales")
        ], icon: "dollarsign.circle.fill", color: .green),
        TransactionCategory(name: "Negocios", subcategories: [
            Subcategory(name: "Ventas"),
            Subcategory(name: "Servicios prestados"),
            Subcategory(name: "Ganancias netas"),
            Subcategory(name: "Clientes recurrentes"),
            Subcategory(name: "Proyectos especiales")
        ], icon: "briefcase.fill", color: .brown),
        TransactionCategory(name: "Inversiones", subcategories: [
            Subcategory(name: "Dividendos"),
            Subcategory(name: "Intereses"),
            Subcategory(name: "Rendimientos bursátiles"),
            Subcategory(name: "Criptomonedas"),
            Subcategory(name: "Fondos de inversión")
        ], icon: "chart.bar.fill", color: .purple),
        TransactionCategory(name: "Alquileres", subcategories: [
            Subcategory(name: "Inmuebles"),
            Subcategory(name: "Habitaciones"),
            Subcategory(name: "Vehículos"),
            Subcategory(name: "Maquinaria"),
            Subcategory(name: "Espacios comerciales")
        ], icon: "building.2.fill", color: .cyan),
        TransactionCategory(name: "Reembolsos", subcategories: [
            Subcategory(name: "Gastos laborales"),
            Subcategory(name: "Seguros"),
            Subcategory(name: "Garantías"),
            Subcategory(name: "Errores de cobro"),
            Subcategory(name: "Viáticos")
        ], icon: "gobackward", color: .mint),
        TransactionCategory(name: "Regalías", subcategories: [
            Subcategory(name: "Propiedad intelectual"),
            Subcategory(name: "Música"),
            Subcategory(name: "Libros"),
            Subcategory(name: "Software"),
            Subcategory(name: "Licencias")
        ], icon: "music.note.list", color: .pink),
        TransactionCategory(name: "Otros ingresos", subcategories: [
            Subcategory(name: "Regalos"),
            Subcategory(name: "Premios"),
            Subcategory(name: "Herencias"),
            Subcategory(name: "Crowdfunding"),
            Subcategory(name: "Subsidios")
        ], icon: "ellipsis.circle.fill", color: .gray)
    ]
}