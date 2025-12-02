import Foundation

struct ResetPasswordRequest: Codable {
    let email: String
    let verifyId: String
    let otp: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email
        case verifyId
        case otp
        case newPassword
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(verifyId, forKey: .verifyId)
        try container.encode(otp, forKey: .otp)
        try container.encode(newPassword, forKey: .newPassword)
    }
}

struct CodeVerificatonRequest: Codable {
    let otp: String
    let verifyId: String
    let value:String

    enum CodingKeys: String, CodingKey {
        case otp
        case verifyId
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(otp, forKey: .otp)
        try container.encode(verifyId, forKey: .verifyId)
        try container.encode(value, forKey: .value)
    }
}

struct CodeSendVerificatonRequest: Codable {
    let type: String
    let value: String
    let userCheck: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case value
        case userCheck
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(userCheck, forKey: .userCheck)
    }
}

struct ResetPasswordResponse: Codable {
    let message: String?
    let success: Bool?
    let statusCode: Int?
    let verifyId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case success
        case statusCode
        case verifyId
    }
}

struct VerificationResponse: Codable {
    let message: String?
    let success: Bool?
    let statusCode: Int?
    let verifyId: String?
    let otp: Int?

    enum CodingKeys: String, CodingKey {
        case message
        case success
        case statusCode
        case verifyId
        case otp
    }
}
struct UtilitiesResponse: Codable {
    let data: UtilitiesDataClass
}

// MARK: - DataClass
struct UtilitiesDataClass: Codable {
    let id, type, name, version: String?
    let content: String?
    let pdfLink: String?
    let startDate, endDate: String?
    let application: Application?
}

// MARK: - Application
struct Application: Codable {
    let id, name, description, appCode: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name, description, appCode, status
    }
}

struct mainResponse: Codable {
    let message: String?
    let success: Bool?
    let statusCode: Int?

    enum CodingKeys: String, CodingKey {
        case message
        case success
        case statusCode
    }
}

enum ResetPasswordError: LocalizedError {
    case userNotFound
    case invalidEmail
    case networkError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidEmail:
            return "Please enter a valid email address"
        case let .networkError(message):
            return message
        case let .unknown(message):
            return message
        }
    }
}
