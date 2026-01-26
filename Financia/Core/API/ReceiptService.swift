import Foundation
import UIKit

enum ReceiptAPIError: Error {
    case invalidResponse
    case serverError(String)
    case invalidImage
    case encodingError
    case networkError(Error)
}

class ReceiptService {
    private let baseURL: String

    init(baseURL: String = "https://financia-backend-production.up.railway.app/api/v1/assistant") {
        self.baseURL = baseURL
    }

    /// Extrae información de un vale/recibo
    /// - Parameters:
    ///   - image: Imagen del vale
    ///   - instrucciones: Instrucciones sobre qué parte te corresponde
    ///   - lugaresConocidos: Lista de lugares guardados para matching
    /// - Returns: Información extraída del vale
    func extractReceipt(
        image: UIImage,
        instrucciones: String,
        lugaresConocidos: [Lugar]? = nil
    ) async throws -> ReceiptExtraction {

        guard let url = URL(string: "\(baseURL)/receipt/extract") else {
            throw ReceiptAPIError.invalidResponse
        }

        print("[ReceiptService] URL: \(url.absoluteString)")
        print("[ReceiptService] Instructions: \(instrucciones)")
        print("[ReceiptService] Known places count: \(lugaresConocidos?.count ?? 0)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Agregar imagen
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ReceiptAPIError.invalidImage
        }
        print("[ReceiptService] Image bytes: \(imageData.count)")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Agregar instrucciones
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"instrucciones\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(instrucciones)\r\n".data(using: .utf8)!)

        // Agregar lugares conocidos (si existen)
        if let lugares = lugaresConocidos, !lugares.isEmpty {
            let lugaresAPI = lugares.map { KnownPlace(from: $0) }

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase

            guard let lugaresJSON = try? encoder.encode(lugaresAPI) else {
                throw ReceiptAPIError.encodingError
            }

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"lugares_conocidos\"\r\n\r\n".data(using: .utf8)!)
            body.append(lugaresJSON)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReceiptAPIError.invalidResponse
            }

            print("[ReceiptService] Status: \(httpResponse.statusCode)")
            if let raw = String(data: data, encoding: .utf8) {
                print("[ReceiptService] Raw response: \(raw)")
            } else {
                print("[ReceiptService] Raw response: <non-utf8>, bytes=\(data.count)")
            }

            guard httpResponse.statusCode == 200 else {
                // Intentar parsear mensaje de error del servidor
                if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                   let detail = errorDict["detail"] {
                    throw ReceiptAPIError.serverError(detail)
                }
                throw ReceiptAPIError.serverError("Status: \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let decoded = try decoder.decode(ReceiptExtraction.self, from: data)
                print("[ReceiptService] Decoded extraction: monto=\(decoded.monto), moneda=\(decoded.moneda), subitems=\(decoded.subitems?.count ?? 0)")
                return decoded
            } catch {
                print("[ReceiptService] Decode error: \(error)")
                throw error
            }

        } catch let error as ReceiptAPIError {
            throw error
        } catch {
            throw ReceiptAPIError.networkError(error)
        }
    }
}
