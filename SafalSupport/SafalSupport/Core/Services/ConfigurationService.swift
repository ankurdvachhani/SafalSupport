import Foundation
import SwiftUI

@MainActor
class ConfigurationService: ObservableObject {
    @Published var configuration: AppConfiguration?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager()
    
    static let shared = ConfigurationService()
    
    private init() {}
    
    func fetchConfiguration() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let endpoint = Endpoint(
                path: "/api/config",
                method: .get
            )
            
            print("🔧 Fetching app configuration...")
            
            let response: ConfigurationResponse = try await networkManager.fetch(endpoint)
            
            if response.success {
                configuration = response.data
                print("✅ Configuration fetched successfully: incidentToggle = \(response.data?.incidentToggle ?? false)")
            } else {
                errorMessage = "Failed to fetch configuration"
                print("❌ Configuration fetch failed")
            }
        } catch {
            errorMessage = "Failed to fetch configuration: \(error.localizedDescription)"
            print("❌ Configuration fetch error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    var isIncidentEnabled: Bool {
        return configuration?.incidentToggle ?? false
    }
    
    var drainageDeleteTimeLimit: Int? {
        return configuration?.drainageDelete
    }
}
