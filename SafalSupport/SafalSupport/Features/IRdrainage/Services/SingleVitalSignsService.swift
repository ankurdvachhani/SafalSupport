import Foundation

// MARK: - Single Vital Signs Service

@MainActor
class SingleVitalSignsService: ObservableObject {
    @Published var data: [SingleVitalSignData] = []
    @Published var filter: SingleVitalSignsFilter?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager()
    
    func fetchSingleVitalSigns(
        vitalType: VitalSignType,
        duration: VitalSignsDuration,
        patientId: String? = nil,
        incidentId: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "vitalType", value: vitalType.rawValue),
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
                path: "/api/dashboard/single-vital-signs",
                method: .get,
                queryItems: queryItems
            )
            
            print("📊 Fetching single vital signs for \(vitalType.displayName) with duration: \(duration.rawValue), patientId: \(patientId ?? "nil"), incidentId: \(incidentId ?? "nil")")
            
            let response: SingleVitalSignsResponse = try await networkManager.fetch(endpoint)
            
            if response.success {
                self.data = response.data
                self.filter = response.filter
                print("✅ Single vital signs loaded successfully: \(response.data.count) data points")
                print("📅 Filter: \(response.filter)")
            } else {
                self.errorMessage = response.message
                print("❌ Failed to load single vital signs: \(response.message)")
            }
            
        } catch {
            self.errorMessage = "Failed to load single vital signs: \(error.localizedDescription)"
            print("❌ Error fetching single vital signs: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}
