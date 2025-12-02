import Foundation

// MARK: - Drainage Type Configuration Model

struct DrainageTypeConfig: Codable, Identifiable {
    let id = UUID()
    let type: String
    let minAmount: Int
    let maxAmount: Int
    let avgAmount: Int
    let priority: String
    let notification: [NotificationRule]?
    let field: [DrainageFieldConfig]?
    
    enum CodingKeys: String, CodingKey {
        case type, minAmount, maxAmount, avgAmount, priority, notification, field
    }
}

// MARK: - Drainage Field Configuration Model

struct DrainageFieldConfig: Codable, Identifiable {
    let id = UUID()
    let fieldKey: String
    let value: FieldConfigValue
    let isDefault: Bool
    let isHidden: Bool
    let isRequired: Bool
    let notification: [NotificationRule]?
    
    enum CodingKeys: String, CodingKey {
        case fieldKey, value, notification
        case isDefault = "default"
        case isHidden = "hidden"
        case isRequired = "required"
    }
}

// MARK: - API Configuration Response Model

struct ConfigResponse: Codable {
    let data: ConfigData
    let success: Bool
    let errors: [String]
    let timestamp: String
    let message: String
}

struct ConfigData: Codable {
    let id: String
    let incidentToggle: Bool
    let autoLogout: Int
    let drainageType: [DrainageTypeConfig]
    let organizationId: String
    let version: Int
    let drainageDelete: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case incidentToggle, autoLogout, drainageType, organizationId
        case version = "__v"
        case drainageDelete
    }
}

// MARK: - Drainage Configuration Service

class DrainageConfigurationService: ObservableObject {
    static let shared = DrainageConfigurationService()
    
    @Published var configData: ConfigData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager()
    
    private init() {}
    
    func fetchConfiguration() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        do {
            let endpoint = Endpoint(
                path: APIConfig.Path.configuration,
                method: .get
            )
            let response: ConfigResponse = try await networkManager.fetch(endpoint)
            
            await MainActor.run {
                self.configData = response.data
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func getDrainageTypeConfig(for type: String) -> DrainageTypeConfig? {
        return configData?.drainageType.first { $0.type == type }
    }
    
    func getNotifications(for drainageType: String, patientAge: Int? = nil) -> [NotificationRule] {
        guard let config = getDrainageTypeConfig(for: drainageType) else { return [] }
        
        var allNotifications: [NotificationRule] = []
        
        // Add general notifications (from drainage type level)
        if let generalNotifications = config.notification {
            allNotifications.append(contentsOf: generalNotifications)
        }
        
        // Add field-specific notifications with age filtering
        if let fields = config.field {
            for field in fields {
                if let fieldNotifications = field.notification {
                    let filteredNotifications = filterNotificationsByAge(fieldNotifications, patientAge: patientAge)
                    allNotifications.append(contentsOf: filteredNotifications)
                }
            }
        }
        
        return allNotifications
    }
    
    func getFieldConfigs(for drainageType: String) -> [FieldConfig] {
        guard let config = getDrainageTypeConfig(for: drainageType) else { return [] }
        
        // Convert DrainageFieldConfig to FieldConfig
        return config.field?.map { drainageField in
            FieldConfig(
                fieldKey: drainageField.fieldKey,
                value: drainageField.value,
                isDefault: drainageField.isDefault,
                isHidden: drainageField.isHidden,
                isRequired: drainageField.isRequired
            )
        } ?? []
    }
    
    private func filterNotificationsByAge(_ notifications: [NotificationRule], patientAge: Int?) -> [NotificationRule] {
        guard let age = patientAge else { 
            // If no patient age available, return all notifications (no age filtering)
            return notifications 
        }

        return notifications.filter { notification in
            // If both ageMin and ageMax exist → check range
            if let ageMin = notification.ageMin, let ageMax = notification.ageMax {
                return age >= ageMin && age <= ageMax
            }
            // If only ageMin exists → age must be >= ageMin
            else if let ageMin = notification.ageMin {
                return age >= ageMin
            }
            // If only ageMax exists → age must be <= ageMax
            else if let ageMax = notification.ageMax {
                return age <= ageMax
            }
            // If both missing → no age restriction, include the notification
            else {
                return true
            }
        }
    }
    
    func getPatientAge(from dob: String) -> Int? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        guard let birthDate = dateFormatter.date(from: dob) else { return nil }
        
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: birthDate, to: Date()).year
        return age
    }
    
}
