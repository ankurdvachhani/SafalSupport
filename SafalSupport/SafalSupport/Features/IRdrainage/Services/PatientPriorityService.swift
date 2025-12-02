import Foundation

// MARK: - Priority Update Models
struct PriorityUpdateRequest: Codable {
    let metadata: PatientMetadataUpdate
}

struct PatientMetadataUpdate: Codable {
    let organizationId: String
    let priority: String
    let ncpiNumber: String?
}

struct PriorityUpdateResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Patient Priority Service
class PatientPriorityService {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    func updatePatientPriority(patientId:String,patientSlug: String, priority: Priority, organizationId: String, ncpiNumber: String?) async throws -> Bool {
    
        
        let endpoint = Endpoint(path: "\(APIConfig.Path.userUpdate)")
        
        // Create URL with query parameter for patientId
        var urlComponents = URLComponents(string: APIConfig.baseURL + endpoint.path)
        urlComponents?.queryItems = [
            URLQueryItem(name: "id", value: patientId)
        ]
        
        guard let url = urlComponents?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        // Create metadata object
        let metadata = PatientMetadataUpdate(
            organizationId: organizationId,
            priority: priority.rawValue,
            ncpiNumber: ncpiNumber
        )
        
        let updateRequest = PriorityUpdateRequest(metadata: metadata)
        
        do {
            request.httpBody = try JSONEncoder().encode(updateRequest)
        } catch {
            throw NetworkError.invalidResponse
        }
        
        let response: PriorityUpdateResponse = try await networkManager.fetch(endpoint, urlRequest: request)
        
        return response.success
    }
}
