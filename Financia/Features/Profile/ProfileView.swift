import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var exchangeRateManager: ExchangeRateManager
    @State private var nombre: String = ""
    @State private var situacion: String = ""
    @State private var estrategia: String = ""
    @State private var usdToCupText: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var accentColor: Color = Color(hex: "FF5C00")

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

            Section("Color principal") {
                ColorPicker("Acento", selection: $accentColor, supportsOpacity: false)
            }
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneToolbar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    saveProfile()
                }
            }
        }
        .onAppear {
            loadProfile()
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    private var avatarView: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            if let data = avatarData, let uiImage = UIImage(data: data) {
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
            accentColorHex: colorToHex(accentColor) ?? "FF5C00"
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
}
