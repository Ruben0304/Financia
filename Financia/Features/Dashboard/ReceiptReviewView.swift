import SwiftUI

struct ReceiptReviewData: Identifiable {
    let id = UUID()
    let extraction: ReceiptExtraction

    var amount: Double { extraction.monto }
    var currencyCode: String { extraction.moneda }
    var lugar: Lugar { extraction.toLugar() }
    var subitems: [SubItem] { extraction.toSubItems() ?? [] }
    var suggestedDescription: String {
        let name = extraction.lugar.nombre ?? ""
        return name.isEmpty ? "Gasto de vale" : name
    }
}

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var transactionManager: TransactionManager
    @EnvironmentObject private var categoryManager: CategoryManager
    @EnvironmentObject private var lugarManager: LugarManager

    let data: ReceiptReviewData

    @State private var amount: Double = 0
    @State private var transactionDate: Date = .now
    @State private var description: String = ""
    @State private var placeName: String = ""
    @State private var receiptSubitems: [SubItem] = []

    @State private var selectedWallet: Wallet?
    @State private var selectedTransactionCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var showingAddSubcategoryAlert = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false
    @State private var showMissingDataAlert: Bool = false

    private var requiresPlaceName: Bool {
        data.extraction.lugar.id == nil
    }

    private var hasValidPlaceName: Bool {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !requiresPlaceName || !trimmed.isEmpty
    }

    private var canSave: Bool {
        amount > 0 && selectedWallet != nil && selectedSubcategory != nil && hasValidPlaceName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !canSave {
                        missingDataBanner
                    }
                    summarySection
                    placeSection
                    itemsSection
                    requiredSection
                    optionalSection
                }
                .padding()
            }
            .navigationTitle("Registrar vale")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if canSave {
                            handleSave()
                        } else {
                            showMissingDataAlert = true
                        }
                    }
                }
            }
            .onAppear {
                initializeFromData()
            }
            .alert("Faltan datos", isPresented: $showMissingDataAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(missingDataMessage)
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
                    categoryManager.addExpenseCategory(newCategory)
                    selectedTransactionCategory = newCategory
                    selectedSubcategory = newCategory.subcategories.first
                }
            }
        }
    }

    private var summarySection: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TextField("Monto", value: $amount, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    Text(data.currencyCode)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                }

                DatePicker("Fecha", selection: $transactionDate, displayedComponents: .date)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }
        } label: {
            Label("Resumen del vale", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
        }
    }

    private var placeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if requiresPlaceName {
                    TextField("Nombre del lugar (requerido)", text: $placeName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    TextField("Lugar (opcional)", text: $placeName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                }

                if !data.extraction.lugar.palabrasClave.isEmpty {
                    LazyVGrid(columns: keywordColumns, alignment: .leading, spacing: 8) {
                        ForEach(data.extraction.lugar.palabrasClave, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5), in: Capsule())
                        }
                    }
                }
            }
        } label: {
            Label("Lugar", systemImage: "mappin.and.ellipse")
                .font(.headline)
        }
    }

    private var itemsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if receiptSubitems.isEmpty {
                    Text("Sin items detectados.")
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

                Button {
                    receiptSubitems.append(SubItem(nombre: "", cantidad: 1, precio: nil))
                } label: {
                    Label("Agregar item", systemImage: "plus")
                }
            }
        } label: {
            Label("Items", systemImage: "list.bullet.rectangle")
                .font(.headline)
        }
    }

    private var requiredSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                CategoryGridSelector(
                    title: "Selecciona categoría",
                    categories: categoryManager.expenseCategories,
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
        } label: {
            Label("Categoría", systemImage: "square.grid.2x2")
                .font(.headline)
        }
    }

    private var optionalSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Descripción", text: $description, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    .lineLimit(2...4)
            }
        } label: {
            Label("Notas", systemImage: "note.text")
                .font(.headline)
        }
    }

    private func initializeFromData() {
        amount = data.amount
        transactionDate = Date()
        description = data.suggestedDescription
        if let backendId = data.extraction.lugar.id,
           let existingLugar = lugarManager.lugar(for: backendId) {
            placeName = existingLugar.nombre
        } else {
            placeName = data.lugar.nombre
        }
        receiptSubitems = data.subitems

        selectedWallet = walletManager.wallets.first
        selectedTransactionCategory = categoryManager.expenseCategories.first
        selectedSubcategory = categoryManager.expenseCategories.first?.subcategories.first
    }

    private func addSubcategory(to category: TransactionCategory, with name: String) {
        let newSubcategory = Subcategory(name: name)
        categoryManager.addSubcategory(newSubcategory, to: category, isIncome: false)
        selectedSubcategory = newSubcategory
        selectedTransactionCategory = category
    }

    private func handleSave() {
        guard let finalSubcategory = selectedSubcategory,
              let finalCategory = selectedTransactionCategory,
              let finalWallet = selectedWallet else { return }

        let trimmedPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLugar: Lugar? = {
            if trimmedPlace.isEmpty && requiresPlaceName {
                return nil
            }
            let upserted = lugarManager.upsertLugar(
                apiLugar: data.extraction.lugar,
                userProvidedName: trimmedPlace.isEmpty ? nil : trimmedPlace
            )
            return upserted
        }()

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
            type: .expense,
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

        transactionManager.addTransaction(transaction)
        dismiss()
    }

    private var missingDataMessage: String {
        var missing: [String] = []
        if requiresPlaceName && !hasValidPlaceName {
            missing.append("Agrega un nombre de lugar")
        }
        if selectedWallet == nil {
            missing.append("Selecciona una cartera")
        }
        if selectedSubcategory == nil {
            missing.append("Selecciona una categoría")
        }
        if missing.isEmpty {
            return "Completa los datos faltantes para guardar."
        }
        return missing.joined(separator: ". ") + "."
    }

    private var missingDataBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(missingDataMessage)
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var keywordColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 8)]
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
