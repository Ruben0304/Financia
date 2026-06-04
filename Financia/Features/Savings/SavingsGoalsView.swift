import SwiftUI

struct SavingsGoalsView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @State private var showingAddGoal = false
    @StateObject private var analysisManager = SavingsGoalAnalysisManager()
    @State private var analyzedGoalID: UUID?
    @State private var showsGlobalAnalysis = false
    @State private var isShowingAnalysisBorder = false

    private var activeGoals: [SavingsGoal] {
        savingsGoalManager.savingsGoals.filter { !$0.alcanzado }
    }

    var body: some View {
        ZStack {
            List {
                if showsGlobalAnalysis && (analysisManager.isAnalyzing || analysisManager.latestAnalysis != nil || analysisManager.lastErrorMessage != nil) {
                    Section {
                        globalAnalysisCard
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .listRowBackground(Color.clear)
                    }
                }

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
                            goalRow(goal)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await analyzeAllGoalsFromPullGesture()
            }

            if isShowingAnalysisBorder {
                SavingsAnalysisBorderOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: analyzedGoalID)
        .animation(.easeInOut(duration: 0.25), value: isShowingAnalysisBorder)
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

    @ViewBuilder
    private func goalRow(_ goal: SavingsGoal) -> some View {
        if analyzedGoalID == goal.id {
            savingsGoalAnalysisRow(for: goal)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
        } else {
            NavigationLink {
                SavingsGoalDetailView(goal: goal)
            } label: {
                SavingsGoalRow(goal: goal)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    triggerSingleGoalAnalysis(for: goal)
                } label: {
                    Label("Analizar", systemImage: "sparkles")
                }
                .tint(Color(hex: "0EA5E9"))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    savingsGoalManager.deleteSavingsGoal(goal)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
        }
    }

    private func triggerSingleGoalAnalysis(for goal: SavingsGoal) {
        showsGlobalAnalysis = false
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            analyzedGoalID = goal.id
        }
        analysisManager.analyzeSingleGoal(goal)
    }

    private func analyzeAllGoalsFromPullGesture() async {
        guard !activeGoals.isEmpty else { return }

        analyzedGoalID = nil
        showsGlobalAnalysis = true
        isShowingAnalysisBorder = true
        analysisManager.analyzeActiveGoals(activeGoals)

        while analysisManager.isAnalyzing {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.easeInOut(duration: 0.25)) {
            isShowingAnalysisBorder = false
        }
    }

    private func dismissAnalysisCard() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            analyzedGoalID = nil
            showsGlobalAnalysis = false
        }
    }

    private func savingsGoalAnalysisRow(for goal: SavingsGoal) -> some View {
        SavingsGoalAIResultCard(
            title: goal.nombre,
            subtitle: analysisManager.isAnalyzing ? "Leyendo saldos, reservas y pronósticos" : "Diagnóstico individual",
            badgeText: "\(Int(goal.porcentajeCompletado))% completado",
            amountText: goal.montoPendiente.formatted(.currency(code: goal.moneda.rawValue)),
            amountLabel: "Restante",
            analysis: analyzedGoalID == goal.id ? analysisManager.latestAnalysis : nil,
            isLoading: analysisManager.isAnalyzing && analyzedGoalID == goal.id,
            errorMessage: analyzedGoalID == goal.id ? analysisManager.lastErrorMessage : nil,
            palette: [
                Color(hex: "38BDF8"),
                Color(hex: "0EA5E9"),
                Color(hex: "22C55E"),
                Color(hex: "A3E635")
            ],
            primaryActionTitle: "Abrir meta",
            secondaryActionTitle: "Cerrar",
            onPrimaryAction: { },
            onSecondaryAction: dismissAnalysisCard,
            destination: AnyView(SavingsGoalDetailView(goal: goal))
        )
    }

    private var globalAnalysisCard: some View {
        SavingsGoalAIResultCard(
            title: "Panorama de metas",
            subtitle: analysisManager.isAnalyzing ? "Análisis global activado al tirar hacia abajo" : "Lectura conjunta de todas tus metas activas",
            badgeText: "\(activeGoals.count) activas",
            amountText: activeGoals.reduce(0) { $0 + $1.montoPendiente }.formatted(.number.precision(.fractionLength(0...2))),
            amountLabel: "Restante total",
            analysis: showsGlobalAnalysis ? analysisManager.latestAnalysis : nil,
            isLoading: analysisManager.isAnalyzing && showsGlobalAnalysis,
            errorMessage: showsGlobalAnalysis ? analysisManager.lastErrorMessage : nil,
            palette: [
                Color(hex: "F97316"),
                Color(hex: "FB7185"),
                Color(hex: "38BDF8"),
                Color(hex: "A855F7")
            ],
            primaryActionTitle: "Mantener visible",
            secondaryActionTitle: "Ocultar",
            onPrimaryAction: { },
            onSecondaryAction: dismissAnalysisCard,
            destination: nil
        )
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

private struct SavingsGoalAIResultCard: View {
    let title: String
    let subtitle: String
    let badgeText: String
    let amountText: String
    let amountLabel: String
    let analysis: String?
    let isLoading: Bool
    let errorMessage: String?
    let palette: [Color]
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let destination: AnyView?

    @State private var isExpanded = false
    @State private var pulsing = false

    private var accentColor: Color { palette.first ?? .blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .opacity(isLoading ? (pulsing ? 0.4 : 1.0) : 1.0)
                    .animation(
                        isLoading
                            ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                            : .default,
                        value: pulsing
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badgeText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.10), in: Capsule())

                Button(action: onSecondaryAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color(.systemFill), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 11)

            Divider()
                .padding(.horizontal, 14)

            // Analysis content
            Group {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.75)
                        Text("Procesando contexto financiero...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                } else if let analysis, !analysis.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(analysis)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(.easeInOut(duration: 0.22), value: isExpanded)

                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "Cerrar" : "Ver análisis completo")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                }
            }

            // Optional navigation link
            if let destination, !isLoading {
                Divider()
                    .padding(.horizontal, 14)

                NavigationLink {
                    destination
                } label: {
                    HStack {
                        Text(primaryActionTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded(onPrimaryAction))
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .onAppear {
            if isLoading { pulsing = true }
        }
        .onChange(of: isLoading) { loading in
            pulsing = loading
        }
    }
}

private struct SavingsAnalysisBorderOverlay: View {
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [
                        Color(hex: "38BDF8").opacity(0.6),
                        Color(hex: "22C55E").opacity(0.5),
                        Color(hex: "F97316").opacity(0.5),
                        Color(hex: "FB7185").opacity(0.6),
                        Color(hex: "A855F7").opacity(0.5),
                        Color(hex: "38BDF8").opacity(0.6)
                    ],
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: 2
            )
            .blur(radius: 1)
            .padding(8)
            .ignoresSafeArea()
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
