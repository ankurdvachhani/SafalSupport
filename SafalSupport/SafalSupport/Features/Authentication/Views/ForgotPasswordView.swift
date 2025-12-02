import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo and Title
                    logoSection
                    
                    // Description
                    Text("Enter your email address and we'll send you a verification code to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Form
                    formSection
                    
                    // Action buttons
                    actionButtons
                    
                    // Back to login
                    backToLoginButton
                }
                .padding(.horizontal, 24)
            }
            .disabled(viewModel.isLoading)
            
            if viewModel.isLoading {
                progressView()
            }
        }
        .withGradientBackground()
        .toast(message: $viewModel.errorMessage)
        .toast(message: $viewModel.successMessage, type: .success)
        .toast(message: $viewModel.successMessageOTP, type: .success)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.accent)
                }
            }
        }
    }
    
    private var logoSection: some View {
        VStack(spacing: 8) {
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              
            Text("Forgot Password")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.top, 60)
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            CustomTextField(
                title: "Email",
                placeholder: "Enter your email",
                text: $viewModel.email,
                error: viewModel.emailError
            )
            
            if viewModel.showOTPVerification {
                // OTP Field
                CustomTextField(
                    title: "Verification Code",
                    placeholder: "Enter 6-digit code",
                    text: $viewModel.otp,
                    error: nil
                )
                .keyboardType(.numberPad)
                
                // New Password Field
                CustomTextField(
                    title: "New Password",
                    placeholder: "Enter new password",
                    text: $viewModel.newPassword,
                    error: viewModel.passwordError,
                    isSecure: true,
                    showSecureText: $viewModel.showPassword
                )
                
                // Confirm Password Field
                CustomTextField(
                    title: "Confirm Password",
                    placeholder: "Confirm new password",
                    text: $viewModel.confirmPassword,
                    error: viewModel.confirmPasswordError,
                    isSecure: true,
                    showSecureText: $viewModel.showConfirmPassword
                )
            }
        }
        .padding(.vertical, 20)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if !viewModel.showOTPVerification {
                Button(action: {
                    Task {
                        await viewModel.resetPassword()
                    }
                }) {
                    Text("SEND VERIFICATION CODE")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(Color.accent)
                        .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
            } else {
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.resetPassword(Isupadte: true)
                        }
                    }) {
                        Text("RESET PASSWORD")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.white)
                            .background(Color.accent)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        Task {
                            await viewModel.resetPassword()
                        }
                    }) {
                        Text("RESEND CODE")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.accent)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accent, lineWidth: 1)
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }
    
    private var backToLoginButton: some View {
        Button(action: { dismiss() }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back to Login")
            }
            .foregroundColor(.accent)
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    NavigationView {
        ForgotPasswordView()
    }
} 

struct progressView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .progressViewStyle(CircularProgressViewStyle(tint: .accent))
    }
}
