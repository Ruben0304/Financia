import SwiftUI
import UIKit
import Combine

struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReceiptScannerViewModel()

    let onExtracted: (ReceiptExtraction) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Sección de imagen
                        imageSection

                        // Sección de instrucciones
                        if viewModel.selectedImage != nil {
                            instructionsSection
                        }

                        // Botón de procesamiento
                        if viewModel.selectedImage != nil && !viewModel.instructions.isEmpty {
                            processButton
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Escanear Vale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay {
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
        }
    }

    // MARK: - Subviews

    private var imageSection: some View {
        VStack(spacing: 16) {
            if let image = viewModel.selectedImage {
                // Preview de imagen seleccionada
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                Button(role: .destructive) {
                    viewModel.selectedImage = nil
                } label: {
                    Label("Eliminar imagen", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            } else {
                // Botones para seleccionar imagen
                VStack(spacing: 12) {
                    Button {
                        viewModel.showImagePicker = true
                        viewModel.sourceType = .camera
                    } label: {
                        Label("Tomar Foto", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button {
                        viewModel.showImagePicker = true
                        viewModel.sourceType = .photoLibrary
                    } label: {
                        Label("Seleccionar de Galería", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.vertical, 40)
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(
                image: $viewModel.selectedImage,
                sourceType: viewModel.sourceType
            )
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instrucciones")
                .font(.headline)

            TextField("Ej: todo es mío, somos 3 personas...", text: $viewModel.instructions, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .lineLimit(3...6)

            Text("Indica qué parte del vale te corresponde")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var processButton: some View {
        Button {
            Task {
                if let extraction = await viewModel.processReceipt() {
                    onExtracted(extraction)
                    dismiss()
                }
            }
        } label: {
            Text("Procesar Vale")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Procesando vale...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

// MARK: - ViewModel

@MainActor
class ReceiptScannerViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var instructions: String = ""
    @Published var isProcessing: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showImagePicker: Bool = false
    @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary

    private let receiptService: ReceiptService
    private let lugarManager: LugarManager

    init(receiptService: ReceiptService = ReceiptService(), lugarManager: LugarManager = .shared) {
        self.receiptService = receiptService
        self.lugarManager = lugarManager
    }

    func processReceipt() async -> ReceiptExtraction? {
        guard let image = selectedImage else { return nil }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let lugares: [Lugar]? = lugarManager.lugares.isEmpty ? nil : lugarManager.lugares

            print("[ReceiptScanner] Starting extract. Instructions length: \(instructions.count)")

            let extraction = try await receiptService.extractReceipt(
                image: image,
                instrucciones: instructions,
                lugaresConocidos: lugares
            )

            print("[ReceiptScanner] Extraction success: monto=\(extraction.monto), moneda=\(extraction.moneda)")
            return extraction
        } catch let error as ReceiptAPIError {
            switch error {
            case .invalidResponse:
                errorMessage = "Respuesta inválida del servidor"
            case .serverError(let message):
                errorMessage = message
            case .invalidImage:
                errorMessage = "La imagen no es válida"
            case .encodingError:
                errorMessage = "Error al codificar los datos"
            case .networkError(let err):
                errorMessage = "Error de red: \(err.localizedDescription)"
            }
            print("[ReceiptScanner] ReceiptAPIError: \(errorMessage)")
            showError = true
            return nil
        } catch {
            errorMessage = "Error desconocido: \(error.localizedDescription)"
            print("[ReceiptScanner] Unknown error: \(error)")
            showError = true
            return nil
        }
    }
}

// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ReceiptScannerView { extraction in
        print("Extracted: \(extraction)")
    }
}
