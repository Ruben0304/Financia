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

    let data: ReceiptReviewData

    @State private var amount: Double = 0
    @State private var transactionDate: Date = .now
    @State private var description: String = ""
    @State private var placeName: String = ""
    @State private var receiptLugar: Lugar?
    @State private var receiptSubitems: [SubItem] = []

    @State private var selectedWallet: Wallet?
    @State private var selectedTransactionCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var showingAddSubcategoryAlert = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false

    private var canSave: Bool {
        amount > 0 && selectedWallet != nil && selectedSubcategory != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    detectedSection
                    requiredSection
                    optionalSection
                }
                .padding()
            }
            .navigationTitle("Revisar vale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        handleSave()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                initializeFromData()
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

    private var detectedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detectado")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("Monto", value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Text(data.currencyCode)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
            }

            DatePicker("Fecha", selection: $transactionDate, displayedComponents: .date)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                Text("Items")
                    .font(.subheadline.weight(.semibold))
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
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completa")
                .font(.headline)

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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            ReceiptCategorySelectionView(
                selectedTransactionCategory: $selectedTransactionCategory,
                selectedSubcategory: $selectedSubcategory,
                showingAddSubcategoryAlert: $showingAddSubcategoryAlert,
                categoryToAddTo: $categoryToAddTo,
                isAddingCategory: $isAddingCategory
            )
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Opcional")
                .font(.headline)

            TextField("Lugar (opcional)", text: $placeName)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))

            TextField("Descripción", text: $description, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                .lineLimit(2...4)
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }

    private func initializeFromData() {
        amount = data.amount
        transactionDate = Date()
        description = data.suggestedDescription
        receiptLugar = data.lugar
        placeName = data.lugar.nombre
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
}

private struct ReceiptCategorySelectionView: View {
    @EnvironmentObject var categoryManager: CategoryManager
    @Binding var selectedTransactionCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    @Binding var showingAddSubcategoryAlert: Bool
    @Binding var categoryToAddTo: TransactionCategory?
    @Binding var isAddingCategory: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: { isAddingCategory = true }) {
                    Label("Añadir Categoría", systemImage: "plus")
                }
                .padding(.horizontal)

                ForEach(categoryManager.expenseCategories) { category in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { selectedTransactionCategory?.id == category.id },
                            set: { isExpanded in
                                if isExpanded {
                                    selectedTransactionCategory = category
                                } else if selectedTransactionCategory?.id == category.id {
                                    selectedTransactionCategory = nil
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(category.subcategories) { subcategory in
                                Button(action: {
                                    selectedSubcategory = subcategory
                                    selectedTransactionCategory = category
                                }) {
                                    HStack {
                                        Text(subcategory.name)
                                        Spacer()
                                        if selectedSubcategory?.id == subcategory.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(Color.primary)
                            }
                            Button(action: {
                                categoryToAddTo = category
                                showingAddSubcategoryAlert = true
                            }) {
                                Label("Añadir subcategoría", systemImage: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 4)
                        }
                        .padding(.leading, 20)
                        .transition(.opacity)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                            Text(category.name)
                                .font(.headline)
                            Spacer()
                            if selectedTransactionCategory?.id == category.id && selectedSubcategory == nil {
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            } else if selectedTransactionCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedTransactionCategory?.id == category.id)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 230)
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

private struct AddCategoryView: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (TransactionCategory) -> Void

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var color = Color.blue

    let iconColumns = [GridItem(.adaptive(minimum: 50))]
    let sampleIcons = ["cart.fill", "car.fill", "house.fill", "gamecontroller.fill", "bag.fill", "heart.fill", "book.fill", "airplane", "bus.fill", "fuelpump.fill", "gift.fill", "phone.fill", "display", "music.note", "lightbulb.fill"]

    var body: some View {
        NavigationView {
            Form {
                Section("Nombre") {
                    TextField("Nombre de la Categoría", text: $name)
                }

                Section("Icono") {
                    LazyVGrid(columns: iconColumns, spacing: 20) {
                        ForEach(sampleIcons, id: \.self) { sampleIcon in
                            Image(systemName: sampleIcon)
                                .font(.title2)
                                .padding()
                                .background(icon == sampleIcon ? color.opacity(0.4) : Color.gray.opacity(0.1))
                                .clipShape(Circle())
                                .onTapGesture { icon = sampleIcon }
                        }
                    }
                }

                Section("Color") {
                    ColorPicker("Elige un color", selection: $color)
                }
            }
            .navigationTitle("Nueva Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let newCategory = TransactionCategory(name: name, subcategories: [], icon: icon, color: color)
                        onSave(newCategory)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || icon.isEmpty)
                }
            }
        }
    }
}
