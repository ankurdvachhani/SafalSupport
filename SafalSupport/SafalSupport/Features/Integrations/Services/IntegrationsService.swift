import Foundation

protocol IntegrationsServicing {
    func loginToEpicMyChart(email: String, password: String) async throws -> EpicMyChartResponse
    func connectEpicMyChart(user: EpicMyChartUser) async throws -> EmptyResponse
    func disconnectEpicMyChart() async throws -> EmptyResponse
    
    func loginToSafalCalendar(email: String, password: String) async throws -> SafalCalendarResponse
    func connectSafalCalendar(user: SafalCalendarUser) async throws -> EmptyResponse
    func disconnectSafalCalendar() async throws -> EmptyResponse
    
    func fetchUserExtraData() async throws -> UserExtraResponse
}

struct ConnectUserData: Codable {
    let reLoginRequired: Bool
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let country: String
    let profilePicture: String?
    let isEmailVerified: Bool
    let createdAt: String
    let updatedAt: String
    let phoneNumber: Int64?
    
    enum CodingKeys: String, CodingKey {
        case reLoginRequired
        case id = "_id"
        case firstName, lastName, email, role, country
        case profilePicture, isEmailVerified, createdAt, updatedAt
        case phoneNumber
    }
}

struct ConnectResponse: Codable {
    let message: String
    let data: ConnectUserData
    let success: Bool
}

class IntegrationsService: IntegrationsServicing {
    
    private let networkManager: NetworkManaging
    
    init(networkManager: NetworkManaging = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    // MARK: - Epic MyChart Integration
    
    func loginToEpicMyChart(email: String, password: String) async throws -> EpicMyChartResponse {
        let endpoint = Endpoint(path: APIConfig.Path.epicMyChartLogin)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.post.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        let loginRequest = IntegrationLoginRequest(email: email, password: password)
        request.httpBody = try? JSONEncoder().encode(loginRequest)
        
        do {
            return try await networkManager.fetch(endpoint, urlRequest: request)
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                throw IntegrationError.invalidCredentials
            default:
                throw IntegrationError.connectionFailed
            }
        } catch {
            throw IntegrationError.connectionFailed
        }
    }
    
    func connectEpicMyChart(user: EpicMyChartUser) async throws -> EmptyResponse {
        let endpoint = Endpoint(path: APIConfig.Path.connectEpicMyChart)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.post.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        // Pass only the basic user parameters
        let connectRequest = [
            "id": user.id,
            "firstName": user.firstName,
            "lastName": user.lastName,
            "email": user.email,
            "role": user.role,
            "profilePicture": user.profilePicture ?? ""
        ]
        request.httpBody = try? JSONEncoder().encode(connectRequest)
        
        do {
            let response: ConnectResponse = try await networkManager.fetch(endpoint, urlRequest: request)
            
            // After successful connection, no need to update UserDefaults
            // Connection status will be checked via /api/user/extra endpoint
            
            return EmptyResponse(success: response.success, message: response.message)
        } catch {
            throw IntegrationError.connectionFailed
        }
    }
    
    func disconnectEpicMyChart() async throws -> EmptyResponse {
        let endpoint = Endpoint(path: APIConfig.Path.disconnectEpicMyChart)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.post.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        do {
            let response: EmptyResponse = try await networkManager.fetch(endpoint, urlRequest: request)
            
            // After successful disconnection, no need to update UserDefaults
            // Connection status will be checked via /api/user/extra endpoint
            
            return response
        } catch {
            throw IntegrationError.disconnectFailed
        }
    }
    
    // MARK: - SafalCalendar Integration
    
    func loginToSafalCalendar(email: String, password: String) async throws -> SafalCalendarResponse {
        let endpoint = Endpoint(path: APIConfig.Path.safalCalendarLogin)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.post.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        let loginRequest = IntegrationLoginRequest(email: email, password: password)
        request.httpBody = try? JSONEncoder().encode(loginRequest)
        
        do {
            return try await networkManager.fetch(endpoint, urlRequest: request)
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                throw IntegrationError.invalidCredentials
            default:
                throw IntegrationError.connectionFailed
            }
        } catch {
            throw IntegrationError.connectionFailed
        }
    }
    
    func connectSafalCalendar(user: SafalCalendarUser) async throws -> EmptyResponse {
        let endpoint = Endpoint(path: APIConfig.Path.connectSafalCalendar)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.post.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        // Pass only the basic user parameters
        let connectRequest = [
            "id": user.id,
            "firstName": user.firstName,
            "lastName": user.lastName,
            "email": user.email,
            "role": user.role,
            "profilePicture": user.profilePicture ?? ""
        ]
        request.httpBody = try? JSONEncoder().encode(connectRequest)
        
        do {
            let response: ConnectResponse = try await networkManager.fetch(endpoint, urlRequest: request)
            
            // After successful connection, no need to update UserDefaults
            // Connection status will be checked via /api/user/extra endpoint
            
            return EmptyResponse(success: response.success, message: response.message)
        } catch {
            throw IntegrationError.connectionFailed
        }
    }
    
    func disconnectSafalCalendar() async throws -> EmptyResponse {
        let endpoint = Endpoint(path: APIConfig.Path.disconnectSafalCalendar)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.post.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        do {
            let response: EmptyResponse = try await networkManager.fetch(endpoint, urlRequest: request)
            
            // After successful disconnection, no need to update UserDefaults
            // Connection status will be checked via /api/user/extra endpoint
            
            return response
        } catch {
            throw IntegrationError.disconnectFailed
        }
    }
    
    // MARK: - User Extra Data
    
    func fetchUserExtraData() async throws -> UserExtraResponse {
        let endpoint = Endpoint(path: APIConfig.Path.userExtra)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = APIConfig.HTTPMethod.get.rawValue
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Add access token from TokenManager if available
        if let token = TokenManager.shared.getToken() {
            request.setValue("access_token=\(token)", forHTTPHeaderField: APIConfig.Header.cookie)
        }
        
        do {
            return try await networkManager.fetch(endpoint, urlRequest: request)
        } catch {
            throw IntegrationError.connectionFailed
        }
    }
}
