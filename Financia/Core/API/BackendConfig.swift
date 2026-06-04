import Foundation

/// Central configuration for the FinancIA backend.
///
/// The app always talks to the Railway deployment. Set `BackendAPIKey` in
/// Info.plist (via an xcconfig or directly) to match the `API_KEY` env var
/// on Railway once you lock the endpoint down.
///
/// While `API_KEY` is empty on Railway, no key header is needed and every
/// call succeeds — don't leave it empty in production.
enum BackendConfig {
    static let baseURL = "https://financia-backend-production.up.railway.app/api/v1"

    static var apiKey: String? {
        let key = Bundle.main.object(forInfoDictionaryKey: "BackendAPIKey") as? String
        return key?.isEmpty == false ? key : nil
    }
}
