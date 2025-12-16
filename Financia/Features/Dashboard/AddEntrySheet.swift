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

struct AddEntrySheet: View {
    
    // MARK: - Properties
    
    @Environment(\.presentationMode) var presentationMode
    
    let kind: FinanceEntryFlow
    let onCompletion: (FinanceEntrySheetResult) -> Void
    
    // UI State
    @State private var amount: Double = 0
    @State private var transactionDate: Date = .now
    @State private var description: String = "" // New state for description
    @State private var selectedEntryType: FinanceEntryFlow
    
    // Category State
    @State private var incomeTransactionCategories: [TransactionCategory]
    @State private var expenseTransactionCategories: [TransactionCategory]
    @State private var selectedTransactionCategory: TransactionCategory?
    @State private var selectedSubcategory: Subcategory?
    @State private var showingAddSubcategoryAlert = false
    @State private var newSubcategoryName = ""
    @State private var categoryToAddTo: TransactionCategory?
    @State private var isAddingCategory = false // State to show AddCategoryView

    // Initializer
    init(kind: FinanceEntryFlow, onCompletion: @escaping (FinanceEntrySheetResult) -> Void) {
        self.kind = kind
        self.onCompletion = onCompletion
        
        // Set initial state based on the 'kind' passed from ContentView
        _selectedEntryType = State(initialValue: kind)
        
        _incomeTransactionCategories = State(initialValue: CategoriesData.incomeCategories)
        _expenseTransactionCategories = State(initialValue: CategoriesData.expenseCategories)
        
        if kind == .income {
            _selectedTransactionCategory = State(initialValue: CategoriesData.incomeCategories.first)
            _selectedSubcategory = State(initialValue: CategoriesData.incomeCategories.first?.subcategories.first)
        } else {
            _selectedTransactionCategory = State(initialValue: CategoriesData.expenseCategories.first)
            _selectedSubcategory = State(initialValue: CategoriesData.expenseCategories.first?.subcategories.first)
        }
    }
    
    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                amountDisplay
                detailsSheet
            }
        }
        .onChange(of: selectedEntryType) { newType in
            if newType == .income {
                selectedTransactionCategory = incomeTransactionCategories.first
                selectedSubcategory = incomeTransactionCategories.first?.subcategories.first
            } else {
                selectedTransactionCategory = expenseTransactionCategories.first
                selectedSubcategory = expenseTransactionCategories.first?.subcategories.first
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
                if selectedEntryType == .income {
                    incomeTransactionCategories.append(newCategory)
                } else {
                    expenseTransactionCategories.append(newCategory)
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
            Picker("Tipo de transacción", selection: $selectedEntryType) {
                Text("Gasto").tag(FinanceEntryFlow.expense)
                Text("Ingreso").tag(FinanceEntryFlow.income)
            }
            .pickerStyle(.segmented)
            
            CategorySelectionView(
                incomeCategories: $incomeTransactionCategories,
                expenseCategories: $expenseTransactionCategories,
                selectedEntryType: $selectedEntryType,
                selectedTransactionCategory: $selectedTransactionCategory,
                selectedSubcategory: $selectedSubcategory,
                showingAddSubcategoryAlert: $showingAddSubcategoryAlert,
                categoryToAddTo: $categoryToAddTo,
                isAddingCategory: $isAddingCategory
            )
            
            // New Description and Date Section
            VStack(spacing: 10) {
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
        .disabled(amount <= 0 || selectedSubcategory == nil)
        .opacity(amount <= 0 || selectedSubcategory == nil ? 0.6 : 1.0)
    }

    // MARK: - Functions
    
    private func addSubcategory(to category: TransactionCategory, with name: String) {
        let newSubcategory = Subcategory(name: name)
        if selectedEntryType == .income {
            if let index = incomeTransactionCategories.firstIndex(where: { $0.id == category.id }) {
                incomeTransactionCategories[index].subcategories.append(newSubcategory)
            }
        } else {
            if let index = expenseTransactionCategories.firstIndex(where: { $0.id == category.id }) {
                expenseTransactionCategories[index].subcategories.append(newSubcategory)
            }
        }
        selectedSubcategory = newSubcategory // Automatically select the newly added subcategory
        selectedTransactionCategory = category // Ensure the parent category is also selected
    }

    private func handleSave() {
        guard let finalSubcategory = selectedSubcategory else { return }

        let categoryAndDescription = description.isEmpty ? finalSubcategory.name : "\(finalSubcategory.name) - \(description)"
        
        let result = FinanceEntrySheetResult(
            amount: amount,
            kind: selectedEntryType,
            category: categoryAndDescription
        )
        onCompletion(result)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - CategorySelectionView

private struct CategorySelectionView: View {
    @Binding var incomeCategories: [TransactionCategory]
    @Binding var expenseCategories: [TransactionCategory]
    @Binding var selectedEntryType: FinanceEntryFlow
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
                
                ForEach(selectedEntryType == .income ? incomeCategories : expenseCategories) { category in
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
                                    selectedTransactionCategory = category // Also select parent category
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
                                    .contentShape(Rectangle()) // Make the whole row tappable
                                }
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(Color.primary)
                            }
                            // Button to add new subcategory
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
                        .transition(.opacity) // Minimal animation for subcategories
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
                    .animation(.easeInOut(duration: 0.2), value: selectedTransactionCategory?.id == category.id) // Animation for disclosure group
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 250) // Fixed height for the scroll view
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AddCategoryView

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


struct AddEntrySheet_Previews: PreviewProvider {
    static var previews: some View {
        AddEntrySheet(kind: .expense) { result in
            print("Saved: \(result.amount) as \(result.kind) with category: \(result.category)")
        }
    }
}