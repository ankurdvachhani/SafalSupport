import Foundation

// MARK: - Individual User Signup
struct UserSignUpRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
    let confirmPassword: String
    let country: String
    let termAndConditionsId: String
    let privacyPolicyId: String
    let phoneNumber: String?
    let phoneNumberVerifyId: String?
    let emailVerifiedId: String?
    let role: String?
    let metadata:[String:String]?
}

// MARK: - Organization Signup
struct OrganizationSignUpRequest: Codable {
    let firstName: String
    let email: String
    let password: String
    let country: String
    let phoneNumber: String?
    let termAndConditionsId: String
    let privacyPolicyId: String
    let phoneNumberVerifyId: String?
}

// MARK: - Signup Response
struct SignUpResponse: Codable {
    let message: String?
    let success: Bool?
    let statusCode: Int?
    let error: String?
    let data : SignUpData?
}
struct SignUpData: Codable {
    let userSlug:String?
    let role:String?
    
}

// MARK: - Validation Errors
struct SignUpValidationError {
    var firstName: String?
    var lastName: String?
    var email: String?
    var password: String?
    var confirmPassword: String?
    var country: String?
    var termsAndConditions: String?
    var privacyPolicy: String?
    var phoneNumber: String?
    
    var hasErrors: Bool {
        return [firstName, lastName, email, password, confirmPassword, country, termsAndConditions, privacyPolicy, phoneNumber].contains { $0 != nil }
    }
}

// MARK: - Constants
enum SignUpConstants {
    static let termsAndConditionsId = "683e0c2c8f68b2357e90cf2b"
    static let privacyPolicyId = "683e0c0a8f68b2357e90cf11"
}

// MARK: - Phone Verification
struct PhoneVerificationRequest: Codable {
    let phoneNumber: String
}

struct PhoneVerificationResponse: Codable {
    let message: String?
    let success: Bool?
    let error: String?
}

struct VerifyOTPRequest: Codable {
    let phoneNumber: String
    let otp: String
}

struct VerifyOTPResponse: Codable {
    let message: String?
    let success: Bool?
    let error: String?
} 
