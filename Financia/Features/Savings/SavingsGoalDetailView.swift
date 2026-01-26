import SwiftUI
import LinkPresentation

struct SavingsGoalDetailView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @EnvironmentObject var walletManager: WalletManager

    let goal: SavingsGoal

    @State private var showingAddContribution = false

    private var currentGoal: SavingsGoal {
        savingsGoalManager.savingsGoals.first(where: { $0.id == goal.id }) ?? goal
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    if let imageData = currentGoal.imagenData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else if let urlString = currentGoal.productURL,
                              let url = URL(string: urlString) {
                        LinkPreviewView(url: url)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    VStack(spacing: 6) {
                        Text(currentGoal.nombre)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)

                        if !currentGoal.descripcion.isEmpty {
                            Text(currentGoal.descripcion)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Progreso") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ahorrado")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currentGoal.ahorrado, format: .currency(code: currentGoal.moneda.rawValue))
                                .font(.headline)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Meta")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currentGoal.precioObjetivo, format: .currency(code: currentGoal.moneda.rawValue))
                                .font(.headline)
                        }
                    }

                    ProgressView(value: currentGoal.porcentajeCompletado, total: 100)
                        .tint(currentGoal.alcanzado ? Color(red: 0.20, green: 0.60, blue: 0.46) : .blue)

                    HStack {
                        Text("\(Int(currentGoal.porcentajeCompletado))% completado")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if currentGoal.alcanzado {
                            Text("Meta alcanzada")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(red: 0.20, green: 0.60, blue: 0.46))
                        } else {
                            Text("Faltan \(currentGoal.montoPendiente.formatted(.currency(code: currentGoal.moneda.rawValue)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !currentGoal.alcanzado {
                Section {
                    Button {
                        showingAddContribution = true
                    } label: {
                        Label("Agregar dinero", systemImage: "plus.circle.fill")
                    }
                }
            }

            if let link = currentGoal.productURL,
               let url = URL(string: link) {
                Section("Link") {
                    Link(destination: url) {
                        Text(link)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                    }
                }
            }

            if !currentGoal.contribuciones.isEmpty {
                Section("Historial de aportes") {
                    ForEach(currentGoal.contribuciones.sorted { $0.fecha > $1.fecha }) { contribution in
                        ContributionRow(contribution: contribution, currency: currentGoal.moneda)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Meta de ahorro")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddContribution) {
            AddContributionSheet(goal: currentGoal)
                .environmentObject(savingsGoalManager)
                .environmentObject(walletManager)
        }
    }
}

private struct AddContributionSheet: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal

    @State private var contributionAmount: String = ""
    @State private var selectedWallet: Wallet?
    @State private var contributionNote: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto") {
                    TextField("0.00", text: $contributionAmount)
                        .keyboardType(.decimalPad)
                }

                Section("Cartera") {
                    Picker("Cartera", selection: $selectedWallet) {
                        ForEach(walletManager.wallets.filter { $0.currency == goal.moneda }) { wallet in
                            Text(wallet.name).tag(wallet as Wallet?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Nota") {
                    TextField("Opcional", text: $contributionNote)
                }
            }
            .navigationTitle("Agregar dinero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveContribution()
                    }
                    .disabled(!canSaveContribution)
                }
            }
            .alert("No se pudo guardar", isPresented: $showError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(errorMessage)
            })
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .onAppear {
                selectedWallet = walletManager.wallets.first { $0.currency == goal.moneda }
            }
        }
    }

    private var canSaveContribution: Bool {
        guard let amount = parseAmount(contributionAmount), amount > 0,
              let wallet = selectedWallet else {
            return false
        }
        return walletManager.calculateBalance(for: wallet) >= amount
    }

    private func saveContribution() {
        guard let amount = parseAmount(contributionAmount), amount > 0 else {
            showErrorMessage("Ingresa un monto válido.")
            return
        }
        guard let wallet = selectedWallet else {
            showErrorMessage("Selecciona una cartera.")
            return
        }
        let available = walletManager.calculateBalance(for: wallet)
        guard available >= amount else {
            showErrorMessage("El saldo de la cartera no es suficiente.")
            return
        }

        let contribution = SavingsContribution(
            monto: amount,
            walletId: wallet.id,
            nota: contributionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contributionNote
        )

        savingsGoalManager.addContribution(to: goal.id, contribution: contribution)
        dismiss()
    }

    private func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

private struct ContributionRow: View {
    let contribution: SavingsContribution
    let currency: Currency

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(contribution.fecha, style: .date)
                    .font(.subheadline.weight(.semibold))
                if let nota = contribution.nota {
                    Text(nota)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(contribution.monto, format: .currency(code: currency.rawValue))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(red: 0.20, green: 0.60, blue: 0.46))
        }
        .padding(.vertical, 4)
    }
}

// LinkPresentation View para preview
struct LinkPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(url: url)
        let provider = LPMetadataProvider()

        provider.startFetchingMetadata(for: url) { metadata, _ in
            if let metadata {
                DispatchQueue.main.async {
                    linkView.metadata = metadata
                }
            }
        }

        return linkView
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}

#Preview {
    NavigationStack {
        let goal = SavingsGoal(
            nombre: "iPhone 15 Pro",
            descripcion: "Color azul titanio, 256GB",
            precioObjetivo: 1200,
            moneda: .usd,
            ahorrado: 350
        )
        SavingsGoalDetailView(goal: goal)
            .environmentObject(SavingsGoalManager.shared)
            .environmentObject(WalletManager.shared)
    }
}
