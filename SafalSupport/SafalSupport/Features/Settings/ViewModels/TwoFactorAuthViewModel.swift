import Foundation
import Combine


struct TwoFactorAuthSettings: Codable {
    let auth2faEmail: String?
    let auth2faPhoneNumber: String?
    let auth2faBackup: Bool
    let auth2faBackupPassword: [String]?
}

// MARK: - Two-Factor Authentication ViewModel
@MainActor
final class TwoFactorAuthViewModel: ObservableObject {
    @Published var isEnabled = false
    @Published var isEmailVerified = false
    @Published var isPhoneVerified = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var backupCodes: [String] = []
    @Published var isUserInitiatedChange = false
    
    // Verification IDs
    private var emailVerifyId = ""
    private var phoneVerifyId = ""
    
    // Computed property to check if toggle should be enabled
    var canEnableToggle: Bool {
        return (isEmailVerified || isPhoneVerified) && (!currentEmail.isEmpty || !currentPhone.isEmpty)
    }
    
    // Current settings
    var currentEmail = ""
    var currentPhone = ""
    
    private let profileService: ProfileServicing
    
    init(profileService: ProfileServicing = ProfileService()) {
        self.profileService = profileService
    }
    
    // MARK: - Load Current Settings
    func loadCurrentSettings() async {
        isLoading = true
        errorMessage = nil
        isUserInitiatedChange = false // Reset flag for initial load
        
        do {
            let response = try await profileService.fetchProfile()
            
            // Load current 2FA settings if available
            if let auth2faEmail = response.auth2faEmail, !auth2faEmail.isEmpty {
                currentEmail = auth2faEmail
                isEmailVerified = true
                print("Loaded existing 2FA email: \(auth2faEmail)")
            }
            
            if let auth2faPhoneNumber = response.auth2faPhoneNumber, !auth2faPhoneNumber.isEmpty {
                currentPhone = auth2faPhoneNumber
                isPhoneVerified = true
                print("Loaded existing 2FA phone: \(auth2faPhoneNumber)")
            }
            
            // Load backup codes if available
            if let backupPassword = response.auth2faBackupPassword {
                backupCodes = backupPassword
                print("Loaded existing backup codes: \(backupPassword)")
            }
            
            // Check if 2FA is already enabled based on existing data
            // If at least one of email or phone is set and verified, enable 2FA
            if (!currentEmail.isEmpty && isEmailVerified) || (!currentPhone.isEmpty && isPhoneVerified) {
                isEnabled = true
                print("2FA is already configured and enabled")
            } else {
                // Use the API response value as fallback
                isEnabled = response.isTwoFactorEnabled ?? false
                print("2FA enabled from API: \(isEnabled)")
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load 2FA settings: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Email Verification
    func sendEmailVerificationCode(email: String) async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await profileService.TwoFAsendCodeForVerification(
                type: "Email",
                value: email,
                phoneNumber: "",
                isSendRequest: true
            )
            
            isLoading = false
            
            if response.success ?? false {
                emailVerifyId = response.verifyId ?? ""
                successMessage = response.message ?? "Verification code sent to your email"
            } else {
                errorMessage = response.message ?? "Failed to send verification code"
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to send verification code: \(error.localizedDescription)"
        }
    }
    
    func verifyEmailOTP(email: String, otp: String) async {
        guard validateOTP(otp) else {
            errorMessage = "Please enter a valid 6-digit verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await profileService.TwoFAsendCodeForVerification(
                type: otp,
                value: emailVerifyId,
                phoneNumber: email,
                isSendRequest: false
            )
            
            isLoading = false
            
            if response.success ?? false {
                isEmailVerified = true
                currentEmail = email
                successMessage = "Email verified successfully"
                isUserInitiatedChange = true
                Task {
                    await updateTwoFactorAuthentication(enabled: true)
                }
            } else {
                errorMessage = response.message ?? "Invalid verification code"
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to verify email: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Phone Verification
    func sendPhoneVerificationCode(phoneNumber: String) async {
        guard validatePhoneNumber(phoneNumber) else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await profileService.TwoFAsendCodeForVerification(
                type: "PhoneNumber",
                value: phoneNumber,
                phoneNumber: "",
                isSendRequest: true
            )
            
            isLoading = false
            
            if response.success ?? false {
                phoneVerifyId = response.verifyId ?? ""
                successMessage = response.message ?? "Verification code sent to your phone"
            } else {
                errorMessage = response.message ?? "Failed to send verification code"
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to send verification code: \(error.localizedDescription)"
        }
    }
    
    func verifyPhoneOTP(phoneNumber: String, otp: String) async {
        guard validateOTP(otp) else {
            errorMessage = "Please enter a valid 6-digit verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await profileService.TwoFAsendCodeForVerification(
                type: otp,
                value: phoneVerifyId,
                phoneNumber: phoneNumber,
                isSendRequest: false
            )
            
            isLoading = false
            
            if response.success ?? false {
                isPhoneVerified = true
                currentPhone = phoneNumber
                successMessage = "Phone verified successfully"
                isUserInitiatedChange = true
                Task {
                    await updateTwoFactorAuthentication(enabled: true)
                }
            } else {
                errorMessage = response.message ?? "Invalid verification code"
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to verify phone: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Update Two-Factor Authentication
    func updateTwoFactorAuthentication(enabled: Bool) async {
        // Validation: Check if at least one of email or phone is verified
        guard isEmailVerified || isPhoneVerified else {
            errorMessage = "At least one of email or phone must be verified to enable 2FA"
            return
        }
        
        // Validation: Check if at least one of email or phone is not empty
        guard !currentEmail.isEmpty || !currentPhone.isEmpty else {
            errorMessage = "At least one of email or phone number is required to enable 2FA"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let request: TwoFactorAuthRequest
            
            if enabled {
                // Enable 2FA: Use actual email and phone values
                request = TwoFactorAuthRequest(
                    auth2faEmail: currentEmail,
                    auth2faPhoneNumber: currentPhone,
                    auth2faEmailVerifiedId: emailVerifyId,
                    auth2faPhoneNumberVerifiedId: phoneVerifyId,
                    auth2faBackup: true
                )
            } else {
                // Disable 2FA: Use "DELETE" values
                request = TwoFactorAuthRequest(
                    auth2faEmail: "DELETE",
                    auth2faPhoneNumber: "DELETE",
                    auth2faEmailVerifiedId: emailVerifyId,
                    auth2faPhoneNumberVerifiedId: phoneVerifyId,
                    auth2faBackup: false
                )
            }
            
            let (success, backupCodes) = try await profileService.updateTwoFactorAuthentication(request: request)
            
            if success {
                isEnabled = enabled
                successMessage = enabled ? "Two-factor authentication enabled successfully" : "Two-factor authentication disabled successfully"
                
                // Only set backup codes when enabling (not when disabling)
                if enabled, let codes = backupCodes {
                    self.backupCodes = codes
                    print("Backup codes received: \(codes)")
                }
            } else {
                errorMessage = "Failed to update two-factor authentication"
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to update two-factor authentication: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Fetch Backup Codes
    private func fetchBackupCodes() async {
        do {
            let response = try await profileService.fetchProfile()
            if let backupPassword = response.auth2faBackupPassword {
                backupCodes = backupPassword
            }
        } catch {
            errorMessage = "Failed to fetch backup codes: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Generate New Backup Codes
    func generateNewBackupCodes() async {
        guard isEnabled else {
            errorMessage = "2FA must be enabled to generate backup codes"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let request = TwoFactorAuthRequest(
                auth2faEmail: currentEmail,
                auth2faPhoneNumber: currentPhone,
                auth2faEmailVerifiedId: emailVerifyId,
                auth2faPhoneNumberVerifiedId: phoneVerifyId,
                auth2faBackup: true
            )
            
            let (success, backupCodes) = try await profileService.updateTwoFactorAuthentication(request: request)
            
            if success, let codes = backupCodes {
                self.backupCodes = codes
                successMessage = "New backup codes generated successfully"
                print("New backup codes generated: \(codes)")
            } else {
                errorMessage = "Failed to generate new backup codes"
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to generate new backup codes: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Validation Methods
    private func validateOTP(_ otp: String) -> Bool {
        let cleanedOTP = otp.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleanedOTP.count == 6
    }
    
    private func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        // Check if it starts with + and has at least 10 digits after
        let phoneRegex = "^\\+[0-9]{10,}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
