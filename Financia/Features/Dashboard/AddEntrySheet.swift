import SwiftUI

// These types are defined here to make this View self-contained and
// to ensure it works with the original ContentView without modification.
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

struct FinanceEntrySheetResult {
    let amount: Double
    let kind: FinanceEntryFlow
    let category: String // This will now hold "Category - Description"
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

    // MARK: - Properties

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var categoryManager: CategoryManager

    let kind: FinanceEntryFlow
    let prefill: ReceiptPrefill?
    let allowsEntryTypeToggle: Bool
    let autoSelectWallet: Bool
    let autoSelectCategory: Bool
    let onCompletion: (FinanceEntrySheetResult) -> Void
    
    // UI State
    @State private var amount: Double = 0
    @State private var transactionDate: Date = .now
    @State private var description: String = ""
    @State private var placeName: String = ""
    @State private var receiptLugar: Lugar?
    @State private var receiptSubitems: [SubItem] = []
    @State private var selectedEntryType: FinanceEntryFlow
    @State private var selectedWallet: Wallet?
    @State private var didInitialize: Bool = false

    // Category State
    @State private var selectedTransactionCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var showingAddSubcategoryAlert = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false

    // Initializer
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
    
    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    if allowsEntryTypeToggle {
                        Picker("Tipo de transacción", selection: $selectedEntryType) {
                            Text("Gasto").tag(FinanceEntryFlow.expense)
                            Text("Ingreso").tag(FinanceEntryFlow.income)
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("Gasto")
                    }
                }

                Section("Monto") {
                    TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                }

