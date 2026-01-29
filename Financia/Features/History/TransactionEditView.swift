import SwiftUI

struct TransactionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var wealthManager: WealthManager

    let transaction: Transaction

    @State private var amount: Double = 0
    @State private var date: Date = .now
    @State private var description: String = ""
    @State private var selectedWallet: Wallet?
    @State private var selectedCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var incomeSourceSelection: IncomeSourceSelection = .none
    @State private var selectedAsset: Asset?
    @State private var selectedJob: Job?
    @State private var selectedLiability: Liability?

    @State private var showingAddSubcategoryAlert = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto") {
                    TextField("0.00", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                }

                Section("Fecha") {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }

                Section("Cartera") {
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

                Section("Categoría") {
                    CategoryGridSelector(
                        title: "Selecciona categoría",
                        categories: categoryList,
                        selectedCategory: $selectedCategory,
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

                if transaction.type == .income {
                    Section("Origen (Opcional)") {
                        Picker("Origen", selection: $incomeSourceSelection) {
                            ForEach(IncomeSourceSelection.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        if incomeSourceSelection == .job {
                            Menu {
                                Button("Ninguno") { selectedJob = nil }
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
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if incomeSourceSelection == .asset {
                            Menu {
                                Button("Ninguno") { selectedAsset = nil }
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
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Section("Pasivo (Opcional)") {
                        Menu {
                            Button("Ninguno") { selectedLiability = nil }
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
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Descripción") {
                    TextField("Descripción", text: $description, axis: .vertical)
                }
            }
            .navigationTitle("Editar transacción")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        handleSave()
                    }
                    .disabled(!canSave)
                }
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
                    if transaction.type == .income {
                        categoryManager.addIncomeCategory(newCategory)
                    } else {
                        categoryManager.addExpenseCategory(newCategory)
                    }
                    selectedCategory = newCategory
                    selectedSubcategory = newCategory.subcategories.first
                }
            }
            .onAppear {
                initializeFromTransaction()
            }
            .onChange(of: incomeSourceSelection) { newValue in
                if newValue != .asset {
                    selectedAsset = nil
                }
                if newValue != .job {
                    selectedJob = nil
                }
            }
        }
    }

    private var canSave: Bool {
        amount > 0 && selectedWallet != nil && selectedSubcategory != nil
    }

    private var categoryList: [TransactionCategory] {
        transaction.type == .income ? categoryManager.incomeCategories : categoryManager.expenseCategories
    }

    private func initializeFromTransaction() {
        amount = transaction.amount
        date = transaction.date
        description = transaction.description
        selectedWallet = walletManager.wallet(withId: transaction.walletId)
        selectedCategory = categoryList.first { $0.id == transaction.categoryId }
        selectedSubcategory = selectedCategory?.subcategories.first { $0.id == transaction.subcategoryId }
        selectedAsset = wealthManager.asset(withId: transaction.assetId)
        selectedJob = wealthManager.job(withId: transaction.jobId)
        selectedLiability = wealthManager.liability(withId: transaction.liabilityId)
        if transaction.type == .income {
            if selectedJob != nil {
                incomeSourceSelection = .job
            } else if selectedAsset != nil {
                incomeSourceSelection = .asset
            } else {
                incomeSourceSelection = .none
            }
        }
    }

    private func addSubcategory(to category: TransactionCategory, with name: String) {
        let newSubcategory = Subcategory(name: name)
        categoryManager.addSubcategory(newSubcategory, to: category, isIncome: transaction.type == .income)
        selectedSubcategory = newSubcategory
        selectedCategory = category
    }

    private func handleSave() {
        guard let finalCategory = selectedCategory,
              let finalSubcategory = selectedSubcategory,
              let finalWallet = selectedWallet else { return }

        let updated = Transaction(
            id: transaction.id,
            type: transaction.type,
            amount: amount,
            date: date,
            categoryId: finalCategory.id,
            categoryName: finalCategory.name,
            subcategoryId: finalSubcategory.id,
            subcategoryName: finalSubcategory.name,
            description: description,
            walletId: finalWallet.id,
            createdAt: transaction.createdAt,
            lugar: transaction.lugar,
            subitems: transaction.subitems,
            assetId: transaction.type == .income && incomeSourceSelection == .asset ? selectedAsset?.id : nil,
            jobId: transaction.type == .income && incomeSourceSelection == .job ? selectedJob?.id : nil,
            liabilityId: transaction.type == .expense ? selectedLiability?.id : nil
        )
        transactionManager.updateTransaction(updated)
        dismiss()
    }
}
