import Foundation

struct ElToqueRatesResponse: Codable {
    let tasas: [String: Double]
    let date: String
}

final class ElToqueAPI {
    private let session: URLSession
    private let baseURL = URL(string: "https://tasas.eltoque.com")!
    private let token: String
    
    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }
    
    func fetchTasas(completion: @escaping (Result<[String: Double], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("v1/trmi")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])))
                return
            }
            
            guard (200...299).contains(http.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status code \(http.statusCode)"])))
                return
            }
            
            if data.isEmpty {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Response data was empty."])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(ElToqueRatesResponse.self, from: data)
                completion(.success(response.tasas))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
