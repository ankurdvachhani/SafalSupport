import Foundation
import LocalAuthentication
import Combine

/// Service for handling biometric authentication (Touch ID, Face ID, etc.)
final class BiometricAuthenticationService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = BiometricAuthenticationService()
    
    // MARK: - Published Properties
    @Published var isBiometricAvailable = false
    @Published var biometricType: BiometricType = .none
    @Published var isBiometricEnabled = false
    
    // MARK: - Private Properties
    private let context = LAContext()
    private let keychainService = "com.safalirdrainmate.biometric"
    private let biometricKey = "biometric_credentials"
    private let userDefaultsKey = "biometric_authentication_enabled"
    
    // MARK: - Biometric Types
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID
        
        var displayName: String {
            switch self {
            case .none: return "Biometric Authentication"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none: return "touchid"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        checkBiometricAvailability()
        loadBiometricSettings()
        loadUserDefaultsSettings()
    }
    
    // MARK: - Public Methods
    
    /// Check if biometric authentication is available on the device
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            
            switch context.biometryType {
            case .touchID:
                biometricType = .touchID
            case .faceID:
                biometricType = .faceID
            case .opticID:
                biometricType = .opticID
            default:
                biometricType = .none
            }
        } else {
            isBiometricAvailable = false
            biometricType = .none
        }
    }
    
    /// Authenticate using biometrics
    func authenticateWithBiometrics(reason: String = "Authenticate to access your account") async -> Bool {
        guard isBiometricAvailable else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Biometric authentication failed: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: success)
                    }
                }
            }
        }
    }
    
    /// Save credentials securely for biometric authentication
    func saveCredentialsForBiometric(email: String, password: String) -> Bool {
        guard isBiometricAvailable else { return false }
        
        let credentials = "\(email):\(password)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: biometricKey,
            kSecValueData as String: credentials.data(using: .utf8)!,
            kSecAttrAccessControl as String: createAccessControl()
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            isBiometricEnabled = true
            saveBiometricSettings()
            return true
        } else {
            print("Failed to save biometric credentials: \(status)")
            return false
        }
    }
    
    /// Retrieve credentials using biometric authentication
    func retrieveCredentialsWithBiometric() async -> (email: String, password: String)? {
        guard isBiometricAvailable else { return nil }
        
        // First authenticate with biometrics
        let authenticated = await authenticateWithBiometrics(
            reason: "Use \(biometricType.displayName) to access your saved credentials"
        )
        
        guard authenticated else { return nil }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: biometricKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let credentials = String(data: data, encoding: .utf8) {
            let components = credentials.components(separatedBy: ":")
            if components.count == 2 {
                return (email: components[0], password: components[1])
            }
        }
        
        return nil
    }
    
    /// Remove saved biometric credentials
    func removeBiometricCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: biometricKey
        ]
        
        SecItemDelete(query as CFDictionary)
        isBiometricEnabled = false
        saveBiometricSettings()
    }
    
    /// Check if biometric credentials are saved
    func hasBiometricCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: biometricKey,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }
    
    // MARK: - Private Methods
    
    private func createAccessControl() -> SecAccessControl {
        var error: Unmanaged<CFError>?
        let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            &error
        )
        
        if let error = error {
            print("Failed to create access control: \(error)")
        }
        
        return accessControl!
    }
    
    private func saveBiometricSettings() {
        UserDefaults.standard.set(isBiometricEnabled, forKey: userDefaultsKey)
    }
    
    private func loadBiometricSettings() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey) && hasBiometricCredentials()
    }
    
    private func loadUserDefaultsSettings() {
        // Load the UserDefaults setting
        let userDefaultsEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        // Only enable if both UserDefaults allows it AND credentials exist
        isBiometricEnabled = userDefaultsEnabled && hasBiometricCredentials()
    }
    
    private func saveUserDefaultsSettings() {
        UserDefaults.standard.set(isBiometricEnabled, forKey: userDefaultsKey)
    }
    
    /// Enable biometric authentication (save to UserDefaults)
    func enableBiometricAuthentication() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        isBiometricEnabled = true
        saveUserDefaultsSettings()
    }
    
    /// Disable biometric authentication (remove from UserDefaults)
    func disableBiometricAuthentication() {
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        isBiometricEnabled = false
        saveUserDefaultsSettings()
    }
    
    /// Check if biometric authentication is enabled in UserDefaults
    func isBiometricAuthenticationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
}

// MARK: - Biometric Authentication Error Types
enum BiometricAuthenticationError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockedOut
    case userCancel
    case systemCancel
    case authenticationFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric data is enrolled. Please set up \(LAContext().biometryType == .faceID ? "Face ID" : "Touch ID") in Settings"
        case .lockedOut:
            return "Biometric authentication is locked out. Please use your passcode to unlock"
        case .userCancel:
            return "Authentication was cancelled by user"
        case .systemCancel:
            return "Authentication was cancelled by system"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
