import SwiftUI

struct SavingsGoalsView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @State private var showingAddGoal = false

    var body: some View {
        List {
            if savingsGoalManager.savingsGoals.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No tienes metas de ahorro")
                            .font(.headline)

                        Text("Crea tu primera meta para comenzar a ahorrar.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("Tus metas") {
                    ForEach(savingsGoalManager.savingsGoals) { goal in
                        NavigationLink {
                            SavingsGoalDetailView(goal: goal)
                        } label: {
                            SavingsGoalRow(goal: goal)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { savingsGoalManager.savingsGoals[$0] }.forEach { goal in
                            savingsGoalManager.deleteSavingsGoal(goal)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ahorros")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            SavingsGoalEditorView()
                .environmentObject(savingsGoalManager)
        }
    }
}

private struct SavingsGoalRow: View {
    let goal: SavingsGoal

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = goal.imagenData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "star.fill")
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.nombre)
                    .font(.headline)
                Text("\(goal.moneda.symbol)\(String(format: "%.2f", goal.ahorrado)) de \(goal.moneda.symbol)\(String(format: "%.2f", goal.precioObjetivo))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(goal.porcentajeCompletado))%")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(goal.alcanzado ? Color(red: 0.20, green: 0.60, blue: 0.46) : .primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SavingsGoalsView()
            .environmentObject(SavingsGoalManager.shared)
    }
}
