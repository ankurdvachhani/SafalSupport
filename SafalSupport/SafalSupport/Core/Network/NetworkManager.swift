import Foundation
import Network

// Add EmptyResponse at the top level
struct EmptyResponse: Codable {
    let success: Bool
    let message: String?
}

// Add FCM Token Request Model at the top level
struct FCMTokenRequest: Codable {
    let token: String
}

// Add 2FA Login Request Model
struct LoginWith2FARequest: Codable {
    let email: String
    let password: String
    let type2fa: String
    let type2faVerifiedId: String
    let userId: String?
    let tz: String?
    init(email: String, password: String, type2fa: String, type2faVerifiedId: String, userId: String? = nil,tz: String? = nil) {
        self.email = email
        self.password = password
        self.type2fa = type2fa
        self.type2faVerifiedId = type2faVerifiedId
        self.userId = userId
        self.tz = tz
    }
}

// Add these models at the top level, after the FCMTokenRequest

struct UploadUrlResponse: Codable {
    let success: Bool
    let data: [UploadUrlData]
    let errors: [String]
    let timestamp: String
    let message: String
}

struct UploadUrlData: Codable {
    let url: String
    let signedUrl: String
    let fileName: String
}

struct UploadUrlRequest: Codable {
    let files: [FileInfo]
    let folderName: String
}

struct FileInfo: Codable {
    let name: String
    let type: String
    let size: Int64
}

// Contact Message Models
struct ContactMessageRequest: Codable {
    let type: String
    let email: String
    let message: String
    let firstName: String
    let lastName: String
    let applicationSlug: String
    let companySlug: String
}

struct ContactMessageResponse: Codable {
    let message: String
    let success: Bool
    let data: ContactMessageData
}

struct ContactMessageData: Codable {
    let type: String
    let email: String
    let message: String
    let application: String
    let companySlug: String
    let id: String
    let createdAt: String
    let updatedAt: String
    let v: Int
    
    enum CodingKeys: String, CodingKey {
        case type, email, message, application, companySlug
        case id = "_id"
        case createdAt, updatedAt
        case v = "__v"
    }
}

protocol NetworkManaging {
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func signIn(email: String, password: String,tz:String) async throws -> UserModel
    func signInWithMultipleAccountCheck(email: String, password: String,tz:String) async throws -> MultipleAccountResponse
    func signInWithUserId(email: String, password: String, userId: String,tz:String) async throws -> UserModel
    func signInOrganization(email: String, password: String) async throws -> UserModel
    func loginWith2FA(request: LoginWith2FARequest) async throws -> UserModel
    func signUp(request: UserSignUpRequest,id:String?,orgId:String?) async throws -> SignUpResponse
    func signUpOrganization(request: OrganizationSignUpRequest) async throws -> SignUpResponse
    func resetPassword(email: String, verifyId: String?, otp: String?, newPassword: String?,isupdate:Bool) async throws -> ResetPasswordResponse
    func sendCodeForVerification(isForgotPassword: Bool,type: String, value: String,phoneNumber:String?, isSendRequest:Bool) async throws ->  VerificationResponse
    func TwoFAsendCodeForVerification(isForgotPassword: Bool,type: String, value: String,phoneNumber:String?, isSendRequest:Bool) async throws ->  VerificationResponse
    func fetchPolicyData(type: String,application:String) async throws -> UtilitiesResponse
    func getUploadUrls(request: UploadUrlRequest) async throws -> UploadUrlResponse
    func uploadFile(url: String, data: Data, contentType: String) async throws
    func fetch<T: Decodable>(_ endpoint: Endpoint, urlRequest: URLRequest) async throws -> T
    func registerFCMToken(_ token: String) async throws -> EmptyResponse
    func deleteFCMToken(_ token: String) async throws -> EmptyResponse
    func sendContactMessage(email: String, message: String, firstName: String, lastName: String) async throws -> ContactMessageResponse
}

