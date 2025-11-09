import SwiftUI

enum FinanceEntryFlow: String, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Ingreso"
        case .expense: return "Gasto"
        }
    }

    var accentColor: Color {
        switch self {
        case .income: return Color(red: 0.17, green: 0.60, blue: 0.47)
        case .expense: return Color(red: 0.83, green: 0.35, blue: 0.33)
        }
    }

    var caption: String {
        switch self {
        case .income: return "Dinero que entra"
        case .expense: return "Dinero que sale"
        }
    }
}

struct FinanceEntrySheetResult {
    let kind: FinanceEntryFlow
    let amount: Double
    let category: FinanceCategoryOption
    let notes: String
}

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSubmit: (FinanceEntrySheetResult) -> Void

    @State private var selectedKind: FinanceEntryFlow
    @State private var selectedCategory: FinanceCategoryOption
    @State private var amountText: String
    @State private var notes: String = ""
    @State private var customCategory: CustomCategoryDraft
    @FocusState private var focusedField: Field?

    init(
        kind: FinanceEntryFlow,
        presetAmount: Double? = nil,
        customCategory: CustomCategoryDraft = CustomCategoryDraft(),
        onSubmit: @escaping (FinanceEntrySheetResult) -> Void = { _ in }
    ) {
        _selectedKind = State(initialValue: kind)
        let defaults = FinanceCategoryOption.defaults(for: kind)
        _selectedCategory = State(initialValue: defaults.first ?? CustomCategoryDraft().makeOption(for: kind))
        if let amount = presetAmount {
            _amountText = State(initialValue: amount.formatted(.number.precision(.fractionLength(2))))
        } else {
            _amountText = State(initialValue: "")
        }
        _customCategory = State(initialValue: customCategory)
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        kindPicker
                        amountField
                        categoryGrid

                        if selectedCategory.isCustom {
                            CustomCategoryEditor(draft: $customCategory, selectedKind: selectedKind)
                                .transition(.opacity)
                        }

                        notesField
                    }
                    .padding(.bottom, 8)
                }

                actionButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
            .navigationTitle("Nuevo movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.86), .large])
        .presentationCornerRadius(32)
        .onChange(of: selectedKind) { newKind in
            let defaults = FinanceCategoryOption.defaults(for: newKind)
            if selectedCategory.kind != newKind || !defaults.contains(selectedCategory) {
                selectedCategory = defaults.first ?? customCategory.makeOption(for: newKind)
            }
        }
        .onChange(of: customCategory) { newValue in
            if selectedCategory.isCustom {
                selectedCategory = newValue.makeOption(for: selectedKind)
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tipo de movimiento")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AuroraColors.secondaryText)

            Picker("Tipo", selection: $selectedKind) {
                ForEach(FinanceEntryFlow.allCases) { kind in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title).font(.headline)
                        Text(kind.caption).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monto")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AuroraColors.secondaryText)

            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AuroraColors.primaryText)
                .padding(.vertical, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categoría")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AuroraColors.secondaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(categoryOptions) { option in
                    CategoryCard(option: option, isSelected: option.id == selectedCategory.id)
                        .onTapGesture {
                            selectedCategory = option
                            focusedField = nil
                        }
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notas (opcional)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AuroraColors.secondaryText)

            TextField("Ej. \"Pagado en efectivo\"", text: $notes, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...3)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
    }

    private var actionButton: some View {
        Button {
            guard let numericAmount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
            let payload = FinanceEntrySheetResult(
                kind: selectedKind,
                amount: numericAmount,
                category: selectedCategory,
                notes: notes
            )
            onSubmit(payload)
            dismiss()
        } label: {
            Text("Guardar \(selectedKind.title.lowercased())")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedKind.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1 : 0.6)
    }

    private var categoryOptions: [FinanceCategoryOption] {
        var defaults = FinanceCategoryOption.defaults(for: selectedKind)
        defaults.append(customCategory.makeOption(for: selectedKind))
        return defaults
    }

    private var isFormValid: Bool {
        guard !amountText.isEmpty, Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0 else {
            return false
        }
        return true
    }

    private enum Field {
        case amount
    }
}

struct FinanceCategoryOption: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: CategoryIcon
    let color: Color
    let kind: FinanceEntryFlow

    var isCustom: Bool {
        id == FinanceCategoryOption.customIdentifier
    }

    static let customIdentifier = "custom-category"

    static func defaults(for kind: FinanceEntryFlow) -> [FinanceCategoryOption] {
        switch kind {
        case .income:
            return [
                FinanceCategoryOption(
                    id: "salary",
                    title: "Salario",
                    icon: .system("dollarsign.arrow.circlepath"),
                    color: Color(red: 0.75, green: 0.89, blue: 0.78),
                    kind: kind
                ),
                FinanceCategoryOption(
                    id: "freelance",
                    title: "Freelance",
                    icon: .system("laptopcomputer"),
                    color: Color(red: 0.74, green: 0.85, blue: 0.98),
                    kind: kind
                ),
                FinanceCategoryOption(
                    id: "investments",
                    title: "Inversiones",
                    icon: .system("chart.line.uptrend.xyaxis"),
                    color: Color(red: 0.90, green: 0.83, blue: 0.98),
                    kind: kind
                )
            ]

        case .expense:
            return [
                FinanceCategoryOption(
                    id: "groceries",
                    title: "Mercado",
                    icon: .system("cart.fill"),
                    color: Color(red: 0.99, green: 0.88, blue: 0.79),
                    kind: kind
                ),
                FinanceCategoryOption(
                    id: "transport",
                    title: "Transporte",
                    icon: .system("car.fill"),
                    color: Color(red: 0.91, green: 0.95, blue: 0.99),
                    kind: kind
                ),
                FinanceCategoryOption(
                    id: "leisure",
                    title: "Ocio",
                    icon: .system("popcorn.fill"),
                    color: Color(red: 0.99, green: 0.91, blue: 0.94),
                    kind: kind
                )
            ]
        }
    }
}

