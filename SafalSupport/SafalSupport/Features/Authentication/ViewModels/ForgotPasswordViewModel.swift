import Foundation
import Combine

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var email = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var successMessageOTP: String?
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var otp = ""
    @Published var showOTPVerification = false
    @Published var isEmailVerified = false
    @Published var showPassword = false
    @Published var showConfirmPassword = false
    
    // MARK: - Private Properties
    private var verifyId: String = ""
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let networkManager: NetworkManager
    
    // MARK: - Initialization
    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
        setupValidation()
    }
    
    // MARK: - Public Methods
    func sendEmailVerificationCode() {
        guard validateEmail() else {
            let message = emailError ?? "Please check your input"
            errorMessage = message
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                let response = try await networkManager.sendCodeForVerification(
                    isForgotPassword: true,
                    type: "Email",
                    value: email,
                    phoneNumber: "",
                    isSendRequest: true
                )
                
                await MainActor.run {
                    self.isLoading = false
                    if response.success ?? false {
                        self.verifyId = response.verifyId ?? ""
                        self.showOTPVerification = true
                        self.successMessageOTP = response.message ?? "Verification code sent to your email"
                    } else {
                        self.handleError(message: response.message ?? "Failed to send verification code")
                    }
                }
            } catch let error as NetworkError {
                await handleNetworkError(error)
            } catch {
                await handleNetworkError(.unknown(error))
            }
        }
    }
    
    func verifyEmailOTP() {
        guard validateOTP() else { return }
        guard validatePassword() else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await networkManager.sendCodeForVerification(
                    type: otp,
                    value: verifyId,
                    phoneNumber: email,
                    isSendRequest: false
                )
                
                await MainActor.run {
                    self.isLoading = false
                    if response.success ?? false {
                        self.isEmailVerified = true
                        self.showOTPVerification = false
                        self.successMessageOTP = "Email verified successfully"
                        // Now proceed with password reset
                        Task {
                            await self.resetPassword()
                        }
                    } else {
                        self.handleError(message: response.message ?? "Invalid verification code")
                    }
                }
            } catch let error as NetworkError {
                await handleNetworkError(error)
            } catch {
                await handleNetworkError(.unknown(error))
            }
        }
    }
    
    func resetPassword(Isupadte:Bool = false) async {
        if Isupadte{
            guard validatePassword() else { return }
        }
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await networkManager.resetPassword(
                email: email,
                verifyId: verifyId,
                otp: otp,
                newPassword: newPassword,
                isupdate: Isupadte
            )
            
            await MainActor.run {
                self.isLoading = false
                if response.success ?? true {
                    if Isupadte{
                        self.handleSuccess(message: response.message ?? "Password reset successfully")
                        self.clearForm()
                    }else{
                        self.verifyId = response.verifyId ?? ""
                        self.showOTPVerification = true
                        self.successMessageOTP = response.message ?? "Verification code sent to your email"
                    }
                  
                } else {
                    self.handleError(message: response.message ?? "Something went wrong")
                }
            }
        } catch let error as NetworkError {
            await handleNetworkError(error)
        } catch {
            await handleNetworkError(.unknown(error))
        }
    }
    
    // MARK: - Private Methods
    private func setupValidation() {
        $email
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] email in
                self?.validateEmailFormat(email)
            }
            .store(in: &cancellables)
        
        $newPassword
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] password in
                self?.validatePasswordFormat(password)
            }
            .store(in: &cancellables)
        
        $confirmPassword
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] confirmPassword in
                self?.validateConfirmPasswordFormat(self?.newPassword ?? "", confirmPassword)
            }
            .store(in: &cancellables)
            
        // Automatically clear error message after 3 seconds
        $errorMessage
            .dropFirst()
            .filter { $0 != nil }
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.errorMessage = nil
            }
            .store(in: &cancellables)
        
        $successMessageOTP
            .dropFirst()
            .filter { $0 != nil }
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.successMessageOTP = nil
            }
            .store(in: &cancellables)
    }
    
    private func validateEmail() -> Bool {
        if email.isEmpty {
            emailError = "Email is required"
            return false
        }
        
        if !isValidEmail(email) {
            emailError = "Please enter a valid email"
            return false
        }
        
        emailError = nil
        return true
    }
    
    private func validateEmailFormat(_ email: String) {
        if !email.isEmpty && !isValidEmail(email) {
            emailError = "Please enter a valid email"
        } else {
            emailError = nil
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func validatePassword() -> Bool {
        if newPassword.isEmpty {
            passwordError = "New password is required"
            return false
        }
        
        if newPassword.count < 8 {
            passwordError = "Password must be at least 8 characters"
            return false
        }
        
        if confirmPassword.isEmpty {
            confirmPasswordError = "Please confirm your password"
            return false
        }
        
        if newPassword != confirmPassword {
            confirmPasswordError = "Passwords do not match"
            return false
        }
        
        passwordError = nil
        confirmPasswordError = nil
        return true
    }
    
    private func validatePasswordFormat(_ password: String) {
        if !password.isEmpty && password.count < 8 {
            passwordError = "Password must be at least 8 characters"
        } else {
            passwordError = nil
        }
    }
    
    private func validateConfirmPasswordFormat(_ password: String, _ confirmPassword: String) {
        if !confirmPassword.isEmpty && password != confirmPassword {
            confirmPasswordError = "Passwords do not match"
        } else {
            confirmPasswordError = nil
        }
    }
    
    private func validateOTP() -> Bool {
        if otp.isEmpty {
            errorMessage = "Please enter the verification code"
            return false
        }
        
        if otp.count != 6 {
            errorMessage = "Please enter a valid 6-digit verification code"
            return false
        }
        
        return true
    }
    
    private func clearForm() {
        email = ""
        newPassword = ""
        confirmPassword = ""
        otp = ""
        showOTPVerification = false
        isEmailVerified = false
        verifyId = ""
    }
    
    private func handleSuccess(message: String) {
        successMessage = message  // This will trigger the green success toast
        // Clear the form
        email = ""
    }
    
    private func handleError(message: String) {
        errorMessage = message  // This will trigger the red error toast
    }
    
    private func handleNetworkError(_ error: NetworkError) async {
        await MainActor.run {
            self.isLoading = false
            switch error {
            case .apiError(let message):
                self.errorMessage = message
            default:
                self.errorMessage = NetworkErrorHandler.handle(error: error)
            }
        }
    }
} 
