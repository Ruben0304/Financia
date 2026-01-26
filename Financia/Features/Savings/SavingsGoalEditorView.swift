//
//  SavingsGoalEditorView.swift
//  Financia
//
//  Created by Claude on 2026-01-26.
//

import SwiftUI
import PhotosUI

struct SavingsGoalEditorView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @Environment(\.dismiss) var dismiss

    @State private var nombre: String = ""
    @State private var descripcion: String = ""
    @State private var precio: String = ""
    @State private var monedaSeleccionada: Currency = .usd
    @State private var productURL: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false

    var body: some View {
        NavigationView {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Imagen
                        imageSectionView

                        // Campos del formulario
                        VStack(spacing: 16) {
                            // Nombre
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nombre de la meta")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AuroraColors.secondaryText)

                                TextField("Ej: iPhone 15 Pro", text: $nombre)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(AuroraColors.primaryText)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                    )
                            }

                            // Descripción
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Descripción (opcional)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AuroraColors.secondaryText)

                                TextField("Ej: Color azul titanio, 256GB", text: $descripcion)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(AuroraColors.primaryText)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                    )
                            }

                            // Precio y Moneda
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Precio objetivo")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AuroraColors.secondaryText)

                                    TextField("0.00", text: $precio)
                                        .font(.system(size: 16, weight: .regular, design: .rounded))
                                        .foregroundColor(AuroraColors.primaryText)
                                        .keyboardType(.decimalPad)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.white.opacity(0.05))
                                        )
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Moneda")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AuroraColors.secondaryText)

                                    Picker("Moneda", selection: $monedaSeleccionada) {
                                        ForEach([Currency.usd, .eur, .cup], id: \.self) { currency in
                                            Text(currency.rawValue.uppercased())
                                                .tag(currency)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                    )
                                    .tint(AuroraColors.primaryText)
                                }
                                .frame(width: 100)
                            }

                            // URL del producto
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Link del producto (opcional)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AuroraColors.secondaryText)

                                TextField("https://amazon.com/...", text: $productURL)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(AuroraColors.primaryText)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                    )
                            }
                        }
                        .padding(.horizontal, 32)

                        // Botón guardar
                        Button(action: saveGoal) {
                            Text("Crear Meta")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: canSave ? [.blue, .purple] : [.gray, .gray.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Nueva Meta de Ahorro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(AuroraColors.primaryText)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }

    private var imageSectionView: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(AuroraColors.secondaryText.opacity(0.5))

                            Text("Agregar foto")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AuroraColors.secondaryText)
                        }
                    )
            }

            Button(action: { showingImagePicker = true }) {
                Text(selectedImage == nil ? "Seleccionar foto" : "Cambiar foto")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.blue)
            }
        }
    }

    private var canSave: Bool {
        !nombre.isEmpty && Double(precio) ?? 0 > 0
    }

    private func saveGoal() {
        guard canSave else { return }

        let goal = SavingsGoal(
            nombre: nombre,
            descripcion: descripcion,
            precioObjetivo: Double(precio) ?? 0,
            moneda: monedaSeleccionada,
            imagenData: selectedImage?.jpegData(compressionQuality: 0.7),
            productURL: productURL.isEmpty ? nil : productURL
        )

        savingsGoalManager.addSavingsGoal(goal)
        dismiss()
    }
}

// ImagePicker helper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

#Preview {
    SavingsGoalEditorView()
        .environmentObject(SavingsGoalManager.shared)
}
