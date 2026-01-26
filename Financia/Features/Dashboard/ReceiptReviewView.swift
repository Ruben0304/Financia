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

                ReceiptCategoryGrid(
                    selectedTransactionCategory: $selectedTransactionCategory,
                    selectedSubcategory: $selectedSubcategory,
                    showingAddSubcategoryAlert: $showingAddSubcategoryAlert,
                    categoryToAddTo: $categoryToAddTo,
                    isAddingCategory: $isAddingCategory
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

private struct ReceiptCategoryGrid: View {
    @EnvironmentObject var categoryManager: CategoryManager
    @Binding var selectedTransactionCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    @Binding var showingAddSubcategoryAlert: Bool
    @Binding var categoryToAddTo: TransactionCategory?
    @Binding var isAddingCategory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selecciona categoría")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: { isAddingCategory = true }) {
                    Label("Nueva", systemImage: "plus.circle.fill")
                }
            }

            LazyVGrid(columns: categoryColumns, spacing: 12) {
                ForEach(categoryManager.expenseCategories) { category in
                    CategoryCard(
                        category: category,
                        selectedTransactionCategory: $selectedTransactionCategory,
                        selectedSubcategory: $selectedSubcategory,
                        showingAddSubcategoryAlert: $showingAddSubcategoryAlert,
                        categoryToAddTo: $categoryToAddTo
                    )
                }
            }
        }
    }

    private var categoryColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
}

private struct CategoryCard: View {
    let category: TransactionCategory
    @Binding var selectedTransactionCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    @Binding var showingAddSubcategoryAlert: Bool
    @Binding var categoryToAddTo: TransactionCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            subcategoryGrid
            addSubcategoryButton
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .foregroundColor(category.color)
            Text(category.name)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if selectedTransactionCategory?.id == category.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }

    private var subcategoryGrid: some View {
        LazyVGrid(columns: subcategoryColumns, alignment: .leading, spacing: 6) {
            ForEach(category.subcategories) { subcategory in
                subcategoryChip(for: subcategory)
            }
        }
    }

    private func subcategoryChip(for subcategory: Subcategory) -> some View {
        let isSelected = selectedSubcategory?.id == subcategory.id
        return Button {
            selectedSubcategory = subcategory
            selectedTransactionCategory = category
        } label: {
            Text(subcategory.name)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? category.color : Color(.systemGray6), in: Capsule())
        }
    }

    private var addSubcategoryButton: some View {
        Button(action: {
            categoryToAddTo = category
            showingAddSubcategoryAlert = true
        }) {
            Label("Agregar subcategoría", systemImage: "plus")
                .font(.caption)
                .foregroundColor(.accentColor)
        }
    }

    private var subcategoryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 80), spacing: 6)]
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
