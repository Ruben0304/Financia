import Foundation

// MARK: - Request / Response models

struct AppleAuthRequest: Encodable {
    let appleUserId: String
    enum CodingKeys: String, CodingKey { case appleUserId = "apple_user_id" }
}

struct AppleRegisterRequest: Encodable {
    let appleUserId: String
    let name: String
    let invitationCode: String
    enum CodingKeys: String, CodingKey {
        case appleUserId    = "apple_user_id"
        case name
        case invitationCode = "invitation_code"
    }
}

struct AuthCheckResponse: Decodable {
    let exists: Bool
    let user: UserDTO?
}

struct UserDTO: Decodable {
    let id: String
    let appleUserId: String
    let name: String
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id
        case appleUserId = "apple_user_id"
        case name
        case createdAt   = "created_at"
    }
}

// MARK: - Errors

enum UserAPIError: LocalizedError {
    case codeTaken
    case codeNotFound
    case server(String)

    var errorDescription: String? {
        switch self {
        case .codeTaken:       return "El código ya fue usado."
        case .codeNotFound:    return "Código no encontrado."
        case .server(let msg): return msg
        }
    }
}

// MARK: - Service

final class UserService {
    static let shared = UserService()
    private let api = APIClient.shared
    private init() {}

    func auth(appleUserID: String) async throws -> AuthCheckResponse {
        try await api.post("/users/auth", body: AppleAuthRequest(appleUserId: appleUserID))
    }

    func register(appleUserID: String, name: String, invitationCode: String) async throws -> UserDTO {
        do {
            return try await api.post(
                "/users/register",
                body: AppleRegisterRequest(
                    appleUserId: appleUserID,
                    name: name,
                    invitationCode: invitationCode
                )
            )
        } catch APIError.conflict {
            throw UserAPIError.codeTaken
        } catch APIError.notFound {
            throw UserAPIError.codeNotFound
        } catch APIError.server(_, let msg) {
            throw UserAPIError.server(msg ?? "Error del servidor")
        }
    }
}
