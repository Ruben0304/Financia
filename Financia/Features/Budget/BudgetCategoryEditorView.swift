import SwiftUI

struct BudgetCategoryEditorView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.dismiss) private var dismiss

    var category: BudgetCategory?

    @State private var nombre: String = ""
    @State private var descripcion: String = ""
    @State private var usdAmount: String = ""
    @State private var eurAmount: String = ""
    @State private var cupAmount: String = ""

    private var isEditing: Bool { category != nil }
    private var canSave: Bool { !nombre.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Nombre", text: $nombre)
                    TextField("Descripción (opcional)", text: $descripcion)
                }

                Section {
                    amountRow(label: "USD", symbol: "$", text: $usdAmount)
                    amountRow(label: "EUR", symbol: "€", text: $eurAmount)
                    amountRow(label: "CUP", symbol: "₱", text: $cupAmount)
                } header: {
                    Text("Montos a asignar")
                } footer: {
                    Text("Puedes asignar en una o varias monedas. El campo vacío o en 0 se ignora.")
                }
            }
            .navigationTitle(isEditing ? "Editar categoría" : "Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    // MARK: - Row

    private func amountRow(label: String, symbol: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                Text(symbol)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                TextField("0.00", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
            }
        }
    }

    // MARK: - Logic

    private func prefill() {
        guard let cat = category else { return }
        nombre = cat.nombre
        descripcion = cat.descripcion ?? ""
        if let v = cat.asignaciones.usd, v > 0 { usdAmount = fmt(v) }
        if let v = cat.asignaciones.eur, v > 0 { eurAmount = fmt(v) }
        if let v = cat.asignaciones.cup, v > 0 { cupAmount = fmt(v) }
    }

    private func save() {
        let nombre = nombre.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }

        let asignaciones = BudgetAsignaciones(
            usd: parse(usdAmount),
            eur: parse(eurAmount),
            cup: parse(cupAmount)
        )

        if var existing = category {
            existing.nombre = nombre
            existing.descripcion = descripcion.isEmpty ? nil : descripcion
            existing.asignaciones = asignaciones
            budgetManager.updateCategory(existing)
        } else {
            budgetManager.addCategory(BudgetCategory(
                nombre: nombre,
                descripcion: descripcion.isEmpty ? nil : descripcion,
                asignaciones: asignaciones
            ))
        }
        dismiss()
    }

    private func parse(_ text: String) -> Double? {
        let v = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
        return v > 0 ? v : nil
    }

    private func fmt(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
