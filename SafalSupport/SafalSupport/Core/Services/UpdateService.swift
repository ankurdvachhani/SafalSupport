import Foundation

class UpdateService {
    static let shared = UpdateService()
    private let networkManager: NetworkManager
    
    init() {
        self.networkManager = DIContainer.shared.resolve()
    }
    
    func checkForUpdates() async throws -> VersionCheckResponse {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        let urlString = APIConfig.utilitiesUrl + APIConfig.Path.appVersionCheck
        let queryItems = [
            URLQueryItem(name: "slug", value: APIConfig.applicationId),
            URLQueryItem(name: "type", value: "ios"),
            URLQueryItem(name: "version", value: currentVersion)
        ]
        
        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        return try decoder.decode(VersionCheckResponse.self, from: data)
    }
}

