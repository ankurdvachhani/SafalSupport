import Foundation

struct VersionCheckResponse: Codable {
    let success: Bool
    let status: String
    let version: String
}

enum UpdateStatus: String {
    case force
    case normal
    case none
    
    static func from(_ status: String) -> UpdateStatus {
        return UpdateStatus(rawValue: status.lowercased()) ?? .none
    }
}

