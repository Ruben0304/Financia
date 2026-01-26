import Foundation

struct UserProfile: Codable, Hashable {
    var nombre: String
    var avatarData: Data?
    var situacionFinanciera: String
    var estrategiaFinanciera: String

    init(
        nombre: String = "",
        avatarData: Data? = nil,
        situacionFinanciera: String = "",
        estrategiaFinanciera: String = ""
    ) {
        self.nombre = nombre
        self.avatarData = avatarData
        self.situacionFinanciera = situacionFinanciera
        self.estrategiaFinanciera = estrategiaFinanciera
    }
}
