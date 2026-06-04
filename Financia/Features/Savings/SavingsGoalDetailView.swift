import SwiftUI
import LinkPresentation

struct SavingsGoalDetailView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @EnvironmentObject var wealthManager: WealthManager
    @EnvironmentObject var profileManager: ProfileManager

    let goal: SavingsGoal

    @State private var aporteInicialMode: SavingsProjectionMode = .percentage
    @State private var baseInicialManual: Double = 0
    @State private var aporteInicialPorcentaje: Double = 0
    @State private var aporteInicialCantidadManual: Double = 0
    @State private var aportePronosticoMode: SavingsProjectionMode = .percentage
    @State private var aportePronosticoPorcentaje: Double = 0
    @State private var aportePronosticoCantidadManual: Double = 0
    @State private var didLoadProjectionState = false

    private var currentGoal: SavingsGoal {
        savingsGoalManager.savingsGoals.first(where: { $0.id == goal.id }) ?? goal
    }

    private var incomeEvents: [ProjectedIncomeEvent] {
        wealthManager.incomeEvents(in: currentGoal.moneda)
    }

    private var pronosticoMensual: Double {
        wealthManager.forecastedMonthlyIncome(in: currentGoal.moneda)
    }

    private var aporteInicialProyectado: Double {
        switch aporteInicialMode {
        case .percentage:
            return max(baseInicialManual, 0) * (aporteInicialPorcentaje / 100)
        case .manualAmount:
            return max(aporteInicialCantidadManual, 0)
        }
    }

    private var aporteMensualProyectado: Double {
        switch aportePronosticoMode {
        case .percentage:
            return pronosticoMensual * (aportePronosticoPorcentaje / 100)
        case .manualAmount:
            return Double(incomeEvents.count) * max(aportePronosticoCantidadManual, 0)
        }
    }

    private var tiempoRestanteTexto: String {
        if currentGoal.alcanzado {
            return "Meta alcanzada"
        }

        guard let projection = projectedGoalDate else {
            return "Sin pronóstico suficiente"
        }
        return projection.relativeDescription
    }

    private var fechaEstimadaTexto: String {
        if currentGoal.alcanzado {
            return "Disponible ahora"
        }
        if let projection = projectedGoalDate {
            return projection.date.formatted(date: .abbreviated, time: .omitted)
        }
        return "Sin fecha estimada"
    }

    private var fechaEstimadaCortaTexto: String? {
        guard !currentGoal.alcanzado, let projection = projectedGoalDate else { return nil }
        return "Estimado para \(projection.date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var accentColor: Color {
        Color(hex: profileManager.profile.accentColorHex ?? "FF5C00")
    }

    private var projectedGoalDate: GoalProjectionResult? {
        let remainingAfterCurrent = max(currentGoal.montoPendiente - aporteInicialProyectado, 0)
        if remainingAfterCurrent <= 0 {
            return GoalProjectionResult(date: Date(), relativeDescription: "La alcanzarías con tu aporte inicial")
        }

        let scheduledEvents = incomeEvents
            .compactMap { income -> ScheduledSavingsContribution? in
                let amount = projectedAmount(for: income)
                guard amount > 0 else { return nil }
                return ScheduledSavingsContribution(dayOfMonth: income.dayOfMonth, amount: amount)
            }
            .sorted { $0.dayOfMonth < $1.dayOfMonth }

        guard !scheduledEvents.isEmpty else { return nil }

        let calendar = Calendar.current
        let startDate = Date()

        var accumulated = 0.0
        for monthOffset in 0..<36 {
            let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: startDate) ?? startDate
            let range = calendar.range(of: .day, in: .month, for: monthDate) ?? (1..<32)

            for event in scheduledEvents {
                let day = min(max(event.dayOfMonth, 1), range.count)
                guard let eventDate = calendar.date(bySetting: .day, value: day, of: monthDate) else { continue }
                if eventDate < startDate { continue }

                accumulated += event.amount
                if accumulated >= remainingAfterCurrent {
                    return GoalProjectionResult(
                        date: eventDate,
                        relativeDescription: relativeDescription(from: startDate, to: eventDate)
                    )
                }
            }
        }

        return nil
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

                        if let fechaEstimadaCortaTexto {
                            Text(fechaEstimadaCortaTexto)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                        }

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

            Section("Proyección") {
                LabeledContent("Pronóstico próximo mes") {
                    Text(pronosticoMensual, format: .currency(code: currentGoal.moneda.rawValue))
                }

                initialProjectionSection
                forecastProjectionSection

                LabeledContent("Aporte inicial estimado") {
                    Text(aporteInicialProyectado, format: .currency(code: currentGoal.moneda.rawValue))
                }

                LabeledContent("Aporte mensual estimado") {
                    Text(aporteMensualProyectado, format: .currency(code: currentGoal.moneda.rawValue))
                }

                LabeledContent("Fecha estimada") {
                    Text(fechaEstimadaTexto)
                        .multilineTextAlignment(.trailing)
                }

                LabeledContent("Tiempo restante") {
                    Text(tiempoRestanteTexto)
                        .multilineTextAlignment(.trailing)
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Meta de ahorro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoadProjectionState else { return }
            syncProjectionStateFromGoal()
            didLoadProjectionState = true
        }
        .onChange(of: aporteInicialMode) { _ in persistProjectionSettings() }
        .onChange(of: baseInicialManual) { _ in persistProjectionSettings() }
        .onChange(of: aporteInicialPorcentaje) { _ in persistProjectionSettings() }
        .onChange(of: aporteInicialCantidadManual) { _ in persistProjectionSettings() }
        .onChange(of: aportePronosticoMode) { _ in persistProjectionSettings() }
        .onChange(of: aportePronosticoPorcentaje) { _ in persistProjectionSettings() }
        .onChange(of: aportePronosticoCantidadManual) { _ in persistProjectionSettings() }
    }

    private var initialProjectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usar de lo que tienes")
                .font(.subheadline.weight(.semibold))

            Picker("Modo aporte inicial", selection: $aporteInicialMode) {
                Text("Porcentaje").tag(SavingsProjectionMode.percentage)
                Text("Cantidad").tag(SavingsProjectionMode.manualAmount)
            }
            .pickerStyle(.segmented)

            if aporteInicialMode == .percentage {
                LabeledContent("Base manual actual") {
                    TextField(
                        "0",
                        value: $baseInicialManual,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Porcentaje")
                    Spacer()
                    Text(aporteInicialPorcentaje / 100, format: .percent.precision(.fractionLength(0)))
                        .foregroundColor(.secondary)
                }

                Slider(value: $aporteInicialPorcentaje, in: 0...100, step: 1)
                    .tint(accentColor)
            } else {
                LabeledContent("Cantidad inicial") {
                    TextField(
                        "0",
                        value: $aporteInicialCantidadManual,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var forecastProjectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usar del pronóstico")
                .font(.subheadline.weight(.semibold))

            Picker("Modo pronóstico", selection: $aportePronosticoMode) {
                Text("Porcentaje").tag(SavingsProjectionMode.percentage)
                Text("Cantidad").tag(SavingsProjectionMode.manualAmount)
            }
            .pickerStyle(.segmented)

            if aportePronosticoMode == .percentage {
                HStack {
                    Text("Porcentaje")
                    Spacer()
                    Text(aportePronosticoPorcentaje / 100, format: .percent.precision(.fractionLength(0)))
                        .foregroundColor(.secondary)
                }

                Slider(value: $aportePronosticoPorcentaje, in: 0...100, step: 1)
                    .tint(accentColor)
            } else {
                LabeledContent("Cantidad por cobro") {
                    TextField(
                        "0",
                        value: $aportePronosticoCantidadManual,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func syncProjectionStateFromGoal() {
        aporteInicialMode = currentGoal.aporteInicialMode
        baseInicialManual = currentGoal.baseInicialManual
        aporteInicialPorcentaje = currentGoal.aporteInicialPorcentaje
        aporteInicialCantidadManual = currentGoal.aporteInicialCantidadManual
        aportePronosticoMode = currentGoal.aportePronosticoMode
        aportePronosticoPorcentaje = currentGoal.aportePronosticoPorcentaje
        aportePronosticoCantidadManual = currentGoal.aportePronosticoCantidadManual
    }

    private func persistProjectionSettings() {
        guard didLoadProjectionState else { return }
        savingsGoalManager.updateProjectionSettings(
            for: currentGoal.id,
            aporteInicialMode: aporteInicialMode,
            baseInicialManual: baseInicialManual,
            aporteInicialPorcentaje: aporteInicialPorcentaje,
            aporteInicialCantidadManual: aporteInicialCantidadManual,
            aportePronosticoMode: aportePronosticoMode,
            aportePronosticoPorcentaje: aportePronosticoPorcentaje,
            aportePronosticoCantidadManual: aportePronosticoCantidadManual
        )
    }

    private func projectedAmount(for income: ProjectedIncomeEvent) -> Double {
        switch aportePronosticoMode {
        case .percentage:
            return income.amount * (aportePronosticoPorcentaje / 100)
        case .manualAmount:
            return max(aportePronosticoCantidadManual, 0)
        }
    }

    private func relativeDescription(from startDate: Date, to eventDate: Date) -> String {
        let calendar = Calendar.current
        let totalDays = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: startDate),
                to: calendar.startOfDay(for: eventDate)
            ).day ?? 0,
            0
        )

        let months = totalDays / 30
        let days = totalDays % 30
        let dayText = eventDate.formatted(.dateTime.day().month(.abbreviated))

        if totalDays == 0 {
            return "Aprox. hoy · \(dayText)"
        }
        if totalDays < 30 {
            let dayLabel = totalDays == 1 ? "1 día" : "\(totalDays) días"
            return "Aprox. \(dayLabel) · \(dayText)"
        }
        if months > 0 && days > 0 {
            let monthLabel = months == 1 ? "1 mes" : "\(months) meses"
            let dayLabel = days == 1 ? "1 día" : "\(days) días"
            return "Aprox. \(monthLabel) y \(dayLabel) · \(dayText)"
        }
        if months > 0 {
            let monthLabel = months == 1 ? "1 mes" : "\(months) meses"
            return "Aprox. \(monthLabel) · \(dayText)"
        }
        return "Aprox. 30 días · \(dayText)"
    }
}

private struct ScheduledSavingsContribution {
    let dayOfMonth: Int
    let amount: Double
}

private struct GoalProjectionResult {
    let date: Date
    let relativeDescription: String
}

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
            .environmentObject(WealthManager.shared)
            .environmentObject(ProfileManager.shared)
    }
}
