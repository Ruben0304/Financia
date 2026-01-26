import SwiftUI

struct AddCategoryView: View {
    @Environment(\.presentationMode) private var presentationMode
    var onSave: (TransactionCategory) -> Void

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var color = Color.blue

    private let iconColumns = [GridItem(.adaptive(minimum: 50))]
    private let sampleIcons = [
        "cart.fill", "car.fill", "house.fill", "gamecontroller.fill", "bag.fill", "heart.fill",
        "book.fill", "airplane", "bus.fill", "fuelpump.fill", "gift.fill", "phone.fill",
        "display", "music.note", "lightbulb.fill"
    ]

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
