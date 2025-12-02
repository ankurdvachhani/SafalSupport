import Foundation
import UIKit

//// MARK: - Verification Models
//struct CodeSendVerificatonRequest: Codable {
//    let type: String
//    let value: String
//    let userCheck: Bool?
//
//    enum CodingKeys: String, CodingKey {
//        case type
//        case value
//        case userCheck
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(type, forKey: .type)
//        try container.encode(value, forKey: .value)
//        try container.encode(userCheck, forKey: .userCheck)
//    }
//}
//
//struct CodeVerificatonRequest: Codable {
//    let otp: String
//    let verifyId: String
//    let value: String
//
//    enum CodingKeys: String, CodingKey {
//        case otp
//        case verifyId
//        case value
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(otp, forKey: .otp)
//        try container.encode(verifyId, forKey: .verifyId)
//        try container.encode(value, forKey: .value)
//    }
//}

// MARK: - Profile Response Models
struct ProfiledResponse: Codable {
    let success: Bool
    let data: UserModel
}

// MARK: - Two-Factor Authentication Models
struct TwoFactorAuthRequest: Codable {
    let auth2faEmail: String
    let auth2faPhoneNumber: String
    let auth2faEmailVerifiedId: String
    let auth2faPhoneNumberVerifiedId: String
    let auth2faBackup: Bool
}

struct TwoFactorAuthResponse: Codable {
    let success: Bool
    let data: TwoFactorAuthData?
    let errors: [String]?
    let timestamp: String?
    let message: String?
}

struct TwoFactorAuthData: Codable {
    let auth2faBackupPassword: [String]?
}


protocol ProfileServicing {
    func fetchProfile() async throws -> UserModel
    func updateProfile(firstName: String, lastName: String, email: String, phoneNumber: String, country: String, profilePicture: String, phoneNumberVerifyId: String?, emailVerifyId: String?, ncpiNumber: String?) async throws -> Bool
    func uploadImage(_ image: UIImage) async throws -> String?
    func sendCodeForVerification(type: String, value: String, phoneNumber: String, isSendRequest: Bool) async throws -> VerificationResponse
    func TwoFAsendCodeForVerification(type: String, value: String, phoneNumber: String, isSendRequest: Bool) async throws -> VerificationResponse
    func deleteAccount(password: String) async throws -> Bool
    func updateTwoFactorAuthentication(enabled: Bool) async throws -> Bool
    func updateTwoFactorAuthentication(request: TwoFactorAuthRequest) async throws -> (Bool, [String]?)
}

