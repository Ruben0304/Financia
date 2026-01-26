import Foundation

// Manager genérico para persistencia usando FileManager + Codable (JSON)
class PersistenceManager {

    static let shared = PersistenceManager()

    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Generic Save/Load

    func save<T: Codable>(_ data: T, to filename: String) throws {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(data)
        try jsonData.write(to: fileURL, options: .atomic)
    }

    func load<T: Codable>(from filename: String, as type: T.Type) throws -> T {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    func fileExists(_ filename: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func delete(_ filename: String) throws {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: fileURL)
    }
}
