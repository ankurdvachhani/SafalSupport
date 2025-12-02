import Foundation

struct LoginCredentials {
    var email: String
    var password: String
    var isOrganization: Bool
    var rememberMe: Bool
}

struct AuthenticationError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return message
    }
}

enum AuthenticationState: Equatable {
    case authenticated
    case unauthenticated
    case error(Error)
    
    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.authenticated, .authenticated):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Multiple Account Models
struct MultipleAccountResponse: Codable {
    let success: Bool
    let data: UserModel?
    let errors: [String]?
    let multipleAccount: Bool?
    let timestamp: String?
    let message: String
    let accounts: [AccountInfo]?
}

struct AccountInfo: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let role: String
    let country: String
    let userSlug: String
    let metadata: AccountMetadata?
    let organizationName: String?
    let email: String
    let displayString: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, role, country, userSlug, metadata, organizationName, email, displayString
    }
}

struct AccountMetadata: Codable {
    let organizationId: String
    let ncpiNumber: String
} 
