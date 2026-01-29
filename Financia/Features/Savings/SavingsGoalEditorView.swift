import SwiftUI
import PhotosUI
import LinkPresentation

extension UIImage: @unchecked Sendable {}
extension LPLinkMetadata: @unchecked Sendable {}

struct SavingsGoalEditorView: View {
    @EnvironmentObject var savingsGoalManager: SavingsGoalManager
    @Environment(\.dismiss) private var dismiss

    @State private var nombre: String = ""
    @State private var descripcion: String = ""
    @State private var precio: String = ""
    @State private var monedaSeleccionada: Currency = .usd
    @State private var productURL: String = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var linkPreviewTitle: String?
    @State private var linkPreviewImage: UIImage?
    @State private var isFetchingMetadata = false
    @State private var linkError: String?

    @State private var userEditedName = false
    @State private var userPickedImage = false
    @State private var isAutoFillingName = false
    @State private var metadataTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Imagen") {
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
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Información") {
                    TextField("Nombre de la meta", text: $nombre)
                        .onChange(of: nombre) { _ in
                            if !isAutoFillingName {
                                userEditedName = true
                            }
                        }

                    TextField("Descripción (opcional)", text: $descripcion)
                }

                Section("Precio") {
                    TextField("Precio objetivo", text: $precio)
                        .keyboardType(.decimalPad)

                    Picker("Moneda", selection: $monedaSeleccionada) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Link del producto") {
                    TextField("https://...", text: $productURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: productURL) { _ in
                            scheduleMetadataFetch()
                        }

                    if isFetchingMetadata {
                        HStack {
                            ProgressView()
                            Text("Buscando datos del link...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let linkError {
                        Text(linkError)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let title = linkPreviewTitle {
                        HStack(spacing: 12) {
                            if let previewImage = linkPreviewImage {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "link")
                                            .foregroundColor(.secondary)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text("Datos detectados")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nueva meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveGoal()
                    }
                    .disabled(!canSave)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        userPickedImage = true
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        guard !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return Double(precio.replacingOccurrences(of: ",", with: ".")) ?? 0 > 0
    }

    private func scheduleMetadataFetch() {
        metadataTask?.cancel()
        let trimmed = productURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            linkPreviewTitle = nil
            linkPreviewImage = nil
            linkError = nil
            isFetchingMetadata = false
            return
        }

        metadataTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                fetchLinkMetadata(for: url)
            }
        }
    }

    private func fetchLinkMetadata(for url: URL) {
        isFetchingMetadata = true
        linkError = nil
        linkPreviewTitle = nil
        linkPreviewImage = nil

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            DispatchQueue.main.async {
                self.isFetchingMetadata = false

                if let _ = error {
                    self.linkError = "No se pudo leer el link. Puedes completar manualmente."
                    return
                }

                guard let metadata else {
                    self.linkError = "No se encontraron datos en el link."
                    return
                }

                if let title = metadata.title, !title.isEmpty {
                    self.linkPreviewTitle = title
                    if !self.userEditedName && self.nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.isAutoFillingName = true
                        self.nombre = title
                        self.isAutoFillingName = false
                    }
                }

                let imageProvider = metadata.imageProvider ?? metadata.iconProvider
                imageProvider?.loadObject(ofClass: UIImage.self) { object, _ in
                    let image = object as? UIImage
                    DispatchQueue.main.async {
                        if let image = image {
                            self.linkPreviewImage = image
                            if !self.userPickedImage && self.selectedImage == nil {
                                self.selectedImage = image
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveGoal() {
        guard canSave else { return }

        let normalizedPrice = Double(precio.replacingOccurrences(of: ",", with: ".")) ?? 0
        let goal = SavingsGoal(
            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            descripcion: descripcion.trimmingCharacters(in: .whitespacesAndNewlines),
            precioObjetivo: normalizedPrice,
            moneda: monedaSeleccionada,
            imagenData: selectedImage?.jpegData(compressionQuality: 0.7),
            productURL: productURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : productURL
        )

        savingsGoalManager.addSavingsGoal(goal)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SavingsGoalEditorView()
            .environmentObject(SavingsGoalManager.shared)
    }
}
