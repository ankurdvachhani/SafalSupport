import Foundation
import SwiftUI

// MARK: - Color Configuration
struct ColorConfig: Codable {
    let primaryColor: String
    let secondaryColor: String
    let accentColor: String
    let backgroundColor: String
    let textColor: String
    
    enum CodingKeys: String, CodingKey {
        case primaryColor = "primary_color"
        case secondaryColor = "secondary_color"
        case accentColor = "accent_color"
        case backgroundColor = "background_color"
        case textColor = "text_color"
    }
}

// MARK: - App Configuration
struct AppConfiguration: Codable {
    let id: String
    let incidentToggle: Bool
    let organizationId: String
    let drainageDelete:Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case incidentToggle
        case organizationId
        case drainageDelete
    }
}

struct ConfigurationResponse: Codable {
    let success: Bool
    let data: AppConfiguration?
    let errors: [String]?
    let timestamp: String?
    let message: String?
}

// Extension to handle UserDefaults storage
extension ColorConfig {
    static let userDefaultsKey = "stored_color_config"
    
    static func save(_ config: ColorConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    static func load() -> ColorConfig? {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let config = try? JSONDecoder().decode(ColorConfig.self, from: data) {
            return config
        }
        return nil
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
} 
