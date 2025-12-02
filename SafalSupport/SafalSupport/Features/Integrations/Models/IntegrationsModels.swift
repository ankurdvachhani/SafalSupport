import Foundation

// MARK: - Epic MyChart Response Models
struct EpicMyChartResponse: Codable {
    let success: Bool
    let message: String
    let data: EpicMyChartUser
}

struct EpicMyChartUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let country: String
    let profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, email, role, country, profilePicture
    }
}

// MARK: - SafalCalendar Response Models
struct SafalCalendarResponse: Codable {
    let success: Bool
    let message: String
    let data: SafalCalendarUser
}

struct SafalCalendarUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let country: String
    let profilePicture: String?
   
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, email, role, country
        case profilePicture
    }
}


// MARK: - User Extra Data Response Models
struct UserExtraResponse: Codable {
    let success: Bool
    let data: UserExtraData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct UserExtraData: Codable {
    let id: String
    let userId: String
    let version: Int
    let createdAt: String
    let lastActive: String
    let updatedAt: String
    let epicMyChart: EpicMyChartUserExtra?
    let safalCalendar: SafalCalendarUserExtra?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, version = "__v"
        case createdAt, lastActive, updatedAt
        case epicMyChart, safalCalendar
    }
}

// MARK: - User Extra Data User Models
struct SafalCalendarUserExtra: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, role, profilePicture
    }
}

struct EpicMyChartUserExtra: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let profilePicture: String?
    
    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, role, profilePicture
    }
}

struct IntegrationItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    var icon: String
    var status: String
    var isConnected: Bool
    var connectedUser: String?
    
    static func == (lhs: IntegrationItem, rhs: IntegrationItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.isConnected == rhs.isConnected &&
        lhs.connectedUser == rhs.connectedUser &&
        lhs.status == rhs.status
    }
    
    init(title: String, 
         description: String, 
         icon: String = "", 
         status: String = "Active",
         isConnected: Bool = false,
         connectedUser: String? = nil) {
        self.title = title
        self.description = description
        self.icon = icon
        self.status = status
        self.isConnected = isConnected
        self.connectedUser = connectedUser
    }
}

struct IntegrationLoginRequest: Codable {
    let email: String
    let password: String
}

struct IntegrationLoginSafalUtilitiesRequest: Codable {
    let email: String
    let password: String
}

struct IntegrationLoginSafalIRDrainMateRequest: Codable {
    let email: String
    let password: String
}


struct IntegrationDisconnectRequest: Codable {
    let type: String
}

struct IntegrationError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
    
    static let invalidCredentials = IntegrationError(message: "Invalid credentials")
    static let connectionFailed = IntegrationError(message: "Invalid credentials")
    static let disconnectFailed = IntegrationError(message: "Invalid credentials")
}

