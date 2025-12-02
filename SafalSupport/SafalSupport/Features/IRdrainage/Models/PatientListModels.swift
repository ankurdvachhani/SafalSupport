import Foundation
import SwiftUI

// MARK: - Priority Enum
enum Priority: String, CaseIterable, Codable {
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"
    case p4 = "P4"
    case p5 = "P5"
    case none = "None"
    
    var color: String {
        switch self {
        case .p1: return "#ef4444"
        case .p2: return "#f97316"
        case .p3: return "#eab308"
        case .p4: return "#0ea5e9"
        case .p5: return "#22c55e"
        case .none: return "#6b7280"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var swiftUIColor: Color {
        switch self {
        case .p1: return Color(hex: "#ef4444")
        case .p2: return Color(hex: "#f97316")
        case .p3: return Color(hex: "#eab308")
        case .p4: return Color(hex: "#0ea5e9")
        case .p5: return Color(hex: "#22c55e")
        case .none: return Color(hex: "#6b7280")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        if let priority = Priority.allCases.first(where: { $0.rawValue == rawValue }) {
            self = priority
        } else {
            self = .none
        }
    }
}

struct PatientListResponse: Codable {
    let success: Bool
    let data: [PatientData]
    let sort: SortInfo
    let pagination: PaginationInfo
    let errors: [String]
    let timestamp: String
    let message: String
}

struct PatientData: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let dob:String?
    let role: String
    let userSlug: String
    let metadata: PatientMetadata
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, role, userSlug, metadata, email, dob
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var priority: Priority {
        return metadata.priority ?? .none
    }
}

struct PatientMetadata: Codable, Equatable {
    let organizationId: String?
    let priority: Priority?
    let ncpiNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case organizationId, priority, ncpiNumber
    }
    
    init(organizationId: String, priority: Priority? = nil, ncpiNumber: String? = nil) {
        self.organizationId = organizationId
        self.priority = priority
        self.ncpiNumber = ncpiNumber
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        organizationId = try container.decode(String.self, forKey: .organizationId)
        ncpiNumber = try container.decodeIfPresent(String.self, forKey: .ncpiNumber)
        
        // Handle priority decoding
        if let priorityString = try container.decodeIfPresent(String.self, forKey: .priority) {
            priority = Priority(rawValue: priorityString) ?? .none
        } else {
            priority = .none
        }
    }
}