actor ProfileService: ProfileServicing {
    func deleteAccount(password: String) async throws -> Bool {
        let endpoint = Endpoint(path: APIConfig.Path.deleteAccount)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        var bodyData:[String:Any] = [:]
        if let token = UserDefaults.standard.string(forKey: "fcmToken") {
             bodyData = ["password": password,"fcm": token] as! [String: Any]
        }else{
            bodyData = ["password": password] as! [String: Any]
        }
       
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
        } catch {
            throw NetworkError.apiError("invalid Password")
        }
        
        let response: EmptyResponse = try await networkManager.fetch(endpoint, urlRequest: request)
        return response.success
    }
    
  
    
    private let networkManager: NetworkManaging
    private let folderName = "profile"
    
    init(networkManager: NetworkManaging = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    func fetchProfile() async throws -> UserModel {
        let endpoint = Endpoint(path: APIConfig.Path.userProfile)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        let response: ProfiledResponse = try await networkManager.fetch(endpoint, urlRequest: request)
        // Store user data
        let user: UserModel = response.data
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
        }
        return response.data
    }
    
    func uploadImage(_ image: UIImage) async throws -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.4) else {
            throw NetworkError.invalidData
        }
        
        // Get image details
        let imageSize = Int64(imageData.count)
        let timestamp = Int(Date().timeIntervalSince1970)
        let uniqueFileName = "image_\(timestamp).jpg"
        
        print("Preparing to upload image: \(uniqueFileName) with size: \(imageSize)")
        
        // 1. Get upload URL with correct file information
        let fileInfo = FileInfo(
            name: uniqueFileName,
            type: "image/jpeg",
            size: imageSize
        )
        
        let uploadRequest = UploadUrlRequest(
            files: [fileInfo],
            folderName: folderName
        )
        
        // Get upload URL using NetworkManager
        let uploadUrlResponse = try await networkManager.getUploadUrls(request: uploadRequest)
        guard let uploadUrl = uploadUrlResponse.data.first else {
            throw NetworkError.invalidResponse
        }
        
        print("Got signed URL for upload: \(uploadUrl.signedUrl)")
        
        // 2. Upload image using NetworkManager
        try await networkManager.uploadFile(
            url: uploadUrl.signedUrl,
            data: imageData,
            contentType: "image/jpeg"
        )
        
        print("Image upload completed successfully")
        let components = URLComponents(string: uploadUrl.signedUrl)
        
        return components?.path ?? ""
    }
    
    func updateProfile(firstName: String, lastName: String, email: String, phoneNumber: String, country: String, profilePicture: String, phoneNumberVerifyId: String?, emailVerifyId: String?, ncpiNumber: String?) async throws -> Bool {
        // First fetch current profile to compare email
        let currentProfile = try await fetchProfile()
        
        guard let userId = TokenManager.shared.getUserId() else {
            throw NetworkError.unauthorized
        }
        
        let endpoint = Endpoint(path: "\(APIConfig.Path.userUpdate)")
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        // Create mutable dictionary for body data
        var bodyData: [String: Any] = [:]
        
        // Only add non-empty values
        if !firstName.isEmpty {
            bodyData["firstName"] = firstName
        }
        
        if !lastName.isEmpty {
            bodyData["lastName"] = lastName
        }
        
        // Only add email if it's different from current profile
        if !email.isEmpty && email != currentProfile.email {
            bodyData["email"] = email
            // Add emailVerifyId if provided when email is changed
            if let verifyId = emailVerifyId {
                bodyData["emailVerifyId"] = verifyId
            }
        }
        
        if !country.isEmpty {
            bodyData["country"] = country
        }
        
        // Add phone number only if it's not empty and not just "+"
        if !phoneNumber.isEmpty && phoneNumber != "+" {
            let formattedPhoneNumber = phoneNumber.starts(with: "+") ? phoneNumber : "\(phoneNumber)"
            bodyData["phoneNumber"] = formattedPhoneNumber
        }else{
            if !country.isEmpty {
               // bodyData["phoneNumber"] = ""
            }
        }
        
        // Add profilePicture if available
        if !profilePicture.isEmpty {
            bodyData["profilePicture"] = profilePicture
        }
        
        // Add phoneNumberVerifyId if provided
        if let verifyId = phoneNumberVerifyId {
            bodyData["phoneNumberVerifyId"] = verifyId
        }
        
        // Add NCPI Number if provided and not empty
        if let ncpiNumber = ncpiNumber, !ncpiNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
           let ncpiNumber = ncpiNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let ncpiDict:[String:String] = ["ncpiNumber":ncpiNumber,"organizationId":TokenManager.shared.loadCurrentUser()?.metadata?.organizationId ?? ""]
            bodyData["metadata"] = ncpiDict
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
        } catch {
            throw NetworkError.invalidResponse
        }
        
        let response: UserUpdateResponse = try await networkManager.fetch(endpoint, urlRequest: request)
        return response.success // Return true if we have a non-empty ID
    }
    
    func TwoFAsendCodeForVerification(type: String, value: String, phoneNumber: String, isSendRequest: Bool) async throws -> VerificationResponse {
        // Use the same endpoint as NetworkManager for consistency
        guard let url = URL(string: APIConfig.authModuleURLString + APIConfig.Path.codeVerification) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = isSendRequest ? "POST" : "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        if isSendRequest {
            let resetRequest = CodeSendVerificatonRequest(type: type, value: value, userCheck: false)
            request.httpBody = try? JSONEncoder().encode(resetRequest)
        } else {
            let resetRequest = CodeVerificatonRequest(otp: type, verifyId: value, value: phoneNumber)
            request.httpBody = try? JSONEncoder().encode(resetRequest)
        }
        
        return try await networkManager.fetch(Endpoint(path: ""), urlRequest: request)
    }
    func sendCodeForVerification(type: String, value: String, phoneNumber: String, isSendRequest: Bool) async throws -> VerificationResponse {
        // Use the same endpoint as NetworkManager for consistency
        guard let url = URL(string: APIConfig.authModuleURLString + APIConfig.Path.codeVerification) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = isSendRequest ? "POST" : "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        if isSendRequest {
            let resetRequest = CodeSendVerificatonRequest(type: type, value: value, userCheck: true)
            request.httpBody = try? JSONEncoder().encode(resetRequest)
        } else {
            let resetRequest = CodeVerificatonRequest(otp: type, verifyId: value, value: phoneNumber)
            request.httpBody = try? JSONEncoder().encode(resetRequest)
        }
        
        return try await networkManager.fetch(Endpoint(path: ""), urlRequest: request)
    }
    
    func updateTwoFactorAuthentication(enabled: Bool) async throws -> Bool {
        let endpoint = Endpoint(path: "/api/user/two-factor-auth")
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        let bodyData = ["enabled": enabled] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
        } catch {
            throw NetworkError.apiError("Invalid request data")
        }
        
        let response: UserUpdateResponse = try await networkManager.fetch(endpoint, urlRequest: request)
        return response.success
    }
    
    func updateTwoFactorAuthentication(request: TwoFactorAuthRequest) async throws -> (Bool, [String]?) {
        let endpoint = Endpoint(path: APIConfig.Path.userUpdate)
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        urlRequest.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: APIConfig.Header.cookie)
        
        let bodyData: [String: Any] = [
            "auth2faEmail": request.auth2faEmail,
            "auth2faPhoneNumber": request.auth2faPhoneNumber,
            "auth2faEmailVerifiedId": request.auth2faEmailVerifiedId,
            "auth2faPhoneNumberVerifiedId": request.auth2faPhoneNumberVerifiedId,
            "auth2faBackup": request.auth2faBackup
        ]
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
        } catch {
            throw NetworkError.apiError("Invalid request data")
        }
        
        let response: TwoFactorAuthResponse = try await networkManager.fetch(endpoint, urlRequest: urlRequest)
        
        // Extract backup codes from the data object
        let backupCodes = response.data?.auth2faBackupPassword
        
        return (response.success, backupCodes)
    }
}

struct UserUpdateResponse: Codable {
    let success: Bool
   
    enum CodingKeys: String, CodingKey {
        case success
        
    }
}


extension NetworkError {
    static let uploadFailed = NetworkError.apiError("Failed to upload image")
    static let invalidData = NetworkError.apiError("Failed to upload image")
}
