import Foundation

enum DebtAPIError: Error {
    case invalidResponse
    case serverError(String)
    case encodingError
    case networkError(Error)
}

class DebtEstimateService {
    private let baseURL: String

    init(baseURL: String = "https://financia-backend-production.up.railway.app/api/v1/assistant") {
        self.baseURL = baseURL
    }

    func estimateDebt(prompt: String) async throws -> DebtEstimateResponse {
        guard let url = URL(string: "\(baseURL)/debt/estimate") else {
            throw DebtAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = DebtEstimateRequest(prompt: prompt)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw DebtAPIError.encodingError
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DebtAPIError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                   let detail = errorDict["detail"] {
                    throw DebtAPIError.serverError(detail)
                }
                throw DebtAPIError.serverError("Status: \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(DebtEstimateResponse.self, from: data)
        } catch let error as DebtAPIError {
            throw error
        } catch {
            throw DebtAPIError.networkError(error)
        }
    }
}
