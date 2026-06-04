import SwiftUI

struct InvitationAccessView: View {
    let appleUserID: String
    let appleName: String

    @EnvironmentObject private var authManager: AuthManager
    @State private var nombre: String
    @State private var codigo = ""

    init(appleUserID: String, appleName: String) {
        self.appleUserID = appleUserID
        self.appleName = appleName
        _nombre = State(initialValue: appleName)
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(alignment: .leading, spacing: 32) {
                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Código de invitación")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(AuroraColors.primaryText)

                    Text("Necesitas un código para registrarte por primera vez.")
                        .font(.subheadline)
                        .foregroundStyle(AuroraColors.secondaryText)
                        .lineSpacing(3)
                }

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AuroraColors.secondaryText)
                        TextField("Tu nombre", text: $nombre)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Código")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AuroraColors.secondaryText)
                        TextField("XXXX-XXXX", text: $codigo)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Button(action: submit) {
                    HStack {
                        Spacer()
                        if authManager.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Registrarme")
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                    }
                    .frame(height: 52)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(authManager.isLoading || nombre.trimmingCharacters(in: .whitespaces).isEmpty || codigo.trimmingCharacters(in: .whitespaces).isEmpty)

                if let error = authManager.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.25), value: authManager.error)
            .keyboardDoneToolbar()
        }
        .ignoresSafeArea()
    }

    private func submit() {
        let trimmedName = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = codigo.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        Task {
            await authManager.register(
                appleUserID: appleUserID,
                name: trimmedName,
                invitationCode: trimmedCode
            )
        }
    }
}