actor NetworkManager: NetworkManaging {
    
    
    private let session: URLSession
    private let monitor: NWPathMonitor
    private var hasInternet: Bool = true
    private let monitorQueue = DispatchQueue(label: "com.safalcalendar.network.monitor")
    
    init(session: URLSession = .shared) {
        self.session = session
        self.monitor = NWPathMonitor()
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task {
                await self.updateConnectionStatus(path.status == .satisfied)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func updateConnectionStatus(_ isConnected: Bool) {
        hasInternet = isConnected
    }
    
    private func addAuthorizationHeader(_ request: inout URLRequest) {
        if let token = TokenManager.shared.getToken() {
            let cookieValue = "access_token=\(token)"
            request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        }
    }
    
    func signIn(email: String, password: String,tz:String) async throws -> UserModel {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.signIn) else {
            throw NetworkError.invalidURL
        }
        
        let signInRequest = SignInRequest(email: email, password: password)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.httpBody = try? JSONEncoder().encode(signInRequest)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Extract access token from cookies
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let url = request.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                if let tokenCookie = cookies.first(where: { $0.name == "access_token" }) {
                    TokenManager.shared.saveToken(tokenCookie.value)
                }
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let resetResponse = try decoder.decode(AuthenticationResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return resetResponse.data ?? UserModel(
                    id: nil, firstName: nil, lastName: nil, email: nil, role: nil, country: nil,
                    profilePicture: nil, isEmailVerified: nil, createdAt: nil, updatedAt: nil,
                    phoneNumber: nil, message: nil, success: nil, statusCode: nil, error: nil,
                    emailVerifiedId: nil, userSlug: nil, companySlug: nil, status: nil, metadata: nil, profilePictureSign: nil, isTwoFactorEnabled: nil,auth2faEmail: nil,auth2faPhoneNumber: nil,auth2faBackupPassword: nil
                )
            case 404:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 400...499:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func signInWithMultipleAccountCheck(email: String, password: String,tz:String) async throws -> MultipleAccountResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.signIn) else {
            throw NetworkError.invalidURL
        }
        
        let signInRequest = SignInRequest(email: email, password: password)
      
        var path = APIConfig.Path.signIn
       

        // 🔁 Build the full base URL + path
        let fullURLString = APIConfig.authModuleURLString + path
        var request = URLRequest(url: URL.init(string: fullURLString)!)
        // Build components from full URL string
        guard var components = URLComponents(string: fullURLString) else {
            throw NetworkError.invalidURL
        }
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.httpBody = try? JSONEncoder().encode(signInRequest)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Extract access token from cookies
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let url = request.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                if let tokenCookie = cookies.first(where: { $0.name == "access_token" }) {
                    TokenManager.shared.saveToken(tokenCookie.value)
                }
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let multipleAccountResponse = try decoder.decode(MultipleAccountResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return multipleAccountResponse
            case 404:
                throw NetworkError.apiError(multipleAccountResponse.message)
            case 400...499:
                throw NetworkError.apiError(multipleAccountResponse.message)
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func signInWithUserId(email: String, password: String, userId: String,tz:String) async throws -> UserModel {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.signIn) else {
            throw NetworkError.invalidURL
        }
        
        let signInRequest = SignInRequest(email: email, password: password, userId: userId)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.httpBody = try? JSONEncoder().encode(signInRequest)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Extract access token from cookies
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let url = request.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                if let tokenCookie = cookies.first(where: { $0.name == "access_token" }) {
                    TokenManager.shared.saveToken(tokenCookie.value)
                }
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let resetResponse = try decoder.decode(AuthenticationResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return resetResponse.data ?? UserModel(
                    id: nil, firstName: nil, lastName: nil, email: nil, role: nil, country: nil,
                    profilePicture: nil, isEmailVerified: nil, createdAt: nil, updatedAt: nil,
                    phoneNumber: nil, message: nil, success: nil, statusCode: nil, error: nil,
                    emailVerifiedId: nil, userSlug: nil, companySlug: nil, status: nil, metadata: nil, profilePictureSign: nil, isTwoFactorEnabled: nil,auth2faEmail: nil,auth2faPhoneNumber: nil,auth2faBackupPassword: nil
                )
            case 404:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 400...499:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func signInOrganization(email: String, password: String) async throws -> UserModel {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.signInOrganization) else {
            throw NetworkError.invalidURL
        }
        
        let signInRequest = SignInRequest(email: email, password: password)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.httpBody = try? JSONEncoder().encode(signInRequest)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Extract access token from cookies
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let url = request.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                if let tokenCookie = cookies.first(where: { $0.name == "access_token" }) {
                    TokenManager.shared.saveToken(tokenCookie.value)
                }
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                do {
                    return try decoder.decode(UserModel.self, from: data)
                } catch {
                    throw NetworkError.decodingError
                }
            case 401:
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw NetworkError.apiError(errorMessage)
                }
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? "")
                }
                throw NetworkError.unauthorized
            case 500...599:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? "")
                }
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func loginWith2FA(request: LoginWith2FARequest) async throws -> UserModel {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.signIn) else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        urlRequest.httpBody = try? JSONEncoder().encode(request)
        
        // Log the request
        NetworkLogger.log(request: urlRequest)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Extract access token from cookies
            if let headerFields = httpResponse.allHeaderFields as? [String: String],
               let url = urlRequest.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                if let tokenCookie = cookies.first(where: { $0.name == "access_token" }) {
                    TokenManager.shared.saveToken(tokenCookie.value)
                }
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let authResponse = try decoder.decode(AuthenticationResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return authResponse.data ?? UserModel(
                    id: nil, firstName: nil, lastName: nil, email: nil, role: nil, country: nil,
                    profilePicture: nil, isEmailVerified: nil, createdAt: nil, updatedAt: nil,
                    phoneNumber: nil, message: nil, success: nil, statusCode: nil, error: nil,
                    emailVerifiedId: nil, userSlug: nil, companySlug: nil, status: nil, metadata: nil, profilePictureSign: nil, isTwoFactorEnabled: nil, auth2faEmail: nil, auth2faPhoneNumber: nil, auth2faBackupPassword: nil
                )
            case 404:
                throw NetworkError.apiError(authResponse.message ?? "")
            case 400...499:
                throw NetworkError.apiError(authResponse.message ?? "")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func signUp(request: UserSignUpRequest,id:String? = "",orgId:String? = "") async throws -> SignUpResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        var path = APIConfig.Path.signUp
        if let id = id, !id.isEmpty {
            path += "/\(id)"
        }

        // 🔁 Build the full base URL + path
        let fullURLString = APIConfig.authModuleURLString + path

        // Build components from full URL string
        guard var components = URLComponents(string: fullURLString) else {
            throw NetworkError.invalidURL
        }

        // Always include base query items
        components.queryItems = [
            URLQueryItem(name: "searchValue", value: orgId),
            URLQueryItem(name: "searchKey", value: "metadata.organizationId"),
            URLQueryItem(name: "applicationOnly", value: "true"),
            URLQueryItem(name: "allowMultipleEmail", value: "true")
        ]

        // Conditionally append more if role is "Organization"
        if request.role == "Organization" {
            components.queryItems! += [
                URLQueryItem(name: "uniqueCheckKey", value: "firstName")
            ]
        }
        

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        print("✅ Final URL:", url)

        var urlRequest = URLRequest(url: url)
        print(url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        urlRequest.httpBody = try? JSONEncoder().encode(request)
        
        // Log the request
        NetworkLogger.log(request: urlRequest)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let signUpResponse = try decoder.decode(SignUpResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200...201:
                return signUpResponse
            case 400...499:
                throw NetworkError.apiError(signUpResponse.error ?? signUpResponse.message ?? "Client error")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func signUpOrganization(request: OrganizationSignUpRequest) async throws -> SignUpResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.signUpOrganization) else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        urlRequest.httpBody = try? JSONEncoder().encode(request)
        
        // Log the request
        NetworkLogger.log(request: urlRequest)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let signUpResponse = try decoder.decode(SignUpResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200...201:
                return signUpResponse
            case 400...499:
                throw NetworkError.apiError(signUpResponse.error ?? signUpResponse.message ?? "Client error")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func resetPassword(email: String, verifyId: String?, otp: String?, newPassword: String?,isupdate:Bool = false) async throws -> ResetPasswordResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.authModuleURLString + APIConfig.Path.forgotPassword) else {
            throw NetworkError.invalidURL
        }
        
        let resetRequest = ResetPasswordRequest(email: email, verifyId: verifyId ?? "", otp: otp ?? "", newPassword: newPassword ?? "")
        var request = URLRequest(url: url)
        if isupdate{
            request.httpMethod = "PUT"
        }else{
            request.httpMethod = "POST"
        }
      
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        request.httpBody = try? JSONEncoder().encode(resetRequest)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let resetResponse = try decoder.decode(ResetPasswordResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return resetResponse
            case 404:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 400...499:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
   
    
    func TwoFAsendCodeForVerification(isForgotPassword: Bool = false,type: String, value: String,phoneNumber:String? = "", isSendRequest:Bool) async throws -> VerificationResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string:  APIConfig.authModuleURLString + APIConfig.Path.codeVerification) else {
            throw NetworkError.invalidURL
        }
       
        var request = URLRequest(url: url)
        request.httpMethod =  isSendRequest ? "POST" : "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        if isSendRequest{
            if isForgotPassword  {
                let resetRequest = CodeSendVerificatonRequest(type: type, value: value, userCheck: false)
                request.httpBody = try? JSONEncoder().encode(resetRequest)
            }else{
                let resetRequest = CodeSendVerificatonRequest(type: type, value: value, userCheck: false)
                request.httpBody = try? JSONEncoder().encode(resetRequest)
            }
        
        }else{
            let resetRequest = CodeVerificatonRequest(otp: type, verifyId: value, value: phoneNumber ?? "")
            request.httpBody = try? JSONEncoder().encode(resetRequest)
        }
      
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let resetResponse = try decoder.decode(VerificationResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return resetResponse
            case 404:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 400...499:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
        
    }
    
    func sendCodeForVerification(isForgotPassword: Bool = false,type: String, value: String,phoneNumber:String? = "", isSendRequest:Bool) async throws -> VerificationResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string:  APIConfig.authModuleURLString + APIConfig.Path.codeVerification) else {
            throw NetworkError.invalidURL
        }
       
        var request = URLRequest(url: url)
        request.httpMethod =  isSendRequest ? "POST" : "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        if isSendRequest{
            if isForgotPassword  {
                let resetRequest = CodeSendVerificatonRequest(type: type, value: value, userCheck: false)
                request.httpBody = try? JSONEncoder().encode(resetRequest)
            }else{
                let resetRequest = CodeSendVerificatonRequest(type: type, value: value, userCheck: false)
                request.httpBody = try? JSONEncoder().encode(resetRequest)
            }
        
        }else{
            let resetRequest = CodeVerificatonRequest(otp: type, verifyId: value, value: phoneNumber ?? "")
            request.httpBody = try? JSONEncoder().encode(resetRequest)
        }
      
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Try to decode the response regardless of status code
            let decoder = JSONDecoder()
            let resetResponse = try decoder.decode(VerificationResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return resetResponse
            case 404:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 400...499:
                throw NetworkError.apiError(resetResponse.message ?? "")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
        
    }
    
    func fetchPolicyData(type: String, application: String) async throws -> UtilitiesResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        // Construct query URL
        var components = URLComponents(string: APIConfig.utilitiesUrl + APIConfig.Path.utilities)
        components?.queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "application", value: application)
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let policyResponse = try decoder.decode(UtilitiesResponse.self, from: data)
            
            switch httpResponse.statusCode {
            case 200:
                return policyResponse
            case 400...499:
               // throw NetworkError.apiError(policyResponse.message ?? "")
                throw NetworkError.serverError(httpResponse.statusCode)
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
  
    
    
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Add headers from endpoint
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        addAuthorizationHeader(&request)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    
                    // Configure date decoding strategy
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)
                    
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw NetworkError.decodingError
                }
            case 401:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? "")
                }
                throw NetworkError.apiError("Client error: \(httpResponse.statusCode)")
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? "")
                }
                throw NetworkError.apiError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            // Log error response
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            // Log unexpected error
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func getUploadUrls(request: UploadUrlRequest) async throws -> UploadUrlResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.getUploadUrls) else {
            throw NetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        addAuthorizationHeader(&urlRequest)
        
        // Encode request body
        urlRequest.httpBody = try? JSONEncoder().encode(request)
        
        // Log the request
        NetworkLogger.log(request: urlRequest)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                return try decoder.decode(UploadUrlResponse.self, from: data)
            case 401:
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? "")
                }
                throw NetworkError.apiError("Failed to get upload URLs")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func uploadFile(url: String, data: Data, contentType: String) async throws {
        guard hasInternet else {
            throw NetworkError.noInternet
        }

        guard let uploadUrl = URL(string: url) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type") // e.g., "image/jpeg"
        addAuthorizationHeader(&request)

        request.httpBody = data

        // Log the request
        NetworkLogger.log(request: request)

        do {
            let (_, response) = try await session.data(for: request)

            // Log the response
            NetworkLogger.log(response: response, data: nil, error: nil)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return
            case 401:
                throw NetworkError.unauthorized
            case 400...499:
                throw NetworkError.apiError("Failed to upload file")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    func fetch<T: Decodable>(_ endpoint: Endpoint, urlRequest: URLRequest) async throws -> T {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        // Log the request
        NetworkLogger.log(request: urlRequest)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    
                    // Configure date decoding strategy
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)
                    
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw NetworkError.decodingError
                }
            case 401:
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError((errorResponse.message ?? errorResponse.error) ?? "")
                }
                throw NetworkError.apiError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    // Add FCM token registration method
    func registerFCMToken(_ token: String) async throws -> EmptyResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.fcmToken) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        addAuthorizationHeader(&request)
        
        let fcmRequest = FCMTokenRequest(token: token)
        request.httpBody = try? JSONEncoder().encode(fcmRequest)
        
        return try await fetch(Endpoint(path: APIConfig.Path.fcmToken), urlRequest: request)
    }
    
    // Add FCM token deletion method
    func deleteFCMToken(_ token: String) async throws -> EmptyResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.fcmToken) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        addAuthorizationHeader(&request)
        
        let fcmRequest = FCMTokenRequest(token: token)
        request.httpBody = try? JSONEncoder().encode(fcmRequest)
        
        return try await fetch(Endpoint(path: APIConfig.Path.fcmToken), urlRequest: request)
    }
    
    // Send contact message method
    func sendContactMessage(email: String, message: String,firstName: String, lastName: String) async throws -> ContactMessageResponse {
        guard hasInternet else {
            throw NetworkError.noInternet
        }
        
        guard let url = URL(string: APIConfig.utilitiesUrl + APIConfig.Path.contactNewsletter) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
        
        let contactRequest = ContactMessageRequest(
            type: "Contact",
            email: email,
            message: message,
            firstName: firstName,
            lastName: lastName,
            applicationSlug: APIConfig.applicationId,
            companySlug: APIConfig.companyId
        )
        
        request.httpBody = try? JSONEncoder().encode(contactRequest)
        
        // Log the request
        NetworkLogger.log(request: request)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(ContactMessageResponse.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw NetworkError.decodingError
                }
            case 401:
                throw NetworkError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.apiError((errorResponse.message ?? errorResponse.error) ?? "")
                }
                throw NetworkError.apiError("Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.unknown(NSError(domain: "Unknown Error", code: httpResponse.statusCode))
            }
        } catch let error as NetworkError {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw error
        } catch {
            NetworkLogger.log(response: nil, data: nil, error: error)
            throw NetworkError.unknown(error)
        }
    }
    
    deinit {
        monitor.cancel()
    }
} 

struct ErrorResponse: Decodable {
    let message: String?
    let success: Bool?
    let statusCode: Int?
    let error:String?
}
