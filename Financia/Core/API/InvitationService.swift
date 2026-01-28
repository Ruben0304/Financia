import Foundation

struct InvitationCodeValidationRequest: Codable {
    let codigo: String
    let nombre: String
}

struct InvitationCodeValidationResponse: Codable {
    let valido: Bool
    let mensaje: String
}

enum InvitationAPIError: Error {
    case invalidResponse
    case serverMessage(String)
    case encodingError
    case networkError(Error)
}

extension InvitationAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Respuesta inválida del servidor."
        case .serverMessage(let message):
            return message
        case .encodingError:
            return "No se pudo preparar la solicitud."
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        }
    }
}

final class InvitationService {
    private let baseURL: String

    init(baseURL: String = "https://financia-backend-production.up.railway.app/api/v1") {
        self.baseURL = baseURL
    }

    func validate(code: String, nombre: String) async throws -> InvitationCodeValidationResponse {
        guard let url = URL(string: "\(baseURL)/invitations/validate") else {
            throw InvitationAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = InvitationCodeValidationRequest(codigo: code, nombre: nombre)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw InvitationAPIError.encodingError
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw InvitationAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                return try JSONDecoder().decode(InvitationCodeValidationResponse.self, from: data)
            case 400:
                throw InvitationAPIError.serverMessage("Código inválido.")
            case 404:
                throw InvitationAPIError.serverMessage("El código no existe.")
            case 409:
                throw InvitationAPIError.serverMessage("El código ya fue usado.")
            default:
                if let response = try? JSONDecoder().decode(InvitationCodeValidationResponse.self, from: data) {
                    throw InvitationAPIError.serverMessage(response.mensaje)
                }
                throw InvitationAPIError.serverMessage("Error del servidor (\(httpResponse.statusCode)).")
            }
        } catch let error as InvitationAPIError {
            throw error
        } catch {
            throw InvitationAPIError.networkError(error)
        }
    }
}
