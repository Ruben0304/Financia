import SwiftUI

struct InvitationAccessView: View {
    @AppStorage("invitationValidated") private var invitationValidated = false
    @AppStorage("invitationName") private var invitationName = ""

    @State private var nombre: String = ""
    @State private var codigo: String = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var messageColor: Color = .secondary

    private let service = InvitationService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acceso")
                            .font(.title.bold())
                        Text("Ingresa tu nombre y el código de invitación para continuar.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section("Datos") {
                    TextField("Nombre", text: $nombre)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    TextField("Código de invitación", text: $codigo)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                }

                Section {
                    Button(action: validate) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text(isLoading ? "Validando..." : "Continuar")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                } footer: {
                    if let message {
                        Text(message)
                            .foregroundColor(messageColor)
                    }
                }
            }
            .navigationTitle("Acceso")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
        }
    }

    private func validate() {
        let trimmedName = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = codigo.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmedName.isEmpty, !trimmedCode.isEmpty else {
            message = "Completa tu nombre y el código de invitación."
            messageColor = .red
            return
        }

        isLoading = true
        message = nil

        Task {
            do {
                let response = try await service.validate(code: trimmedCode, nombre: trimmedName)
                message = response.mensaje
                messageColor = response.valido ? Color(red: 0.20, green: 0.60, blue: 0.46) : .red

                if response.valido {
                    invitationName = trimmedName
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    invitationValidated = true
                }
            } catch let error as InvitationAPIError {
                message = error.localizedDescription
                messageColor = .red
            } catch {
                message = "No se pudo validar el código."
                messageColor = .red
            }
            isLoading = false
        }
    }
}

#Preview {
    InvitationAccessView()
}