                Section("Cartera") {
                    if !walletManager.wallets.isEmpty {
                        Menu {
                            ForEach(walletManager.wallets) { wallet in
                                Button(action: { selectedWallet = wallet }) {
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
                                Image(systemName: selectedWallet?.icon ?? "wallet.pass")
                                    .foregroundColor(selectedWallet?.color ?? .blue)
                                Text(selectedWallet?.name ?? "Seleccionar Cartera")
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Categoría") {
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
                            showingAddSubcategoryAlert = true
                        }
                    )
                }

                Section("Detalles") {
                    if prefill != nil {
                        TextField("Lugar (opcional)", text: $placeName)
                    }

                    TextField("Descripción", text: $description)

                    DatePicker("Fecha", selection: $transactionDate, displayedComponents: .date)
                }

                if prefill != nil {
                    Section("Items") {
                        receiptDetailsSection
                    }
                }
            }
            .navigationTitle(selectedEntryType == .income ? "Nuevo ingreso" : "Nuevo gasto")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        handleSave()
                    }
                    .disabled(amount <= 0 || selectedSubcategory == nil || selectedWallet == nil)
                }
            }
        }
        .onAppear {
            initializeIfNeeded()
        }
        .onChange(of: selectedEntryType) { newType in
            guard autoSelectCategory else { return }
            setDefaultCategory(for: newType)
        }
        .alert("Nueva Subcategoría", isPresented: $showingAddSubcategoryAlert) {
            TextField("Nombre", text: $newSubcategoryName)
            Button("Guardar") {
                if let category = categoryToAddTo, !newSubcategoryName.isEmpty {
                    addSubcategory(to: category, with: newSubcategoryName)
                    newSubcategoryName = ""
                }
            }
            Button("Cancelar", role: .cancel) {
                newSubcategoryName = ""
            }
        }
        .sheet(isPresented: $isAddingCategory) {
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
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Spacer()
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding([.top, .trailing])
    }
    
    private var amountDisplay: some View {
        VStack {
            HStack(alignment: .center, spacing: 4) {
                Text(selectedEntryType == .income ? "+" : "-")
                    .font(.system(size: 45, weight: .light, design: .rounded))
                Text("$")
                    .font(.system(size: 45, weight: .light, design: .rounded))
                TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 70, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 150)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal)
        }
        .padding(.vertical, 30)
    }

    private var detailsSheet: some View {
        VStack(spacing: 16) {
            if allowsEntryTypeToggle {
                Picker("Tipo de transacción", selection: $selectedEntryType) {
                    Text("Gasto").tag(FinanceEntryFlow.expense)
                    Text("Ingreso").tag(FinanceEntryFlow.income)
                }
                .pickerStyle(.segmented)
            } else {
                Text("Gasto")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            // Wallet Selector
            if !walletManager.wallets.isEmpty {
                Menu {
                    ForEach(walletManager.wallets) { wallet in
                        Button(action: { selectedWallet = wallet }) {
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
                        Image(systemName: selectedWallet?.icon ?? "wallet.pass")
                            .foregroundColor(selectedWallet?.color ?? .blue)
                        Text(selectedWallet?.name ?? "Seleccionar Cartera")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }

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
                    showingAddSubcategoryAlert = true
                }
            )

            if prefill != nil {
                receiptDetailsSection
            }

            // Description and Date Section
            VStack(spacing: 10) {
                if prefill != nil {
                    TextField("Lugar (opcional)", text: $placeName)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                TextField("Descripción (ej. Almuerzo con amigos)", text: $description)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                DatePicker("Fecha", selection: $transactionDate, displayedComponents: .date)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            saveButton

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 40, style: .continuous)
        )
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    private var saveButton: some View {
        Button(action: handleSave) {
            Text("Guardar Transacción")
                .font(.headline).fontWeight(.bold).foregroundStyle(.white).padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color(red: 0.78, green: 0.58, blue: 0.98), Color(red: 0.53, green: 0.36, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(20)
                .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
        }
        .padding(.top)
        .disabled(amount <= 0 || selectedSubcategory == nil || selectedWallet == nil)
        .opacity(amount <= 0 || selectedSubcategory == nil || selectedWallet == nil ? 0.6 : 1.0)
    }

    // MARK: - Functions
    
    private func addSubcategory(to category: TransactionCategory, with name: String) {
        let newSubcategory = Subcategory(name: name)
        let isIncome = selectedEntryType == .income
        categoryManager.addSubcategory(newSubcategory, to: category, isIncome: isIncome)
        selectedSubcategory = newSubcategory
        selectedTransactionCategory = category
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

        // Crear transacción persistente
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
            subitems: cleanedSubitems.isEmpty ? nil : cleanedSubitems
        )

        // Guardar en TransactionManager
        transactionManager.addTransaction(transaction)

        // Notificar completion (para compatibilidad)
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

    private var receiptDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items del vale")
                    .font(.headline)
                Spacer()
                Button {
                    receiptSubitems.append(SubItem(nombre: "", cantidad: 1, precio: nil))
                } label: {
                    Label("Agregar", systemImage: "plus")
                }
            }

            if let currencyCode = prefill?.currencyCode {
                Text("Moneda detectada: \(currencyCode)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if receiptSubitems.isEmpty {
                Text("No hay items detectados todavía.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(receiptSubitems.indices, id: \.self) { index in
                    let itemId = receiptSubitems[index].id
                    ReceiptSubitemRow(item: $receiptSubitems[index]) {
                        receiptSubitems.removeAll { $0.id == itemId }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ReceiptSubitemRow: View {
    @Binding var item: SubItem
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Item", text: $item.nombre)
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
            }

            Stepper("Cantidad: \(item.cantidad)", value: $item.cantidad, in: 1...99)

            TextField("Precio (opcional)", text: priceBinding)
                .keyboardType(.decimalPad)
        }
        .padding(12)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var priceBinding: Binding<String> {
        Binding<String>(
            get: {
                guard let price = item.precio else { return "" }
                return String(format: "%.2f", price)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    item.precio = nil
                } else {
                    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                    item.precio = Double(normalized)
                }
            }
        )
    }
}

struct AddEntrySheet_Previews: PreviewProvider {
    static var previews: some View {
        AddEntrySheet(kind: .expense) { result in
            print("Saved: \(result.amount) as \(result.kind) with category: \(result.category)")
        }
    }
}