enum CategoryIcon: Equatable {
    case system(String)
    case emoji(String)
}

private struct CategoryCard: View {
    let option: FinanceCategoryOption
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CategoryIconView(icon: option.icon, background: option.color)
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AuroraColors.primaryText)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? option.color.opacity(0.9) : Color.clear, lineWidth: 2)
        )
    }
}

private struct CategoryIconView: View {
    let icon: CategoryIcon
    let background: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background.opacity(0.6))
                .frame(width: 52, height: 52)

            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AuroraColors.primaryText)
            case .emoji(let emoji):
                Text(emoji)
                    .font(.system(size: 26))
            }
        }
    }
}

struct CustomCategoryDraft: Equatable {
    enum IconStyle: String, CaseIterable, Identifiable {
        case system
        case emoji

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "Icono iOS"
            case .emoji: return "Emoji"
            }
        }
    }

    var name: String = "Personalizada"
    var iconStyle: IconStyle = .system
    var symbolName: String = "sparkles"
    var emoji: String = "✨"

    func makeOption(for kind: FinanceEntryFlow) -> FinanceCategoryOption {
        FinanceCategoryOption(
            id: FinanceCategoryOption.customIdentifier,
            title: name.isEmpty ? "Personalizada" : name,
            icon: iconStyle == .system ? .system(symbolName) : .emoji(emoji),
            color: Color(red: 0.94, green: 0.88, blue: 0.99),
            kind: kind
        )
    }
}

private struct CustomCategoryEditor: View {
    @Binding var draft: CustomCategoryDraft
    let selectedKind: FinanceEntryFlow

    private let symbolCandidates = [
        "wand.and.stars",
        "house.fill",
        "tshirt.fill",
        "takeoutbag.and.cup.and.straw.fill",
        "gamecontroller.fill",
        "airplane",
        "stethoscope",
        "gift.fill"
    ]

    private let emojiCandidates = ["🍰", "🏖️", "🎉", "🥡", "📚", "🚲", "🧾", "🛠️", "🧘🏻‍♂️"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categoria personalizada")
                .font(.headline)
                .foregroundStyle(AuroraColors.primaryText)

            TextField("Nombre de la categoría", text: $draft.name)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.tertiarySystemBackground)))

            Picker("Estilo de icono", selection: $draft.iconStyle) {
                ForEach(CustomCategoryDraft.IconStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if draft.iconStyle == .system {
                iconGrid
            } else {
                emojiSelector
            }

            HStack {
                Text("Preview")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                CategoryCard(option: draft.makeOption(for: selectedKind), isSelected: true)
                    .frame(maxWidth: 160)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
    }

    private var iconGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(symbolCandidates, id: \.self) { symbol in
                    Button {
                        draft.symbolName = symbol
                    } label: {
                        CategoryIconView(
                            icon: .system(symbol),
                            background: symbol == draft.symbolName ? selectedKind.accentColor.opacity(0.4) : Color(.tertiarySystemBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var emojiSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Emoji personalizado", text: $draft.emoji)
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.tertiarySystemBackground)))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(emojiCandidates, id: \.self) { emoji in
                        Button {
                            draft.emoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(emoji == draft.emoji ? selectedKind.accentColor.opacity(0.3) : Color(.tertiarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

#Preview {
    AddEntrySheet(kind: .expense)
}
