import Foundation

enum ChatAPIError: Error {
    case invalidResponse
    case serverError(String)
    case encodingError
    case networkError(Error)
}

class ChatService {
    private let baseURL: String

    init(baseURL: String = "https://financia-backend-production.up.railway.app/api/v1/assistant") {
        self.baseURL = baseURL
    }

    /// Envía un mensaje al chat y recibe la respuesta en streaming
    func sendMessage(_ message: String) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: "\(baseURL)/chat/stream") else {
            throw ChatAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["content": message]
        guard let httpBody = try? JSONEncoder().encode(body) else {
            throw ChatAPIError.encodingError
        }
        request.httpBody = httpBody

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatAPIError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        if let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: String],
                           let detail = errorDict["detail"] {
                            continuation.finish(throwing: ChatAPIError.serverError(detail))
                        } else {
                            continuation.finish(throwing: ChatAPIError.serverError("Status: \(httpResponse.statusCode)"))
                        }
                        return
                    }

                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        if let chunk = String(data: buffer, encoding: .utf8) {
                            continuation.yield(chunk)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ChatAPIError.networkError(error))
                }
            }
        }
    }
}
