import SwiftUI

struct AddWalletSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (Wallet) -> Void

    @State private var name: String = ""
    @State private var currency: Currency = .usd
    @State private var balance: String = ""
    @State private var icon: String = "creditcard.fill"
    @State private var color: Color = .blue
    
    let iconColumns = [GridItem(.adaptive(minimum: 50))]
    let sampleIcons = ["creditcard.fill", "banknote.fill", "dollarsign.circle.fill", "gift.fill", "house.fill", "car.fill"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detalles de la Cartera")) {
                    TextField("Nombre", text: $name)
                    Picker("Moneda", selection: $currency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                    TextField("Balance Inicial", text: $balance)
                        .keyboardType(.decimalPad)
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
            .navigationTitle("Nueva Cartera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let newWallet = Wallet(
                            name: name,
                            currency: currency,
                            balance: Double(balance) ?? 0,
                            icon: icon,
                            color: color
                        )
                        onSave(newWallet)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || balance.isEmpty)
                }
            }
        }
    }
}
