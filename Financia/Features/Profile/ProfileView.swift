import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var exchangeRateManager: ExchangeRateManager
    @EnvironmentObject private var cloudKitStatusManager: CloudKitStatusManager
    @State private var nombre: String = ""
    @State private var situacion: String = ""
    @State private var estrategia: String = ""
    @State private var usdToCupText: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var accentColor: Color = Color(hex: "FF5C00")
    @State private var automationWalletId: UUID?

    // Claude AI / MCP
    @State private var mcpToken: String? = nil
    @State private var isLoadingToken = false
    @State private var mcpTokenError: String? = nil
    @State private var tokenCopied = false

    // Account deletion
    @EnvironmentObject private var authManager: AuthManager
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String? = nil

    private let mcpServerURL = "https://financia-mcp.up.railway.app/mcp"

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    avatarView
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Tu nombre", text: $nombre)
                            .font(.headline)
                        Text("Perfil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Metas y objetivos") {
                NavigationLink(destination: SavingsGoalsView()) {
                    Label("Ahorros", systemImage: "star.circle.fill")
                }
            }

            Section("Situación financiera") {
                TextField("Describe tu situación actual", text: $situacion, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Estrategia financiera") {
                TextField("Describe tu estrategia", text: $estrategia, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Automatizaciones") {
                Picker("Cartera para borradores", selection: $automationWalletId) {
                    Text("Sin seleccionar")
                        .tag(Optional<UUID>.none)

                    ForEach(walletManager.wallets) { wallet in
                        Text("\(wallet.name) (\(wallet.currency.rawValue))")
                            .tag(Optional(wallet.id))
                    }
                }

                Text("Los borradores automáticos usarán esta cartera por defecto. La moneda saldrá de esa cartera.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Cambio USD (informal)") {
                TextField("1 USD = ? CUP", text: $usdToCupText)
                    .keyboardType(.decimalPad)

                if let suggestedRate = exchangeRateManager.rate(for: "USD") {
                    HStack {
                        Text("Sugerido")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Usar \(formattedRate(suggestedRate))") {
                            usdToCupText = formattedRate(suggestedRate)
                        }
                    }
                    .font(.caption)
                } else {
                    Text("Sin tasa oficial disponible. Usa un valor manual.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Estado de iCloud") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cloudKitStatusManager.state.isAvailable ? "checkmark.icloud.fill" : "icloud.slash")
                        .foregroundStyle(cloudKitStatusManager.state.isAvailable ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudKitStatusManager.state.title)
                            .font(.headline)
                        Text(cloudKitStatusManager.state.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cloudKitStatusManager.isUsingCloudKitStore ? "externaldrive.badge.icloud" : "externaldrive")
                        .foregroundStyle(cloudKitStatusManager.isUsingCloudKitStore ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudKitStatusManager.isUsingCloudKitStore ? "Store CloudKit activo" : "Store local activo")
                            .font(.headline)
                        Text(cloudKitStatusManager.persistenceMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Comprobar de nuevo") {
                    Task {
                        await cloudKitStatusManager.refresh()
                    }
                }

                if cloudKitStatusManager.state.shouldShowSettingsAction {
                    Button("Abrir Ajustes") {
                        openSettings()
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("Claude AI")
                        .font(.headline)
                }

                if let token = mcpToken {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tu conexión está lista.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // MCP URL row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL del servidor")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(mcpServerURL)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = mcpServerURL
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                        }

                        // Token row
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Token de acceso")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("Bearer \(token)")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = "Bearer \(token)"
                                    tokenCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        tokenCopied = false
                                    }
                                } label: {
                                    Image(systemName: tokenCopied ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                        .foregroundStyle(tokenCopied ? .green : .accentColor)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                        }

                        Text("En Claude.ai → Settings → Integrations → Add MCP Server. Pega la URL y agrega el header Authorization con el token.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if isLoadingToken {
                    HStack {
                        ProgressView()
                        Text("Generando token…")
                            .foregroundColor(.secondary)
                    }
                } else {
                    if let error = mcpTokenError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Button("Conectar con Claude") {
                        fetchMcpToken()
                    }
                }
            } header: {
                Text("Claude AI")
            } footer: {
                Text("Conecta Claude a tus datos de FinancIA para hacer preguntas y registrar gastos desde cualquier dispositivo.")
            }

            Section("Color principal") {
                ColorPicker("Acento", selection: $accentColor, supportsOpacity: false)
            }

            Section {
                Button {
                    authManager.signOut()
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section {
                if isDeletingAccount {
                    HStack {
                        ProgressView()
                        Text("Eliminando cuenta…")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Eliminar cuenta", systemImage: "trash")
                    }
                }

                if let error = deleteAccountError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } footer: {
                Text("Esta acción es irreversible. Se eliminarán todos tus datos, transacciones, carteras y configuración.")
            }
        }
        .confirmationDialog(
            "¿Eliminar cuenta?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar cuenta", role: .destructive) {
                deleteAccount()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrarán permanentemente todos tus datos. Esta acción no se puede deshacer.")
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .title) {
                Text("Perfil")
                    .darkFinanceToolbarTitle(size: 24)
                    .foregroundColor(DarkFinanceColors.primaryText)
            }

            ToolbarItem(placement: .subtitle) {
                Text("Tu identidad, contexto y preferencias")
                    .darkFinanceToolbarSubtitle(size: 12, weight: .medium)
                    .foregroundColor(DarkFinanceColors.secondaryText)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    saveProfile()
                }
            }
        }
        .onAppear {
            loadProfile()
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    private var avatarView: some View {
        let currentAvatarData = avatarData

        return PhotosPicker(selection: $selectedItem, matching: .images) {
            if let data = currentAvatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func loadProfile() {
        let profile = profileManager.profile
        nombre = profile.nombre
        situacion = profile.situacionFinanciera
        estrategia = profile.estrategiaFinanciera
        avatarData = profile.avatarData
        accentColor = Color(hex: profile.accentColorHex ?? "FF5C00")
        automationWalletId = profile.automationWalletId
        if let manualRate = exchangeRateManager.manualUsdToCupRate {
            usdToCupText = formattedRate(manualRate)
        }
    }

    private func saveProfile() {
        let updated = UserProfile(
            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarData: avatarData,
            situacionFinanciera: situacion.trimmingCharacters(in: .whitespacesAndNewlines),
            estrategiaFinanciera: estrategia.trimmingCharacters(in: .whitespacesAndNewlines),
            accentColorHex: colorToHex(accentColor) ?? "FF5C00",
            automationWalletId: automationWalletId
        )
        profileManager.saveProfile(updated)

        let manualRate = parseRate(usdToCupText)
        exchangeRateManager.updateManualUsdToCupRate(manualRate)
    }

    private func parseRate(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized), value > 0 {
            return value
        }
        return nil
    }

    private func formattedRate(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func colorToHex(_ color: Color) -> String? {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    private func deleteAccount() {
        isDeletingAccount = true
        deleteAccountError = nil
        Task {
            do {
                _ = try await APIClient.shared.delete("/users/me")
                await MainActor.run {
                    authManager.signOut()
                }
            } catch {
                await MainActor.run {
                    deleteAccountError = "No se pudo eliminar la cuenta. Intenta de nuevo."
                    isDeletingAccount = false
                }
            }
        }
    }

    private func fetchMcpToken() {
        isLoadingToken = true
        mcpTokenError = nil
        Task {
            do {
                let response = try await APIClient.shared.post(
                    "/users/mcp-token",
                    body: Empty(),
                    as: MCPTokenResponse.self
                )
                await MainActor.run { mcpToken = response.token }
            } catch {
                await MainActor.run { mcpTokenError = error.localizedDescription }
            }
            await MainActor.run { isLoadingToken = false }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Supporting types

private struct MCPTokenResponse: Decodable {
    let token: String
}
