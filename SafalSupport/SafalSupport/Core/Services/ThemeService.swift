import Foundation

protocol ThemeServicing {
    func fetchColors() async throws -> ThemeResponse
    func saveColors(primary: String, background: String, meeting: String, event: String) async throws
  //  func fetchColorConfig() async throws -> ColorConfig
}

class ThemeService: ThemeServicing {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    func fetchColors() async throws -> ThemeResponse {
        let endpoint = Endpoint(
            path: APIConfig.Path.colors,
            method: .get,
            headers: [
                APIConfig.Header.contentType: APIConfig.ContentType.json,
                APIConfig.Header.cookie: "access_token=\(TokenManager.shared.getToken() ?? "")"
            ]
        )
        
        return try await networkManager.fetch(endpoint)
    }
    
    func saveColors(primary: String, background: String, meeting: String, event: String) async throws {
        let endpoint = Endpoint(
            path: APIConfig.Path.saveColors,
            method: .put,
            headers: [
                APIConfig.Header.contentType: APIConfig.ContentType.json,
                APIConfig.Header.cookie: "access_token=\(TokenManager.shared.getToken() ?? "")"
            ]
        )
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        let body = [
            "primary": primary,
            "background": background,
            "meeting": meeting,
            "event": event
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.allHTTPHeaderFields = endpoint.headers
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Use NetworkManager's fetch method with EmptyResponse type
        let _: EmptyResponse = try await networkManager.fetch(endpoint, urlRequest: urlRequest)
    }
    
//    func fetchColorConfig() async throws -> ColorConfig {
//        let endpoint = Endpoint(
//            path: APIConfig.Path.colorsConfig,
//            method: .get,
//            headers: [
//                APIConfig.Header.contentType: APIConfig.ContentType.json,
//                APIConfig.Header.cookie: "access_token=\(TokenManager.shared.getToken() ?? "")"
//            ]
//        )
//        
//        let response: ColorConfigResponse = try await networkManager.fetch(endpoint)
//        // Save to local storage
//        ColorConfig.save(response.data)
//        return response.data
//    }
} 
