//
//  ProfileViewModel.swift
//  SafalCalendar
//
//  Created by Apple on 26/06/25.
//

import Foundation
import Combine
import SwiftUI
import PhotosUI
import UIKit

// MARK: - Profile Models
struct ProfileValidationError {
    var firstName: String?
    var lastName: String?
    var email: String?
    var country: String?
    var phoneNumber: String?
    var ncpiNumber: String?
    
    var hasErrors: Bool {
        return [firstName, lastName, email, country, phoneNumber, ncpiNumber].contains { $0 != nil }
    }
}

struct ProfileUpdateRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let country: String
    let phoneNumber: Int64?
    let ncpiNumber: String?
}

struct ProfileResponse: Codable {
    let message: String?
    let success: Bool?
    let statusCode: Int?
    let error: String?
}

// MARK: - Profile Data Model
struct ProfileData {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var country: String = ""
    var phoneNumber: String = ""
    var isEmailVerified: Bool = true
    var profilePictureUrl: String?
    var isPhoneVerified: Bool = true
    var role:String = ""
    var ncpiNumber: String? = nil
    var isTwoFactorEnabled: Bool = false
    
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    init() {}
    
    init(from user: UserModel) {
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        email = user.email ?? ""
        country = user.country ?? ""
        isEmailVerified = user.isEmailVerified ?? true
        profilePictureUrl = user.profilePictureSign
        isPhoneVerified = user.isPhoneVerified ?? true
        role = user.role ?? ""
        ncpiNumber = user.metadata?.ncpiNumber ?? ""
        isTwoFactorEnabled = user.isTwoFactorEnabled ?? false
        
        if let phone = user.phoneNumber {
            phoneNumber = String(phone)
        }
    }
}

