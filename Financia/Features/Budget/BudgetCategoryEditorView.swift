import SwiftUI

struct BudgetCategoryEditorView: View {
    @EnvironmentObject var budgetManager: BudgetManager
    @Environment(\.dismiss) private var dismiss

    var category: BudgetCategory?

    @State private var nombre = ""
    @State private var descripcion = ""

    private var isEditing: Bool { category != nil }
    private var canSave: Bool { !nombre.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $nombre)
                    TextField("Descripción (opcional)", text: $descripcion)
                } footer: {
                    Text("Los montos se asignan directamente desde la pantalla de presupuesto.")
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
            .onAppear {
                nombre = category?.nombre ?? ""
                descripcion = category?.descripcion ?? ""
            }
        }
    }

    private func save() {
        let nombre = nombre.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }

        if var existing = category {
            existing.nombre = nombre
            existing.descripcion = descripcion.isEmpty ? nil : descripcion
            budgetManager.updateCategory(existing)
        } else {
            budgetManager.addCategory(BudgetCategory(
                nombre: nombre,
                descripcion: descripcion.isEmpty ? nil : descripcion
            ))
        }
        dismiss()
    }
}
