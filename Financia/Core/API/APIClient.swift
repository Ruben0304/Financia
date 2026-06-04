import Foundation
import os

/// Errors surfaced by every CRUD call against the FinancIA backend.
///
/// We expose specific cases so Managers can react differently to offline
/// (`networkUnavailable`) vs. backend errors (`server`) — for example, a
/// failed write should always roll back the in-memory state and surface
/// the cause to the UI, never silently retry.
enum APIError: LocalizedError {
    case invalidURL
    case encoding(Error)
    case decoding(Error)
    case networkUnavailable
    case unauthorized
    case notFound
    case conflict
    case server(status: Int, message: String?)
    case unexpected(Error?)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .encoding(let e): return "Error codificando la petición: \(e.localizedDescription)"
        case .decoding(let e): return "Error decodificando la respuesta: \(e.localizedDescription)"
        case .networkUnavailable: return "Sin conexión a internet"
        case .unauthorized: return "API key inválida o ausente"
        case .notFound: return "Recurso no encontrado"
        case .conflict: return "Conflicto: el recurso ya existe"
        case .server(let status, let message):
            return "Error del servidor (\(status))\(message.map { ": \($0)" } ?? "")"
        case .unexpected(let e):
            return "Error inesperado\(e.map { ": \($0.localizedDescription)" } ?? "")"
        }
    }
}

/// Thin async HTTP client over `URLSession`.
///
/// Every request and every response is logged via `os.Logger` so you can
/// filter the Xcode console by `[API]` (or by subsystem `com.financia.api`)
/// and see exactly what URL, body, status code and error came back. Logs
/// are gated by `#if DEBUG` so release builds stay quiet.
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let log = Logger(subsystem: "com.financia.api", category: "APIClient")

    init(baseURL: String = BackendConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        #if DEBUG
        print("🌐 [API] APIClient init — baseURL=\(baseURL), apiKey=\(BackendConfig.apiKey == nil ? "❌ NONE" : "✅ set")")
        #endif
    }

    // MARK: - Public API

    func getList<T: Decodable>(_ path: String, as: T.Type = T.self) async throws -> [T] {
        try await send(method: "GET", path: path, body: Optional<Empty>.none)
    }

    func get<T: Decodable>(_ path: String, as: T.Type = T.self) async throws -> T {
        try await send(method: "GET", path: path, body: Optional<Empty>.none)
    }

    @discardableResult
    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, as: T.Type = T.self) async throws -> T {
        try await send(method: "POST", path: path, body: body)
    }

    @discardableResult
    func put<Body: Encodable, T: Decodable>(_ path: String, body: Body, as: T.Type = T.self) async throws -> T {
        try await send(method: "PUT", path: path, body: body)
    }

    @discardableResult
    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body, as: T.Type = T.self) async throws -> T {
        try await send(method: "PATCH", path: path, body: body)
    }

    @discardableResult
    func delete(_ path: String) async throws -> DeleteResponse {
        try await send(method: "DELETE", path: path, body: Optional<Empty>.none)
    }

    // MARK: - Internal

    private func send<Body: Encodable, T: Decodable>(
        method: String,
        path: String,
        body: Body?
    ) async throws -> T {
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ [API] Invalid URL: \(urlString)")
            #endif
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = BackendConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        if let userID = AuthManager.shared.currentUserID {
            request.setValue(userID, forHTTPHeaderField: "X-User-ID")
        }
        request.timeoutInterval = 20

        // Encode body
        if let body, !(body is Empty) {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                #if DEBUG
                print("❌ [API] \(method) \(path) — encode failed: \(error)")
                print("   Body type: \(type(of: body))")
                #endif
                throw APIError.encoding(error)
            }
        }

        // Log outgoing request
        #if DEBUG
        let startedAt = Date()
        print("➡️  [API] \(method) \(urlString)")
        if let body = request.httpBody, let json = String(data: body, encoding: .utf8) {
            let truncated = json.count > 800 ? String(json.prefix(800)) + "… (\(json.count) chars)" : json
            print("   body: \(truncated)")
        }
        #endif

        // Send
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            #if DEBUG
            print("📴 [API] \(method) \(path) — NETWORK UNAVAILABLE (\(error.code.rawValue) \(error.localizedDescription))")
            #endif
            throw APIError.networkUnavailable
        } catch let error as URLError {
            #if DEBUG
            print("❌ [API] \(method) \(path) — URLError \(error.code.rawValue): \(error.localizedDescription)")
            print("   userInfo: \(error.userInfo)")
            #endif
            throw APIError.unexpected(error)
        } catch {
            #if DEBUG
            print("❌ [API] \(method) \(path) — \(error)")
            #endif
            throw APIError.unexpected(error)
        }

        guard let http = response as? HTTPURLResponse else {
            #if DEBUG
            print("❌ [API] \(method) \(path) — response wasn't HTTPURLResponse")
            #endif
            throw APIError.unexpected(nil)
        }

        #if DEBUG
        let elapsed = Date().timeIntervalSince(startedAt)
        let icon = (200..<300).contains(http.statusCode) ? "✅" : "⚠️"
        print("\(icon) [API] \(method) \(path) → HTTP \(http.statusCode) (\(String(format: "%.0f", elapsed * 1000))ms, \(data.count)B)")
        if !(200..<300).contains(http.statusCode), let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            let truncated = raw.count > 1200 ? String(raw.prefix(1200)) + "…" : raw
            print("   response: \(truncated)")
        }
        #endif

        switch http.statusCode {
        case 200..<300:
            if T.self == Empty.self {
                return Empty() as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                print("❌ [API] \(method) \(path) — DECODE FAILED as \(T.self)")
                print("   error: \(error)")
                if let raw = String(data: data, encoding: .utf8) {
                    let truncated = raw.count > 1200 ? String(raw.prefix(1200)) + "…" : raw
                    print("   raw body: \(truncated)")
                }
                #endif
                throw APIError.decoding(error)
            }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 409:
            throw APIError.conflict
        default:
            let msg = String(data: data, encoding: .utf8)
            throw APIError.server(status: http.statusCode, message: msg)
        }
    }
}

/// Marker type for endpoints that don't take a body / don't return one.
struct Empty: Codable {}

/// Mirror of the backend `DeleteResponse`.
struct DeleteResponse: Codable {
    let id: String
    let deleted: Bool
}
