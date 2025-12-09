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

// A simple category struct for the UI
private struct EntryCategory: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var icon: String
    let color: Color
}

struct AddEntrySheet: View {
    
    // MARK: - Properties
    
    @Environment(\.presentationMode) var presentationMode
    
    let kind: FinanceEntryFlow
    let onCompletion: (FinanceEntrySheetResult) -> Void
    
    // UI State
    @State private var amount: Double = 0
    @State private var selectedCategory: EntryCategory
    @State private var transactionDate: Date = .now
    @State private var description: String = "" // New state for description
    @State private var selectedEntryType: FinanceEntryFlow
    
    // Category State
    @State private var incomeCategories: [EntryCategory]
    @State private var expenseCategories: [EntryCategory]
    @State private var isAddingCategory = false
    
    // Initializer
    init(kind: FinanceEntryFlow, onCompletion: @escaping (FinanceEntrySheetResult) -> Void) {
        self.kind = kind
        self.onCompletion = onCompletion
        
        // Set initial state based on the 'kind' passed from ContentView
        _selectedEntryType = State(initialValue: kind)
        
        let initialIncome: [EntryCategory] = [
            .init(name: "Salario", icon: "dollarsign.circle.fill", color: .green),
            .init(name: "Regalo", icon: "gift.fill", color: .pink),
            .init(name: "Inversiones", icon: "chart.bar.fill", color: .purple),
            .init(name: "Freelance", icon: "laptopcomputer", color: .orange)
        ]
        
        let initialExpense: [EntryCategory] = [
            .init(name: "Comida", icon: "fork.knife.circle.fill", color: .yellow),
            .init(name: "Transporte", icon: "car.fill", color: .blue),
            .init(name: "Hogar", icon: "house.fill", color: .cyan),
            .init(name: "Ocio", icon: "gamecontroller.fill", color: .red),
            .init(name: "Ropa", icon: "bag.fill", color: .indigo),
            .init(name: "Salud", icon: "heart.fill", color: .pink),
            .init(name: "Educación", icon: "book.fill", color: .teal),
            .init(name: "Otros", icon: "ellipsis.circle.fill", color: .gray)
        ]
        
        _incomeCategories = State(initialValue: initialIncome)
        _expenseCategories = State(initialValue: initialExpense)
        
        _selectedCategory = State(initialValue: (kind == .income ? initialIncome : initialExpense).first!)
    }
    
    // MARK: - Body

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                amountDisplay
                detailsSheet
            }
        }
        .onChange(of: selectedEntryType) { newType in
            if newType == .income {
                selectedCategory = incomeCategories.first!
            } else {
                selectedCategory = expenseCategories.first!
            }
        }
        .sheet(isPresented: $isAddingCategory) {
            AddCategoryView { newCategory in
                if selectedEntryType == .income {
                    incomeCategories.append(newCategory)
                } else {
                    expenseCategories.append(newCategory)
                }
                selectedCategory = newCategory
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
            .foregroundStyle(AuroraColors.primaryText)
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
            
            categoryGrid
            
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

    private var categoryGrid: some View {
        let categories = selectedEntryType == .income ? incomeCategories : expenseCategories
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                // Add new category button
                Button(action: { isAddingCategory = true }) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "plus").font(.title).foregroundStyle(.secondary))
                        Text("Añadir")
                            .font(.caption)
                            .foregroundStyle(AuroraColors.primaryText)
                    }
                    .padding(6)
                }

                ForEach(categories) { category in
                    Button(action: { selectedCategory = category }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(category.color.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    ZStack {
                                        Text(category.icon.isEmoji ? category.icon : "")
                                            .font(.title)
                                        Image(systemName: category.icon.isEmoji ? "" : category.icon)
                                            .font(.title)
                                            .foregroundStyle(category.color)
                                    }
                                )
                            Text(category.name)
                                .font(.caption)
                                .foregroundStyle(AuroraColors.primaryText)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(selectedCategory == category ? 0.7 : 0.0))
                        )
                        .scaleEffect(selectedCategory == category ? 1.1 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selectedCategory)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 100)
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
        .disabled(amount <= 0)
        .opacity(amount <= 0 ? 0.6 : 1.0)
    }

    // MARK: - Functions
    
    private func handleSave() {
        let categoryAndDescription = description.isEmpty ? selectedCategory.name : "\(selectedCategory.name) - \(description)"
        
        let result = FinanceEntrySheetResult(
            amount: amount,
            kind: selectedEntryType,
            category: categoryAndDescription
        )
        onCompletion(result)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Add Category View

private struct AddCategoryView: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (EntryCategory) -> Void
    
    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var color = Color.blue
    @State private var isEmoji = false
    
    let iconColumns = [GridItem(.adaptive(minimum: 50))]
    let sampleIcons = ["cart.fill", "car.fill", "house.fill", "gamecontroller.fill", "bag.fill", "heart.fill", "book.fill", "airplane", "bus.fill", "fuelpump.fill", "gift.fill", "phone.fill", "display", "music.note", "lightbulb.fill"]

    var body: some View {
        NavigationView {
            Form {
                Section("Nombre y Emoji/Icono") {
                    TextField("Nombre de la Categoría", text: $name)
                    Toggle("Usar Emoji como Icono", isOn: $isEmoji)
                    if isEmoji {
                        TextField("Pega un emoji aquí", text: $icon)
                            .onChange(of: icon) { newValue in
                                icon = String(newValue.prefix(1))
                            }
                    }
                }

                if !isEmoji {
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
                        let newCategory = EntryCategory(name: name, icon: icon, color: color)
                        onSave(newCategory)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || icon.isEmpty)
                }
            }
        }
    }
}

private extension String {
    var isEmoji: Bool {
        contains { $0.isEmoji }
    }
}

private extension Character {
    /// A simple check to see if a character is an emoji.
    var isEmoji: Bool {
        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x1F600...0x1F64F, // Emoticons
                 0x1F300...0x1F5FF, // Misc Symbols and Pictographs
                 0x1F680...0x1F6FF, // Transport & Map
                 0x2600...0x26FF,   // Misc symbols
                 0x2700...0x27BF,   // Dingbats
                 0xFE00...0xFE0F,   // Variation Selectors
                 0x1F900...0x1F9FF, // Supplemental Symbols and Pictographs
                 127000...127600, // Various asian characters
                 65024...65039, // Variation selector
                 9100...9300, // Misc items
                 8400...8447: // Combining Diacritical Marks for Symbols
                return true
            default:
                continue
            }
        }
        return false
    }
}

struct AddEntrySheet_Previews: PreviewProvider {
    static var previews: some View {
        AddEntrySheet(kind: .expense) { result in
            print("Saved: \(result.amount) as \(result.kind) with category: \(result.category)")
        }
    }
}
