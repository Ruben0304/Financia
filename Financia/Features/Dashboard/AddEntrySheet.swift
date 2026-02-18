import SwiftUI

enum FinanceEntryFlow: Identifiable {
    case income
    case expense

    var id: String {
        switch self {
        case .income: return "income"
        case .expense: return "expense"
        }
    }
}

enum IncomeSourceSelection: String, CaseIterable, Identifiable {
    case none = "Ninguno"
    case job = "Trabajo"
    case asset = "Activo"

    var id: String { rawValue }
}

struct FinanceEntrySheetResult {
    let amount: Double
    let kind: FinanceEntryFlow
    let category: String
}

struct ReceiptPrefill {
    let amount: Double
    let date: Date
    let description: String
    let lugar: Lugar?
    let subitems: [SubItem]
    let currencyCode: String?
}

struct AddEntrySheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var categoryManager: CategoryManager
    @EnvironmentObject var wealthManager: WealthManager

    let kind: FinanceEntryFlow
    let prefill: ReceiptPrefill?
    let allowsEntryTypeToggle: Bool
    let autoSelectWallet: Bool
    let autoSelectCategory: Bool
    let onCompletion: (FinanceEntrySheetResult) -> Void

    @State private var amount: Double = 0
    @State private var transactionDate: Date = .now
    @State private var description: String = ""
    @State private var placeName: String = ""
    @State private var receiptLugar: Lugar?
    @State private var receiptSubitems: [SubItem] = []
    @State private var selectedEntryType: FinanceEntryFlow
    @State private var selectedWallet: Wallet?
    @State private var didInitialize: Bool = false
    @State private var selectedTransactionCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var showingAddSubcategoryForm = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false
    @State private var showingCategoryPicker = false
    @State private var showingWalletPicker = false
    @State private var showingReceiptPicker = false
    @State private var incomeSourceSelection: IncomeSourceSelection = .none
    @State private var selectedAsset: Asset?
    @State private var selectedJob: Job?
    @State private var selectedLiability: Liability?

    init(
        kind: FinanceEntryFlow,
        prefill: ReceiptPrefill? = nil,
        allowsEntryTypeToggle: Bool = true,
        autoSelectWallet: Bool = true,
        autoSelectCategory: Bool = true,
        onCompletion: @escaping (FinanceEntrySheetResult) -> Void
    ) {
        self.kind = kind
        self.prefill = prefill
        self.allowsEntryTypeToggle = allowsEntryTypeToggle
        self.autoSelectWallet = autoSelectWallet
        self.autoSelectCategory = autoSelectCategory
        self.onCompletion = onCompletion
        _selectedEntryType = State(initialValue: kind)
    }

    var body: some View {
        ZStack {
            DarkFinanceBackground()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        typeToggle
                        amountSection
                        formFields

                        if prefill != nil {
                            receiptSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }

                saveButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 16)
                    .background(DarkFinanceColors.cardBackground)
            }
        }
        .onAppear(perform: initializeIfNeeded)
        .onChange(of: selectedEntryType) { newType in
            guard autoSelectCategory else { return }
            setDefaultCategory(for: newType)
            if newType == .income {
                selectedLiability = nil
            } else {
                incomeSourceSelection = .none
                selectedAsset = nil
                selectedJob = nil
            }
        }
        .onChange(of: incomeSourceSelection) { newValue in
            if newValue != .asset {
                selectedAsset = nil
            }
            if newValue != .job {
                selectedJob = nil
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            categoryPickerSheet
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }

            Spacer()

            Text("Nuevo Registro")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
    }

    // MARK: - Type Toggle
    private var typeToggle: some View {
        HStack(spacing: 12) {
            Button {
                selectedEntryType = .income
            } label: {
                Text("Ingreso")
                    .font(.system(size: 14, weight: selectedEntryType == .income ? .semibold : .medium))
                    .foregroundColor(selectedEntryType == .income ? .white : DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedEntryType == .income ? DarkFinanceColors.successGradient : LinearGradient(colors: [Color(hex: "1A1A1D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .buttonStyle(.plain)

            Button {
                selectedEntryType = .expense
            } label: {
                Text("Gasto")
                    .font(.system(size: 14, weight: selectedEntryType == .expense ? .semibold : .medium))
                    .foregroundColor(selectedEntryType == .expense ? .white : DarkFinanceColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedEntryType == .expense ? LinearGradient(colors: [DarkFinanceColors.errorRed], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color(hex: "1A1A1D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedEntryType == .expense ? Color.clear : Color(hex: "2A2A2E"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Amount Section
    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("Monto")
                .font(.system(size: 14))
                .foregroundColor(DarkFinanceColors.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 4) {
                Text("$")
                    .font(DarkFinanceTypography.monoAmount(size: 48, weight: .medium))
                    .foregroundColor(selectedEntryType == .income ? DarkFinanceColors.successGreen : DarkFinanceColors.primaryText)

                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .font(DarkFinanceTypography.monoAmount(size: 48, weight: .medium))
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .frame(minWidth: 100)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Form Fields
    private var formFields: some View {
        VStack(spacing: 16) {
            // Category
            formField(label: "Categoría") {
                Button {
                    showingCategoryPicker = true
                } label: {
                    HStack {
                        if let category = selectedTransactionCategory, let subcategory = selectedSubcategory {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                            Text(subcategory.name)
                                .foregroundColor(DarkFinanceColors.primaryText)
                        } else {
                            Text("Seleccionar")
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                    .darkInputStyle()
                }
                .buttonStyle(.plain)
            }

            // Wallet
            formField(label: "Cuenta") {
                Menu {
                    ForEach(walletManager.wallets) { wallet in
                        Button {
                            selectedWallet = wallet
                        } label: {
                            HStack {
                                Image(systemName: wallet.icon)
                                Text("\(wallet.name) (\(wallet.currency.symbol))")
                                if selectedWallet?.id == wallet.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let wallet = selectedWallet {
                            Image(systemName: wallet.icon)
                                .foregroundColor(wallet.color)
                            Text(wallet.name)
                                .foregroundColor(DarkFinanceColors.primaryText)
                        } else {
                            Text("Seleccionar")
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                    }
                    .darkInputStyle()
                }
                .buttonStyle(.plain)
            }

            // Origen (Trabajo/Activo/Pasivo)
            if selectedEntryType == .income {
                formField(label: "Origen (Opcional)") {
                    VStack(spacing: 10) {
                        Picker("Origen", selection: $incomeSourceSelection) {
                            ForEach(IncomeSourceSelection.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        if incomeSourceSelection == .job {
                            Menu {
                                Button("Ninguno") {
                                    selectedJob = nil
                                }
                                ForEach(wealthManager.jobs) { job in
                                    Button {
                                        selectedJob = job
                                    } label: {
                                        HStack {
                                            Text(job.name)
                                            if selectedJob?.id == job.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedJob?.name ?? "Seleccionar trabajo")
                                        .foregroundColor(selectedJob == nil ? DarkFinanceColors.secondaryText : DarkFinanceColors.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(DarkFinanceColors.secondaryText)
                                }
                                .darkInputStyle()
                            }
                            .buttonStyle(.plain)
                        } else if incomeSourceSelection == .asset {
                            Menu {
                                Button("Ninguno") {
                                    selectedAsset = nil
                                }
                                ForEach(wealthManager.assets) { asset in
                                    Button {
                                        selectedAsset = asset
                                    } label: {
                                        HStack {
                                            Text(asset.name)
                                            if selectedAsset?.id == asset.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedAsset?.name ?? "Seleccionar activo")
                                        .foregroundColor(selectedAsset == nil ? DarkFinanceColors.secondaryText : DarkFinanceColors.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(DarkFinanceColors.secondaryText)
                                }
                                .darkInputStyle()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                formField(label: "Pasivo (Opcional)") {
                    Menu {
                        Button("Ninguno") {
                            selectedLiability = nil
                        }
                        ForEach(wealthManager.liabilities) { liability in
                            Button {
                                selectedLiability = liability
                            } label: {
                                HStack {
                                    Text(liability.name)
                                    if selectedLiability?.id == liability.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedLiability?.name ?? "Seleccionar pasivo")
                                .foregroundColor(selectedLiability == nil ? DarkFinanceColors.secondaryText : DarkFinanceColors.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }
                        .darkInputStyle()
                    }
                    .buttonStyle(.plain)
                }
            }

            // Date
            formField(label: "Fecha") {
                DatePicker(
                    "",
                    selection: $transactionDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .darkInputStyle()
            }

            // Description
            formField(label: "Descripción (Opcional)") {
                TextField("Pago mensual de trabajo", text: $description)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            // Receipt attachment
            formField(label: "Adjuntar Recibo") {
                Button {
                    showingReceiptPicker = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 24))
                            .foregroundColor(DarkFinanceColors.secondaryText)
                        Text("Toca para añadir foto")
                            .font(.system(size: 12))
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                    }
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DarkFinanceColors.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DarkFinanceColors.inputBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DarkFinanceColors.secondaryText)
            content()
        }
    }

    // MARK: - Receipt Section
    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items del vale")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)

            if receiptSubitems.isEmpty {
                Text("No hay items detectados")
                    .font(.system(size: 13))
                    .foregroundColor(DarkFinanceColors.secondaryText)
            } else {
                ForEach(receiptSubitems) { item in
                    HStack {
                        Text(item.nombre)
                            .font(.system(size: 13))
                            .foregroundColor(DarkFinanceColors.primaryText)
                        Spacer()
                        if let precio = item.precio {
                            Text(precio, format: .currency(code: "CUP"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "1A1A1D"))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DarkFinanceColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DarkFinanceColors.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: handleSave) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Guardar \(selectedEntryType == .income ? "Ingreso" : "Gasto")")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedEntryType == .income ? DarkFinanceColors.successGradient : LinearGradient(colors: [DarkFinanceColors.errorRed], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
        .buttonStyle(.plain)
        .disabled(amount <= 0 || selectedSubcategory == nil || selectedWallet == nil)
        .opacity(amount <= 0 || selectedSubcategory == nil || selectedWallet == nil ? 0.5 : 1.0)
    }

    // MARK: - Category Picker Sheet
    private var categoryPickerSheet: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        CategoryGridSelector(
                            title: "Selecciona categoría",
                            categories: selectedEntryType == .income ? categoryManager.incomeCategories : categoryManager.expenseCategories,
                            selectedCategory: $selectedTransactionCategory,
                            selectedSubcategory: $selectedSubcategory,
                            onAddCategory: {
                                isAddingCategory = true
                            },
                            onAddSubcategory: { category in
                                categoryToAddTo = category
                                showingAddSubcategoryForm = true
                            }
                        )
                        .padding()
                    }
                }
            }
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        showingCategoryPicker = false
                    }
                }
            }
            .navigationDestination(isPresented: $isAddingCategory) {
                AddCategoryView { newCategory in
                    if selectedEntryType == .income {
                        categoryManager.addIncomeCategory(newCategory)
                    } else {
                        categoryManager.addExpenseCategory(newCategory)
                    }
                    selectedTransactionCategory = newCategory
                    selectedSubcategory = newCategory.subcategories.first
                }
            }
            .navigationDestination(isPresented: $showingAddSubcategoryForm) {
                AddSubcategoryFormView(categoryName: categoryToAddTo?.name ?? "") { name in
                    if let category = categoryToAddTo, !name.isEmpty {
                        addSubcategory(to: category, with: name)
                    }
                }
            }
        }
    }

    // MARK: - Functions
    private func addSubcategory(to category: TransactionCategory, with name: String) {
        let newSubcategory = Subcategory(name: name)
        let isIncome = selectedEntryType == .income
        categoryManager.addSubcategory(newSubcategory, to: category, isIncome: isIncome)
        selectedSubcategory = newSubcategory
        selectedTransactionCategory = category
        newSubcategoryName = ""
    }

    private func handleSave() {
        guard let finalSubcategory = selectedSubcategory,
              let finalCategory = selectedTransactionCategory,
              let finalWallet = selectedWallet else { return }

        let trimmedPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLugar: Lugar? = trimmedPlace.isEmpty ? nil : Lugar(
            id: receiptLugar?.id ?? UUID(),
            nombre: trimmedPlace,
            visualKeywords: receiptLugar?.visualKeywords
        )

        let cleanedSubitems = receiptSubitems.compactMap { item -> SubItem? in
            let name = item.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return SubItem(
                id: item.id,
                nombre: name,
                cantidad: max(1, item.cantidad),
                precio: item.precio
            )
        }

        let transaction = Transaction(
            type: selectedEntryType == .income ? .income : .expense,
            amount: amount,
            date: transactionDate,
            categoryId: finalCategory.id,
            categoryName: finalCategory.name,
            subcategoryId: finalSubcategory.id,
            subcategoryName: finalSubcategory.name,
            description: description,
            walletId: finalWallet.id,
            lugar: finalLugar,
            subitems: cleanedSubitems.isEmpty ? nil : cleanedSubitems,
            assetId: incomeSourceSelection == .asset ? selectedAsset?.id : nil,
            jobId: incomeSourceSelection == .job ? selectedJob?.id : nil,
            liabilityId: selectedEntryType == .expense ? selectedLiability?.id : nil
        )

        transactionManager.addTransaction(transaction)

        if transaction.type == .expense {
            ExpenseAnalysisManager.shared.analyzeExpense(transaction: transaction)
        }

        let categoryAndDescription = description.isEmpty ? finalSubcategory.name : "\(finalSubcategory.name) - \(description)"
        let result = FinanceEntrySheetResult(
            amount: amount,
            kind: selectedEntryType,
            category: categoryAndDescription
        )
        onCompletion(result)
        presentationMode.wrappedValue.dismiss()
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true

        if autoSelectWallet {
            selectedWallet = walletManager.wallets.first
        }

        if autoSelectCategory {
            setDefaultCategory(for: selectedEntryType)
        } else {
            selectedTransactionCategory = nil
            selectedSubcategory = nil
        }

        guard let prefill = prefill else { return }
        amount = prefill.amount
        transactionDate = prefill.date
        description = prefill.description
        receiptLugar = prefill.lugar
        placeName = prefill.lugar?.nombre ?? ""
        receiptSubitems = prefill.subitems
    }

    private func setDefaultCategory(for type: FinanceEntryFlow) {
        if type == .income {
            selectedTransactionCategory = categoryManager.incomeCategories.first
            selectedSubcategory = categoryManager.incomeCategories.first?.subcategories.first
        } else {
            selectedTransactionCategory = categoryManager.expenseCategories.first
            selectedSubcategory = categoryManager.expenseCategories.first?.subcategories.first
        }
    }
}
