import SwiftUI
import PhotosUI

struct ValuableObjectsView: View {
    @EnvironmentObject private var wealthManager: WealthManager
    @State private var isAddingObject = false

    var body: some View {
        List {
            if wealthManager.valuableObjects.isEmpty {
                Text("No hay objetos de valor registrados.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(wealthManager.valuableObjects) { object in
                    NavigationLink {
                        ValuableObjectDetailView(object: object)
                    } label: {
                        HStack(spacing: 12) {
                            thumbnail(for: object)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(object.name)
                                if object.forSale {
                                    Text("En venta")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Text(object.estimatedValue.formatted(.currency(code: object.currency.rawValue)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indices in
                    indices.map { wealthManager.valuableObjects[$0] }.forEach(wealthManager.deleteValuableObject)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Objetos de valor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingObject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingObject) {
            ValuableObjectEditorView { object in
                wealthManager.addValuableObject(object)
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for object: ValuableObject) -> some View {
        if let data = object.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "shippingbox")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                )
        }
    }
}

struct ValuableObjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var estimatedValue: String = ""
    @State private var currency: Currency = .usd
    @State private var forSale: Bool = false

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    let onSave: (ValuableObject) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                DarkFinanceBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        photoCard
                        formCard
                        saleCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Nuevo objeto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return (Double(estimatedValue.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var photoCard: some View {
        HStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text(selectedImage == nil ? "Seleccionar foto" : "Cambiar foto")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DarkFinanceColors.primaryText)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: "Nombre") {
                TextField("Ej. Reloj, Cámara, Joya", text: $name)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            field(label: "Descripción") {
                TextField("Opcional", text: $notes, axis: .vertical)
                    .foregroundColor(DarkFinanceColors.primaryText)
                    .darkInputStyle()
            }

            HStack(spacing: 10) {
                field(label: "Valor estimado") {
                    TextField("0.00", text: $estimatedValue)
                        .keyboardType(.decimalPad)
                        .foregroundColor(DarkFinanceColors.primaryText)
                        .darkInputStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Moneda")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DarkFinanceColors.secondaryText)
                    Picker("Moneda", selection: $currency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private var saleCard: some View {
        Toggle(isOn: $forSale) {
            Text("En venta")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DarkFinanceColors.primaryText)
        }
        .darkFinanceCard(cornerRadius: 16, padding: 16)
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DarkFinanceColors.secondaryText)
            content()
        }
    }

    private func save() {
        let object = ValuableObject(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedValue: Double(estimatedValue.replacingOccurrences(of: ",", with: ".")) ?? 0,
            currency: currency,
            forSale: forSale,
            imageData: selectedImage?.jpegData(compressionQuality: 0.7)
        )
        onSave(object)
        dismiss()
    }
}
