//
//  SavingsGoalDetailView.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import SwiftUI
import LinkPresentation

struct SavingsGoalDetailView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) var dismiss

    let goal: SavingsGoal

    @State private var showingAddContribution = false
    @State private var contributionAmount: String = ""
    @State private var selectedWallet: Wallet?
    @State private var contributionNote: String = ""

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AuroraColors.primaryText)
                    }

                    Spacer()

                    Button(action: { /* TODO: Edit */ }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(AuroraColors.primaryText)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 24) {
                        // Imagen o preview de URL
                        if let imageData = goal.imagenData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal, 32)
                        } else if let urlString = goal.productURL,
                                  let url = URL(string: urlString) {
                            LinkPreviewView(url: url)
                                .frame(height: 250)
                                .padding(.horizontal, 32)
                        }

                        // Información principal
                        VStack(spacing: 12) {
                            Text(goal.nombre)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(AuroraColors.primaryText)
                                .multilineTextAlignment(.center)

                            if !goal.descripcion.isEmpty {
                                Text(goal.descripcion)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(AuroraColors.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 32)

                        // Progreso
                        progressCardView

                        // Botón agregar contribución
                        if !goal.alcanzado {
                            Button(action: { showingAddContribution = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Agregar dinero")
                                }
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }
                            .padding(.horizontal, 32)
                        }

                        // Historial de contribuciones
                        if !goal.contribuciones.isEmpty {
                            contributionsListView
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddContribution) {
            addContributionSheet
        }
        .onAppear {
            selectedWallet = walletManager.wallets.first { $0.currency == goal.moneda }
        }
    }

    private var progressCardView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ahorrado")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AuroraColors.secondaryText)

                    Text("\(goal.moneda.symbol)\(String(format: "%.2f", goal.ahorrado))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(goal.alcanzado ? .green : AuroraColors.primaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Meta")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AuroraColors.secondaryText)

                    Text("\(goal.moneda.symbol)\(String(format: "%.2f", goal.precioObjetivo))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AuroraColors.primaryText)
                }
            }

            // Barra de progreso
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: goal.alcanzado ? [.green, .green.opacity(0.7)] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (goal.porcentajeCompletado / 100), height: 16)
                }
            }
            .frame(height: 16)

            HStack {
                Text("\(Int(goal.porcentajeCompletado))% completado")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AuroraColors.secondaryText)

                Spacer()

                if !goal.alcanzado {
                    Text("Faltan \(goal.moneda.symbol)\(String(format: "%.2f", goal.montoPendiente))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AuroraColors.secondaryText)
                } else {
                    Text("¡Meta alcanzada!")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 32)
    }

    private var contributionsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historial de aportes")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(AuroraColors.primaryText)
                .padding(.horizontal, 32)

            ForEach(goal.contribuciones.reversed()) { contribution in
                ContributionRow(contribution: contribution)
            }
            .padding(.horizontal, 32)
        }
    }

    private var addContributionSheet: some View {
        NavigationView {
            ZStack {
                AuroraBackground()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monto a agregar")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AuroraColors.secondaryText)

                        TextField("0.00", text: $contributionAmount)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(AuroraColors.primaryText)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }

                    if let wallet = selectedWallet {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Desde la cartera")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AuroraColors.secondaryText)

                            Picker("Cartera", selection: $selectedWallet) {
                                ForEach(walletManager.wallets.filter { $0.currency == goal.moneda }) { wallet in
                                    Text("\(wallet.name) (\(wallet.currency.symbol)\(String(format: "%.2f", wallet.balance)))")
                                        .tag(wallet as Wallet?)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .tint(AuroraColors.primaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nota (opcional)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AuroraColors.secondaryText)

                        TextField("Ej: Aporte del mes", text: $contributionNote)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(AuroraColors.primaryText)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }

                    Spacer()

                    Button(action: saveContribution) {
                        Text("Agregar")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: canSaveContribution ? [.blue, .purple] : [.gray, .gray.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .disabled(!canSaveContribution)
                }
                .padding(32)
            }
            .navigationTitle("Agregar Dinero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        showingAddContribution = false
                    }
                    .foregroundColor(AuroraColors.primaryText)
                }
            }
        }
    }

    private var canSaveContribution: Bool {
        guard let amount = Double(contributionAmount), amount > 0,
              let wallet = selectedWallet else {
            return false
        }
        return wallet.balance >= amount
    }

    private func saveContribution() {
        guard canSaveContribution,
              let amount = Double(contributionAmount),
              let wallet = selectedWallet else {
            return
        }

        let contribution = SavingsContribution(
            monto: amount,
            walletId: wallet.id,
            nota: contributionNote.isEmpty ? nil : contributionNote
        )

        savingsGoalManager.addContribution(to: goal.id, contribution: contribution)
        showingAddContribution = false
        contributionAmount = ""
        contributionNote = ""
        dismiss()
    }
}

struct ContributionRow: View {
    let contribution: SavingsContribution

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(contribution.fecha, style: .date)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AuroraColors.primaryText)

                if let nota = contribution.nota {
                    Text(nota)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AuroraColors.secondaryText)
                }
            }

            Spacer()

            Text("+\(String(format: "%.2f", contribution.monto))")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// LinkPresentation View para preview estilo iMessage
struct LinkPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(url: url)
        let provider = LPMetadataProvider()

        provider.startFetchingMetadata(for: url) { metadata, error in
            if let metadata = metadata {
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
    let goal = SavingsGoal(
        nombre: "iPhone 15 Pro",
        descripcion: "Color azul titanio, 256GB",
        precioObjetivo: 1200,
        moneda: .usd,
        ahorrado: 350
    )

    return SavingsGoalDetailView(goal: goal)
        .environmentObject(SavingsGoalManager.shared)
        .environmentObject(WalletManager.shared)
}
