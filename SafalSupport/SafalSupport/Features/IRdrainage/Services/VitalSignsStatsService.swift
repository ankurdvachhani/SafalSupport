import Foundation

// MARK: - Vital Signs Stats Service

@MainActor
class VitalSignsStatsService: ObservableObject {
    @Published var stats: VitalSignsStatsData?
    @Published var filter: VitalSignsFilter?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager()
    
    func fetchVitalSignsStats(
        duration: VitalSignsDuration,
        patientId: String? = nil,
        incidentId: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "duration", value: duration.rawValue),
                URLQueryItem(name: "tz", value: TimeZone.current.identifier)
            ]
            
            if let patientId = patientId {
                queryItems.append(URLQueryItem(name: "patientId", value: patientId))
            }
            
            if let incidentId = incidentId {
                queryItems.append(URLQueryItem(name: "incident", value: incidentId))
            }
            
            let endpoint = Endpoint(
                path: "/api/dashboard/vital-signs-stats",
                method: .get,
                queryItems: queryItems
            )
            
            print("📊 Fetching vital signs stats with duration: \(duration.rawValue), patientId: \(patientId ?? "nil"), incidentId: \(incidentId ?? "nil")")
            
            let response: VitalSignsStatsResponse = try await networkManager.fetch(endpoint)
            
            if response.success {
                self.stats = response.data
                self.filter = response.filter
                print("✅ Vital signs stats loaded successfully")
                print("📅 Filter: \(response.filter)")
            } else {
                self.errorMessage = response.message
                print("❌ Failed to load vital signs stats: \(response.message)")
            }
            
        } catch {
            self.errorMessage = "Failed to load vital signs stats: \(error.localizedDescription)"
            print("❌ Error fetching vital signs stats: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}
