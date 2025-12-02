import Foundation
import Security

final class TokenManager {
    static let shared = TokenManager()
    
    private let tokenKey = "com.safalcalendar.accessToken"
    private let userNameKey = "com.safalcalendar.userName"
    private let userIdKey = "com.safalcalendar.userId"
    
    private init() {}
    
    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func saveUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: userNameKey)
    }
    
    func getUserName() -> String? {
        return UserDefaults.standard.string(forKey: userNameKey)
    }
    
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
    
    func deleteToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        // Also clear the user name when logging out
        UserDefaults.standard.removeObject(forKey: userNameKey)
        clearUserData()
    }
    
    func loadCurrentUser() -> UserModel? {
        if let data = UserDefaults.standard.data(forKey: "currentUser") {
            return try? JSONDecoder().decode(UserModel.self, from: data)
        }
        return nil
    }
    
    func saveUserId(_ id: String) {
        UserDefaults.standard.set(id, forKey: userIdKey)
        print("💾 User ID saved: \(id)")
    }
    
    func getUserId() -> String? {
        return UserDefaults.standard.string(forKey: userIdKey)
    }
    
    func clearUserData() {
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        clearColorTheme()
    }
    
    func clearColorTheme() {
        // Clear color settings
        ThemeManager.shared.clearStoredColors()
    }
    
    /// Updates the stored user name when profile is updated
    /// - Parameter name: The new user name to store
    func updateUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: userNameKey)
        print("💾 User name updated: \(name)")
    }
    
    /// Updates the stored user name with first and last name
    /// - Parameters:
    ///   - firstName: The user's first name
    ///   - lastName: The user's last name
    func updateUserName(firstName: String, lastName: String) {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        updateUserName(fullName)
    }
} 
