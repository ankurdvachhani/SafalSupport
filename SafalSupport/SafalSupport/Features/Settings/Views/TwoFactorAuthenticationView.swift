import SwiftUI

struct TwoFactorAuthenticationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TwoFactorAuthViewModel()
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var countryCode = "+1"
    @State private var showEmailOTPView = false
    @State private var showPhoneOTPView = false
    @State private var showBackupCodes = false
    @State private var backupCodes: [String] = []
    @State private var emailOTP = ""
    @State private var phoneOTP = ""
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Form Fields
                    formFields
                    
                    // Enable/Disable Toggle
                    toggleSection
                    
                    // Backup Codes Section (when enabled)
//                    if viewModel.isEnabled {
//                        backupCodesSection
//                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .overlay(content: {
                    if showEmailOTPView {
                        emailOTPView
                    }
                    if showPhoneOTPView {
                        phoneOTPView
                    }
                    if showBackupCodes {
                      //  backupCodesOverlay
                    }
                })
            }
            .disabled(viewModel.isLoading)
        }
        .withGradientBackground()
        .navigationTitle("Two-Factor Authentication")
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $viewModel.errorMessage, type: .error)
        .toast(message: $viewModel.successMessage, type: .success)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: viewModel.isEnabled) { oldValue, newValue in
            if newValue == false {
                // back to sceen
                dismiss()
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.dynamicAccent)
            
            Text("Two-Factor Authentication")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Add an extra layer of security to your account")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Form Fields
    private var formFields: some View {
        VStack(spacing: 16) {
            // Email Verification
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Email Address*")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if viewModel.isEmailVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    TextField("Enter your email", text: $email)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .disabled(viewModel.isEmailVerified)
                    
                    if !viewModel.isEmailVerified && !email.isEmpty {
                        Button("Verify") {
                            Task {
                                await viewModel.sendEmailVerificationCode(email: email)
                                if viewModel.successMessage != nil {
                                    showEmailOTPView = true
                                }
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accent)
                        .cornerRadius(8)
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            
            // Phone Verification
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Phone Number*")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if viewModel.isPhoneVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    CountryCodePicker(selectedCode: $countryCode)
                        .frame(width: 100)
                    
                    TextField("Enter phone number", text: $phoneNumber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .disabled(viewModel.isPhoneVerified)
                    
                    if !viewModel.isPhoneVerified && phoneNumber.count >= 10 {
                        Button("Verify") {
                            Task {
                                let fullPhoneNumber = "\(countryCode)\(phoneNumber)"
                                await viewModel.sendPhoneVerificationCode(phoneNumber: fullPhoneNumber)
                                if viewModel.successMessage != nil {
                                    showPhoneOTPView = true
                                }
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accent)
                        .cornerRadius(8)
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
    }
    
    // MARK: - Toggle Section
    private var toggleSection: some View {
        VStack(spacing: 16) {
            // Main 2FA Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Two-Factor Authentication")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Enable or disable 2FA for your account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .dynamicAccent))
                    .onChange(of: viewModel.isEnabled) { newValue in
                        // Only call API if this is a user-initiated change, not initial load
                        if viewModel.isUserInitiatedChange {
                            Task {
                                await viewModel.updateTwoFactorAuthentication(enabled: newValue)
                                if newValue && viewModel.successMessage != nil {
                                    backupCodes = viewModel.backupCodes
                                    showBackupCodes = true
                                }
                            }
                        }
                        // Reset the flag after handling the change
                        viewModel.isUserInitiatedChange = true
                    }
                    .disabled(!viewModel.canEnableToggle)
            }
            
            // Backup Codes Generation (only when 2FA is enabled)
//            if viewModel.isEnabled {
//                HStack {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Generate New Backup Codes")
//                            .font(.headline)
//                            .foregroundColor(.primary)
//                        
//                        Text("Create new backup codes (old codes will be invalidated)")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    Spacer()
//                    
//                    Button("Generate") {
//                        Task {
//                            await viewModel.generateNewBackupCodes()
//                            if !viewModel.backupCodes.isEmpty {
//                                backupCodes = viewModel.backupCodes
//                                showBackupCodes = true
//                            }
//                        }
//                    }
//                    .buttonStyle(.bordered)
//                    .disabled(viewModel.isLoading)
//                }
//            }
            
            if !viewModel.canEnableToggle {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    if !viewModel.isEmailVerified && !viewModel.isPhoneVerified {
                        Text("Please verify at least one of email or phone number to enable 2FA")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if viewModel.currentEmail.isEmpty && viewModel.currentPhone.isEmpty {
                        Text("Please enter at least one of email or phone number to enable 2FA")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Backup Codes Section
    private var backupCodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Backup Codes")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View Codes") {
                    backupCodes = viewModel.backupCodes
                    showBackupCodes = true
                }
                .buttonStyle(.bordered)
            }
            
            Text("Backup codes can be used to access your account if you lose access to your email or phone. Each code can only be used once.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Email OTP Overlay
    private var emailOTPView: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showEmailOTPView = false
                    }
                }
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Text("Verify Your Email")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("We've sent a 6-digit verification code to \(email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Enter 6-digit code", text: $emailOTP)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .onChange(of: emailOTP) { newValue in
                        let numericOnly = newValue.filter { $0.isNumber }
                        if numericOnly.count > 6 {
                            emailOTP = String(numericOnly.prefix(6))
                        } else {
                            emailOTP = numericOnly
                        }
                    }
                
                HStack(spacing: 12) {
                    Button("Verify") {
                        Task {
                            await viewModel.verifyEmailOTP(email: email, otp: emailOTP)
                            if viewModel.isEmailVerified {
                                showEmailOTPView = false
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
                    .disabled(emailOTP.count != 6 || viewModel.isLoading)
                    
                    Button("Resend") {
                        Task {
                            await viewModel.sendEmailVerificationCode(email: email)
                        }
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 16)
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(radius: 5)
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: showEmailOTPView)
    }
    
    // MARK: - Phone OTP Overlay
    private var phoneOTPView: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showPhoneOTPView = false
                    }
                }
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Text("Verify Your Phone")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("We've sent a 6-digit verification code to \(phoneNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Enter 6-digit code", text: $phoneOTP)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .onChange(of: phoneOTP) { newValue in
                        let numericOnly = newValue.filter { $0.isNumber }
                        if numericOnly.count > 6 {
                            phoneOTP = String(numericOnly.prefix(6))
                        } else {
                            phoneOTP = numericOnly
                        }
                    }
                
                HStack(spacing: 12) {
                    Button("Verify") {
                        Task {
                            let fullPhoneNumber = "\(countryCode)\(phoneNumber)"
                            await viewModel.verifyPhoneOTP(phoneNumber: fullPhoneNumber, otp: phoneOTP)
                            if viewModel.isPhoneVerified {
                                showPhoneOTPView = false
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
                    .disabled(phoneOTP.count != 6 || viewModel.isLoading)
                    
                    Button("Resend") {
                        Task {
                            let fullPhoneNumber = "\(countryCode)\(phoneNumber)"
                            await viewModel.sendPhoneVerificationCode(phoneNumber: fullPhoneNumber)
                        }
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 16)
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(radius: 5)
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: showPhoneOTPView)
    }
    
    // MARK: - Backup Codes Overlay
    private var backupCodesOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showBackupCodes = false
                    }
                }
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Text("Backup Codes")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Save these backup codes in a secure location. Each code can only be used once to access your account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(backupCodes, id: \.self) { code in
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("These codes are shown only once. Please save them securely.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                
                Button("I've Saved My Codes") {
                    showBackupCodes = false
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer().frame(height: 16)
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(radius: 5)
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: showBackupCodes)
    }
    

    
    private func loadCurrentSettings() {
        // Load current 2FA settings from the view model
        Task {
            await viewModel.loadCurrentSettings()
            
            // Update UI fields with loaded values
            if viewModel.isEmailVerified {
                email = viewModel.currentEmail
            }
            if viewModel.isPhoneVerified {
                // Extract phone number from full phone number (remove country code)
                let fullPhone = viewModel.currentPhone
                if fullPhone.hasPrefix("+91") {
                    countryCode = "+91"
                    phoneNumber = String(fullPhone.dropFirst(3))
                } else if fullPhone.hasPrefix("+1") {
                    countryCode = "+1"
                    phoneNumber = String(fullPhone.dropFirst(2))
                } else {
                    phoneNumber = fullPhone
                }
            }
        }
    }
}



#Preview {
    TwoFactorAuthenticationView()
}
