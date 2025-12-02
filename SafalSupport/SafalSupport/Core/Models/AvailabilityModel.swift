import Foundation

struct AvailabilityResponse: Codable {
    let success: Bool
    let data: AvailabilityData
}

struct AvailabilityData: Codable {
    let id: String
    let userId: String
    let type: String
    let availableArray: [AvailabilityItem]
    let createdAt: String
    let updatedAt: String
    let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case type
        case availableArray
        case createdAt
        case updatedAt
        case timezone
    }
}

struct AvailabilityItem: Codable {
    let startTime: String
    let endTime: String
    let name: String
    let unavailable: Bool
}

struct AvailabilityRequest: Codable {
    let type: String
    let availableArray: [AvailabilityItem]
    let timezone: String
} 
