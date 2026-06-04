import Foundation

struct UserProfile: Codable, Hashable {
    var nombre: String
    var avatarData: Data?
    var situacionFinanciera: String
    var estrategiaFinanciera: String
    var accentColorHex: String?
    var automationWalletId: UUID?

    init(
        nombre: String = "",
        avatarData: Data? = nil,
        situacionFinanciera: String = "",
        estrategiaFinanciera: String = "",
        accentColorHex: String? = nil,
        automationWalletId: UUID? = nil
    ) {
        self.nombre = nombre
        self.avatarData = avatarData
        self.situacionFinanciera = situacionFinanciera
        self.estrategiaFinanciera = estrategiaFinanciera
        self.accentColorHex = accentColorHex
        self.automationWalletId = automationWalletId
    }
}
