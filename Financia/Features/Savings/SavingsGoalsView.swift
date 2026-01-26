//
//  SavingsGoalsView.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import SwiftUI

struct SavingsGoalsView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @Environment(\.dismiss) var dismiss

    @State private var showingAddGoal = false
    @State private var selectedGoal: SavingsGoal?

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

                    Text("Ahorros")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AuroraColors.primaryText)

                    Spacer()

                    Button(action: { showingAddGoal = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AuroraColors.primaryText)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
                .padding(.bottom, 24)

                // Content
                if savingsGoalManager.savingsGoals.isEmpty {
                    emptyStateView
                } else {
                    goalsListView
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddGoal) {
            SavingsGoalEditorView()
                .environmentObject(savingsGoalManager)
        }
        .sheet(item: $selectedGoal) { goal in
            SavingsGoalDetailView(goal: goal)
                .environmentObject(savingsGoalManager)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.circle")
                .font(.system(size: 80))
                .foregroundColor(AuroraColors.secondaryText.opacity(0.3))

            Text("No tienes metas de ahorro")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(AuroraColors.primaryText)

            Text("Crea tu primera meta para comenzar a ahorrar")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(AuroraColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer()
        }
    }

    private var goalsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(savingsGoalManager.savingsGoals) { goal in
                    SavingsGoalCard(goal: goal)
                        .onTapGesture {
                            selectedGoal = goal
                        }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

struct SavingsGoalCard: View {
    let goal: SavingsGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Imagen o placeholder
                if let imageData = goal.imagenData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(AuroraColors.secondaryText.opacity(0.5))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.nombre)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AuroraColors.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("\(goal.moneda.symbol)\(String(format: "%.2f", goal.ahorrado))")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(goal.alcanzado ? .green : AuroraColors.primaryText)

                        Text("de \(goal.moneda.symbol)\(String(format: "%.2f", goal.precioObjetivo))")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(AuroraColors.secondaryText)
                    }

                    if goal.alcanzado {
                        Text("¡Meta alcanzada!")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                Text("\(Int(goal.porcentajeCompletado))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AuroraColors.primaryText)
            }

            // Barra de progreso
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: goal.alcanzado ? [.green, .green.opacity(0.7)] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (goal.porcentajeCompletado / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

#Preview {
    SavingsGoalsView()
        .environmentObject(SavingsGoalManager.shared)
}
