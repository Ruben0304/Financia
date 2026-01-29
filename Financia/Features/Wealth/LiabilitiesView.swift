import SwiftUI

struct LiabilitiesView: View {
    @EnvironmentObject private var wealthManager: WealthManager
    @State private var isAddingLiability = false

    var body: some View {
        List {
            if wealthManager.liabilities.isEmpty {
                Text("No hay pasivos registrados.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(wealthManager.liabilities) { liability in
                    NavigationLink {
                        LiabilityDetailView(liability: liability)
                    } label: {
                        HStack {
                            Text(liability.name)
                            Spacer()
                            Text(liability.monthlyEstimates.isEmpty ? "—" : "Estimado")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indices in
                    indices.map { wealthManager.liabilities[$0] }.forEach(wealthManager.deleteLiability)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pasivos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingLiability = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingLiability) {
            LiabilityEditorView { liability in
                wealthManager.addLiability(liability)
            }
        }
    }
}

struct LiabilityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var estimates: [MonthlyEstimate] = []

    let onSave: (Liability) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        formCard
                        estimatesCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Nuevo pasivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let liability = Liability(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            monthlyEstimates: estimates
                        )
                        onSave(liability)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: "Nombre") {
                TextField("Ej. Préstamo, Auto", text: $name)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            field(label: "Notas") {
                TextField("Opcional", text: $notes, axis: .vertical)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var estimatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimado mensual")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            MonthlyEstimateEditor(estimates: $estimates)
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DarkFinanceColors.secondaryText)
            content()
        }
    }
}
