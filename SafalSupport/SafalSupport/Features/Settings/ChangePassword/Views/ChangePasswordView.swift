import SwiftUI
import Combine

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChangePasswordViewModel()
    
    var body: some View {
        Form {
            Section {
                CustomTextField(
                    title: "Current Password",
                    placeholder: "Enter your current password",
                    text: $viewModel.currentPassword,
                    error: viewModel.currentPasswordError,
                    isSecure: true,
                    showSecureText: $viewModel.showCurrentPassword
                )
                
                CustomTextField(
                    title: "New Password",
                    placeholder: "Enter your new password",
                    text: $viewModel.newPassword,
                    error: viewModel.newPasswordError,
                    isSecure: true,
                    showSecureText: $viewModel.showNewPassword
                )
                
                CustomTextField(
                    title: "Confirm New Password",
                    placeholder: "Confirm your new password",
                    text: $viewModel.confirmPassword,
                    error: viewModel.confirmPasswordError,
                    isSecure: true,
                    showSecureText: $viewModel.showConfirmPassword
                )
            } footer: {
                Text("Password must be at 8 characters long.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
            
            Section {
                Button(action: {
                    Task {
                        await viewModel.changePassword()
                        
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Update Password")
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .listRowBackground(Color.accentColor)
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
        }
        .navigationTitle("Change Password")
        .toast(message: $viewModel.errorMessage, type: .error)
        .toast(message: $viewModel.successMessage, type: .success)
        .onChange(of: viewModel.successMessage) { success in
            if success != nil {
                // Dismiss the view after successful password change
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - ViewModel
final class ChangePasswordViewModel: ObservableObject {
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    
    @Published var showCurrentPassword = false
    @Published var showNewPassword = false
    @Published var showConfirmPassword = false
    
    @Published var currentPasswordError: String?
    @Published var newPasswordError: String?
    @Published var confirmPasswordError: String?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    private var cancellables = Set<AnyCancellable>()
    
  
    
    var isValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        isValidPassword(newPassword)
    }
    
    
    init() {
        setupValidation()
    }
    
    
    @MainActor
    func changePassword() async  {
        guard validateInputs() else { return  }
        
        isLoading = true
        
        Task {
            do {
                let networkManager: NetworkManager = DIContainer.shared.resolve()
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
                var bodyData: [String: String] = [:]
                
                // Only add non-empty values
                if !currentPassword.isEmpty {
                    bodyData["oldPassword"] = currentPassword
                }
                
                if !newPassword.isEmpty {
                    bodyData["newPassword"] = newPassword
                }
                
                if !confirmPassword.isEmpty {
                    bodyData["reNewPassword"] = confirmPassword
                }
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
                } catch {
                    throw NetworkError.invalidResponse
                }
                
                let response: UserUpdateResponse = try await networkManager.fetch(endpoint, urlRequest: request)
               // return !(response.id?.isEmpty ?? true) // Return true if we have a non-empty ID
                successMessage =  "Password updated successfully" 
                isLoading = false
            } catch let error as NetworkError {
                await handleNetworkError(error)
            } catch {
                await handleNetworkError(.unknown(error))
            }
        }
        
    }
    private func setupValidation() {
        // Current Password Validation
        $currentPassword
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] password in
                guard let self = self else { return }
                if password.isEmpty {
                    self.currentPasswordError = "Current password cannot be empty"
                } else if !self.isValidPassword(password) {
                    self.currentPasswordError = "Please enter a valid password"
                } else {
                    self.currentPasswordError = nil
                }
            }
            .store(in: &cancellables)
        
        // New Password Validation
        $newPassword
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] password in
                guard let self = self else { return }
                if password.isEmpty {
                    self.newPasswordError = "New password cannot be empty"
                } else if password.count < 8 {
                    self.newPasswordError = "Password must be at least 8 characters"
                } else {
                    self.newPasswordError = nil
                }
            }
            .store(in: &cancellables)

        // Confirm Password Validation (should match new password)
        Publishers.CombineLatest($newPassword, $confirmPassword)
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] newPassword, confirmPassword in
                guard let self = self else { return }
                if confirmPassword.isEmpty {
                    self.confirmPasswordError = "Confirm password cannot be empty"
                } else if confirmPassword.count < 8 {
                    self.confirmPasswordError = "Password must be at least 8 characters"
                } else if confirmPassword != newPassword {
                    self.confirmPasswordError = "Passwords do not match"
                } else {
                    self.confirmPasswordError = nil
                }
            }
            .store(in: &cancellables)
    }
    
    private func validateInputs() -> Bool {
        var isValid = true
        
        // Reset errors
        currentPasswordError = nil
        newPasswordError = nil
        confirmPasswordError = nil
        
        // Validate current password
        if currentPassword.isEmpty {
            currentPasswordError = "Please enter your current password"
            isValid = false
        }
        
        // Validate new password
        if newPassword.isEmpty {
            newPasswordError = "Please enter a new password"
            isValid = false
        } else if !isValidPassword(newPassword) {
            newPasswordError = "Password must meet the requirements"
            isValid = false
        }
        
        // Validate confirm password
        if confirmPassword.isEmpty {
            confirmPasswordError = "Please confirm your new password"
            isValid = false
        } else if newPassword != confirmPassword {
            confirmPasswordError = "Passwords do not match"
            isValid = false
        }
        
        return isValid
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters long
        guard password.count >= 8 else { return false }
        
        return true
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

#Preview {
    NavigationView {
        ChangePasswordView()
    }
} 
