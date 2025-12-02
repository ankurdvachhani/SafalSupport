import Foundation

struct UserModel: Codable {
    let id: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let role: String?
    let country: String?
    let profilePicture: String?
    let isEmailVerified: Bool?
    let createdAt: String?
    let updatedAt: String?
    let phoneNumber: String?
    let message: String?
    let success: Bool?
    let statusCode: Int?
    let error: String?
    let isPhoneVerified:Bool? = true
    let emailVerifiedId: String?
    let userSlug: String?
    let companySlug:String?
    let status:String?
    let metadata:GetUserModelMetadata?
    let profilePictureSign:String?
    let isTwoFactorEnabled:Bool?
    let auth2faEmail: String?
    let auth2faPhoneNumber: String?
    let auth2faBackupPassword: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, email, role, country
        case profilePicture, isEmailVerified, createdAt, updatedAt
        case phoneNumber,emailVerifiedId,userSlug,companySlug,metadata
        case message, success, statusCode, error,status,profilePictureSign
        case isTwoFactorEnabled, auth2faEmail, auth2faPhoneNumber, auth2faBackupPassword
    }
}


struct AuthenticationResponse: Codable {
    let data: UserModel?
    let error: String?
    let message:String?
    let success:Bool?
}

struct SignInRequest: Codable {
    let email: String
    let password: String
    let userId: String?
    
    init(email: String, password: String, userId: String? = nil) {
        self.email = email
        self.password = password
        self.userId = userId
    }
}

struct OrganizationData: Codable {
    let id: String
    let firstName: String
    let email: String
    let role: String
    let country: String
    let companySlug: String
    let profilePicture: String?
    let isEmailVerified: Bool
    let applications: [String]
    let registeredOn: String
    let status: String
    let companyIds: [String]
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, email, role, country
        case companySlug, profilePicture, isEmailVerified
        case applications, registeredOn, status, companyIds
        case createdAt, updatedAt
    }
} 