// MARK: - ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Delete Account
    func deleteAccount(password: String) async -> Bool {
        state = .loading
        errorMessage = nil
        
        do {
            let success = try await profileService.deleteAccount(password: password)
            state = .loaded
            
            if success {
                // Clear user data on successful deletion
                UserDefaults.standard.removeObject(forKey: "currentUser")
                UserDefaults.standard.removeObject(forKey: "fcmToken")
                // Reset app icon badge number to 0 on account deletion
                UIApplication.shared.applicationIconBadgeNumber = 0
                return true
            } else {
                errorMessage = "Failed to delete account"
                return false
            }
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Two-Factor Authentication
    func updateTwoFactorAuthentication(enabled: Bool) async {
        // This method is now handled by the dedicated TwoFactorAuthViewModel
        // Keeping it for backward compatibility but it's deprecated
        state = .loading
        errorMessage = nil
        
        do {
            let success = try await profileService.updateTwoFactorAuthentication(enabled: enabled)
            state = .loaded
            
            if success {
                isTwoFactorEnabled = enabled
                successMessage = enabled ? "Two-factor authentication enabled" : "Two-factor authentication disabled"
            } else {
                errorMessage = "Failed to update two-factor authentication"
                // Revert the toggle if the API call failed
                isTwoFactorEnabled = !enabled
            }
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            // Revert the toggle if the API call failed
         //   isTwoFactorEnabled = !enabled
        }
    }

    // MARK: - Published Properties
    @Published private(set) var state = ViewState.idle
    @Published var profile = ProfileData()
    @Published private(set) var validationError = ProfileValidationError()
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?
    @Published var showOTPVerification = false
    @Published var showEmailVerification = false
    @Published var otp = ""
    @Published var isPhoneVerified = false
    @Published var isEmailVerified = false
    @Published var successMessageOTP: String?
    @Published var isTwoFactorEnabled = false
    
    // MARK: - Private Properties
    private let profileService: ProfileServicing
    private var verifyId: String = ""
    private var emailVerifyId: String = ""
    private var verifiedPhoneNumbers: Set<String> = []
    private var verifiedEmails: Set<String> = []
    private var originalPhoneNumber: String = ""
    private var originalEmail: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }
    
    var canSave: Bool {
        !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !profile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(profile.email) &&
        validationError.firstName == nil &&
        validationError.lastName == nil &&
        validationError.email == nil &&
        validationError.country == nil &&
        validationError.phoneNumber == nil
    }
    
    var formattedPhoneNumber: String {
        guard !profile.phoneNumber.isEmpty else { return "" }
        return profile.phoneNumber
    }
    
    // MARK: - Initialization
    init(profileService: ProfileServicing = ProfileService()) {
        self.profileService = profileService
        setupValidation()
        Task {
            await fetchProfile()
        }
    }
    
    private func setupValidation() {
        // First Name Validation
        $profile
            .map(\.firstName)
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.validateFirstName(name)
            }
            .store(in: &cancellables)
        
        // Last Name Validation
        $profile
            .map(\.lastName)
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.validateLastName(name)
            }
            .store(in: &cancellables)
        
        // Email Validation
        $profile
            .map(\.email)
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] email in
                self?.validateEmail(email)
            }
            .store(in: &cancellables)
    }
    
    private func validateFirstName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationError.firstName = "First name is required"
        } else if name.hasPrefix(" ") || name.hasSuffix(" ") {
            validationError.firstName = "First name cannot start or end with spaces"
        } else {
            validationError.firstName = nil
        }
    }
    
    private func validateLastName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            validationError.lastName = "Last name is required"
        } else if name.hasPrefix(" ") || name.hasSuffix(" ") {
            validationError.lastName = "Last name cannot start or end with spaces"
        } else {
            validationError.lastName = nil
        }
    }
    
    private func validateEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            validationError.email = "Email is required"
        } else if trimmedEmail != email {
            validationError.email = "Email cannot contain spaces"
        } else if !isValidEmail(trimmedEmail) {
            validationError.email = "Please enter a valid email"
        } else {
            validationError.email = nil
        }
    }
    
    // MARK: - Public Methods
    func fetchProfile() async {
        state = .loading
        errorMessage = nil
        
        do {
            let response = try await profileService.fetchProfile()
            profile = ProfileData(from: response)
            
            // Sync two-factor authentication status
            isTwoFactorEnabled = profile.isTwoFactorEnabled
            
            // Store the original phone number and email from API
            if let phone = response.phoneNumber {
                originalPhoneNumber = String(phone)
                // If phone number exists and is verified, add it to verified numbers
                if response.isPhoneVerified == true {
                    verifiedPhoneNumbers.insert(String(phone))
                    isPhoneVerified = true
                }
            }
            
            if let email = response.email {
                originalEmail = email
                // If email exists and is verified, add it to verified emails
                if response.isEmailVerified == true {
                    verifiedEmails.insert(email)
                    isEmailVerified = true
                }
            }
            
            // Update the stored user name in TokenManager when profile is loaded
            TokenManager.shared.updateUserName(firstName: profile.firstName, lastName: profile.lastName)
            
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    func uploadImage(_ image: UIImage) async throws -> String? {
        state = .loading
        errorMessage = nil
        
        do {
            let imagePath = try await profileService.uploadImage(image)
            state = .loaded
            return imagePath
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func resetProfile() {
        profile = ProfileData()
        validationError = ProfileValidationError()
        state = .idle
    }
    
    func updateProfile(firstName: String, lastName: String, email: String, phoneNumber: String, country: String, profilePicture: String, ncpiNumber: String? = nil) async {
        guard validateFields(firstName: firstName, lastName: lastName, email: email, phoneNumber: phoneNumber, country: country, ncpiNumber: ncpiNumber) else {
            return
        }
        
        // If phone number changed and not verified, prevent update
        let formattedNumber = phoneNumber.isEmpty ? "" : phoneNumber
        if !formattedNumber.isEmpty && formattedNumber != profile.phoneNumber && !isPhoneVerified {
            errorMessage = "Please verify your phone number before updating"
            return
        }
        
        // If email changed and not verified, prevent update
        if !email.isEmpty && email != profile.email && !isEmailVerified {
            errorMessage = "Please verify your email before updating"
            return
        }
        
        state = .loading
        errorMessage = nil
        
        do {
            let success = try await profileService.updateProfile(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: String(formattedNumber.dropFirst()),
                country: country,
                profilePicture: profilePicture,
                phoneNumberVerifyId: isPhoneVerified ? verifyId : nil,
                emailVerifyId: isEmailVerified ? emailVerifyId : nil,
                ncpiNumber: ncpiNumber
            )
            
            if success {
                // Fetch updated profile data
                let response = try await profileService.fetchProfile()
                profile = ProfileData(from: response)
                
                // Update the stored user name in TokenManager
                TokenManager.shared.updateUserName(firstName: firstName, lastName: lastName)
                
                successMessage = "Profile updated successfully"
                state = .loaded
                
                // Reset verification states
                resetPhoneVerification()
                resetEmailVerification()
            } else {
                state = .error("Failed to update profile")
                errorMessage = "Failed to update profile"
            }
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }
    
    // Add this new method to handle successful verification
    func handleSuccessfulVerification(phoneNumber: String) {
        verifiedPhoneNumbers.insert(phoneNumber)
        isPhoneVerified = true
        showOTPVerification = false
        // Update the original phone number to the newly verified one
        originalPhoneNumber = phoneNumber
    }
    
    // Update needsVerification to check against verified numbers
    func needsVerification(phoneNumber: String) -> Bool {
        // If phone number is empty, no verification needed
        if phoneNumber.isEmpty {
            return false
        }
        
        // Check if this number is in our verified numbers set
        if verifiedPhoneNumbers.contains(phoneNumber) {
            return false
        }
        
        // If current number is different from original verified number
        if phoneNumber != originalPhoneNumber {
            return true
        }
        
        return true
    }
    
    func resetPhoneVerification() {
        showOTPVerification = false
        isPhoneVerified = false
        otp = ""
        verifyId = ""
    }
    
    func sendVerificationCode(phoneNumber: String) async {
    //    guard validatePhoneNumber(phoneNumber) else { return }
        
        // If this number is already verified, no need to verify again
        if verifiedPhoneNumbers.contains(phoneNumber) {
            isPhoneVerified = true
            showOTPVerification = false
            return
        }
        
        state = .loading
        errorMessage = nil
        
        do {
            let response = try await profileService.sendCodeForVerification(
                type: "PhoneNumber",
                value: phoneNumber,
                phoneNumber: "",
                isSendRequest: true
            )
            
            state = .loaded
            
            if response.success ?? false {
                verifyId = response.verifyId ?? ""
                showOTPVerification = true
                successMessageOTP = response.message ?? "Verification code sent to your phone"
            } else {
                errorMessage = response.message ?? "Failed to send verification code"
            }
        } catch let error as NetworkError {
            state = .loaded
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            state = .loaded
            errorMessage = error.localizedDescription
        }
    }
    
    func verifyOTP(phoneNumber: String) async {
        guard validateOTP() else { return }
        
        state = .loading
        errorMessage = nil
        
        do {
            let response = try await profileService.sendCodeForVerification(
                type: otp,
                value: verifyId,
                phoneNumber: phoneNumber,
                isSendRequest: false
            )
            
            state = .loaded
            
            if response.success ?? false {
                handleSuccessfulVerification(phoneNumber: phoneNumber)
                successMessageOTP = response.message ?? "Phone number verified successfully"
            } else {
                errorMessage = response.message ?? "Invalid verification code"
            }
        } catch let error as NetworkError {
            state = .loaded
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            state = .loaded
            errorMessage = error.localizedDescription
        }
    }
    
    // Add these new methods for email verification
    func resetEmailVerification() {
        showEmailVerification = false
        isEmailVerified = false
        otp = ""
        emailVerifyId = ""
    }
    
    func needsEmailVerification(email: String) -> Bool {
        // If email is empty, no verification needed
        if email.isEmpty {
            return false
        }
        
        // Check if this email is in our verified emails set
        if verifiedEmails.contains(email) {
            return false
        }
        
        // If current email is different from original verified email
        if email != originalEmail {
            return true
        }
        
        return true
    }
    
    func sendEmailVerificationCode(email: String) async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // If this email is already verified, no need to verify again
        if verifiedEmails.contains(email) {
            isEmailVerified = true
            showEmailVerification = false
            return
        }
        
        state = .loading
        errorMessage = nil
        
        do {
            let response = try await profileService.sendCodeForVerification(
                type: "Email",
                value: email,
                phoneNumber: "",
                isSendRequest: true
            )
            
            state = .loaded
            
            if response.success ?? false {
                emailVerifyId = response.verifyId ?? ""
                showEmailVerification = true
                successMessageOTP = response.message ?? "Verification code sent to your email"
            } else {
                errorMessage = response.message ?? "Failed to send verification code"
            }
        } catch let error as NetworkError {
            state = .loaded
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            state = .loaded
            errorMessage = error.localizedDescription
        }
    }
    
    func verifyEmailOTP(email: String) async {
        guard validateOTP() else { return }
        
        state = .loading
        errorMessage = nil
        
        do {
            let response = try await profileService.sendCodeForVerification(
                type: otp,
                value: emailVerifyId,
                phoneNumber: email,
                isSendRequest: false
            )
            
            state = .loaded
            
            if response.success ?? false {
                handleSuccessfulEmailVerification(email: email)
                successMessageOTP = response.message ?? "Email verified successfully"
            } else {
                errorMessage = response.message ?? "Invalid verification code"
            }
        } catch let error as NetworkError {
            state = .loaded
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            state = .loaded
            errorMessage = error.localizedDescription
        }
    }
    
    func handleSuccessfulEmailVerification(email: String) {
        verifiedEmails.insert(email)
        isEmailVerified = true
        showEmailVerification = false
        // Update the original email to the newly verified one
        originalEmail = email
    }
    
    // MARK: - Private Methods
    private func validateFields(firstName: String, lastName: String, email: String, phoneNumber: String, country: String, ncpiNumber: String? = nil) -> Bool {
        var isValid = true
        var errors = ProfileValidationError()
        
        // First Name validation
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFirstName.isEmpty {
            errors.firstName = "First name is required"
            isValid = false
        } else if firstName.hasPrefix(" ") || firstName.hasSuffix(" ") {
            errors.firstName = "First name cannot start or end with spaces"
            isValid = false
        }
        
        // Last Name validation
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLastName.isEmpty {
            errors.lastName = "Last name is required"
            isValid = false
        } else if lastName.hasPrefix(" ") || lastName.hasSuffix(" ") {
            errors.lastName = "Last name cannot start or end with spaces"
            isValid = false
        }
        
        // Email validation
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            errors.email = "Email is required"
            isValid = false
        } else if trimmedEmail != email {
            errors.email = "Email cannot contain spaces"
            isValid = false
        } else if !isValidEmail(trimmedEmail) {
            errors.email = "Please enter a valid email"
            isValid = false
        }
        
        // Phone Number validation (optional)
        if !phoneNumber.isEmpty {
            // Remove any non-numeric characters
            let numericOnly = phoneNumber.filter { $0.isNumber }
            
            if numericOnly.count < 10 {
                errors.phoneNumber = "Phone number must be 10 digits"
                isValid = false
            }
        }
        
        // Country validation
        if country.isEmpty {
            errors.country = "Please select your country"
            isValid = false
        }
        
        // NCPI Number validation (required for non-Patient roles)
        if profile.role != "Patient" {
            if let ncpiNumber = ncpiNumber, ncpiNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.ncpiNumber = "NCPI Number is required for \(profile.role) role"
                isValid = false
            }
        }
        
        validationError = errors
        return isValid
    }
    
    private func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        if phoneNumber.isEmpty {
            errorMessage = "Phone number is required for verification"
            return false
        }
        
        // Check if it starts with + and has at least 10 digits after
        let phoneRegex = "^\\+[0-9]{10,}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        if !phonePredicate.evaluate(with: phoneNumber) {
            errorMessage = "Please enter a valid phone number with country code"
            return false
        }
        
        return true
    }
    
    private func validateOTP() -> Bool {
        if otp.isEmpty {
            errorMessage = "Please enter the verification code"
            return false
        }
        
        // Remove any non-numeric characters
        let cleanedOTP = otp.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if cleanedOTP.count != 6 {
            errorMessage = "Please enter a valid 6-digit verification code"
            return false
        }
        
        return true
    }
    
     func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Supporting Types
extension ProfileViewModel {
    enum ViewState {
        case idle
        case loading
        case loaded
        case error(String)
    }
}


