import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @State private var isOrganization: Bool = false
    @State private var showTermsAndConditions = false
    @State private var showPrivacyPolicy = false
    @State private var showOTPView = false
    @State private var showShareIdView = false
    @State private var isCopied = false
    
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView

                    // Form Fields
                    formFields

                    termsAndPrivacyView

                    // Sign Up Button
                    signUpButton

                    // Sign In Link
                    signInLink
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .overlay(content: {
                    if showOTPView {
                        mailOtp
                    }
                    if showShareIdView {
                        organizationShareSheet
                    }
                })
            }
            .disabled(viewModel.isLoading)

//            if viewModel.isLoading {
//                progressView()
//            }
        }
        
        .withGradientBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(isOrganization ? "Organization Sign Up" : "Sign Up")
        .toast(message: $viewModel.errorMessage, type: .error)
        .toast(message: $viewModel.successMessage, type: .success)
        .toast(message: $viewModel.successMessageOTP, type: .success)
        .onChange(of: viewModel.mailverifyId) { _, _ in
            showOTPView = true
        }
        .onChange(of: viewModel.isRegistrationComplete) { _, _ in
            showOTPView = false
            if isOrganization && !viewModel.OrganizationShareId.isEmpty {
                showShareIdView = true
            } else {
                Task {
                    await delay(1.5) // ✅ proper async delay
                    NavigationManager.shared.dismiss()
                }
            }
        }
    }

    // MARK: - EMAIL OTP

    private var mailOtp: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showOTPView = false
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

                Text("We’ve sent a 6-digit verification code to your email.\nPlease enter it below to continue.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Enter 6-digit code", text: $viewModel.otp)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.verifyEmailOTP()
                        }
                    } label: {
                        Text("Submit")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }

                    Button {
                        Task {
                            await viewModel.sendMailVerificationCode(isOrganization: isOrganization)
                        }
                    } label: {
                        Text("Resend Code")
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            )
                    }
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
        .animation(.easeInOut, value: showOTPView)
    }
    
    private var organizationShareSheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        NavigationManager.shared.dismiss()
                    }
                }

            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Organization Share ID")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(spacing: 16) {
                    Text("Share this ID with doctors and nurses to join your organization:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack {
                        Text(viewModel.OrganizationShareId)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )

                        Button {
                            UIPasteboard.general.string = viewModel.OrganizationShareId
                            withAnimation {
                                isCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isCopied = false
                            }
                        } label: {
                            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundColor(isCopied ? .green : .accentColor)
                                .font(.system(size: 20))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(radius: 2)
                )

                Button {
                    withAnimation {
                        NavigationManager.shared.dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }

                Spacer().frame(height: 16)
            }
            .padding(.horizontal)
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
        .animation(.easeInOut, value: showShareIdView)
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            Image("Manual")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(isOrganization ? "Organization Sign Up" : "Sign Up")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.top, 40)
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: 16) {
            RolePicker(selectedRole: $viewModel.role, error: viewModel.validationError.role)
                .onChange(of: viewModel.role) { newRole in
                    isOrganization = (newRole == "Organization")
                    viewModel.clearForm()
                }


            // First Name
            CustomTextField(
                title: isOrganization ? "Organization Name*" : "First Name*",
                placeholder: isOrganization ? "Enter your organization name" : "Enter your First name",
                text: $viewModel.firstName,
                error: viewModel.validationError.firstName,
                isDisabled: viewModel.isDetailsFetched
            )

            // Last Name (for all roles except Organization)
            if !isOrganization {
                CustomTextField(
                    title: "Last Name*",
                    placeholder: "Enter your last name",
                    text: $viewModel.lastName,
                    error: viewModel.validationError.lastName,
                    isDisabled: viewModel.isDetailsFetched
                )
            }

            // Email
            CustomTextField(
                title: "Email*",
                placeholder: "Enter your email",
                text: $viewModel.email,
                error: viewModel.validationError.email
            )
            // Country Picker
            CountryPicker(
                selectedCountry: $viewModel.country,
                error: viewModel.validationError.country
            )
            .onChange(of: viewModel.country) { newValue in
                // Update country code and clear phone number when country changes
                switch newValue {
                case "IND":
                    viewModel.countryCode = "+91"
                case "USA":
                    viewModel.countryCode = "+1"
                default:
                    break
                }
            }

            if !isOrganization {
                // Phone Number (Optional)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone Number (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack(spacing: 12) {
                        // Country Code Picker
                        CountryCodePicker(
                            selectedCode: $viewModel.countryCode
                        )
                        .disabled(!viewModel.country.isEmpty)
                        .onChange(of: viewModel.countryCode) { _ in
                            viewModel.resetPhoneVerification()
                        }

                        // Phone Number TextField
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Enter phone number", text: $viewModel.phoneNumber)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .onChange(of: viewModel.phoneNumber) { _ in
                                    viewModel.resetPhoneVerification()
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            viewModel.validationError.phoneNumber == nil ? Color.gray.opacity(0.2) : Color.red,
                                            lineWidth: 1
                                        )
                                )

                            if let error = viewModel.validationError.phoneNumber {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }

                        // Verify Button or Verified Badge
                        if !viewModel.phoneNumber.isEmpty {
                            if viewModel.isPhoneVerified {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                }
                            } else {
                                Button {
                                    Task {
                                        await viewModel.sendVerificationCode()
                                    }
                                } label: {
                                    Text("Verify")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.accent)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                            }
                        }
                    }
                }

                // OTP Verification
                if viewModel.showOTPVerification && !viewModel.isPhoneVerified {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter Verification Code")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        TextField("Enter 6-digit code", text: $viewModel.otp)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )

                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    await viewModel.verifyOTP()
                                }
                            } label: {
                                Text("Submit")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.accent)
                                    .cornerRadius(8)
                            }
                            .disabled(viewModel.isLoading)

                            Button {
                                Task {
                                    await viewModel.sendVerificationCode()
                                }
                            } label: {
                                Text("Resend Code")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accent, lineWidth: 1)
                                    )
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Password
            CustomTextField(
                title: "Password*",
                placeholder: "Enter your password",
                text: $viewModel.password,
                error: viewModel.validationError.password,
                isSecure: true,
                showSecureText: $viewModel.showPassword
            )

            CustomTextField(
                title: "Confirm Password*",
                placeholder: "Confirm your password",
                text: $viewModel.confirmPassword,
                error: viewModel.validationError.confirmPassword,
                isSecure: true,
                showSecureText: $viewModel.showConfirmPassword
            )
        }
        .padding(.vertical, 20)
    }

    // MARK: - Terms and Privacy Policy

    private var termsAndPrivacyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Terms & Conditions
            Button {
                showTermsAndConditions.toggle()
            } label: {
                HStack {
                    Image(systemName: viewModel.agreeToTerms ? "checkmark.square.fill" : "square")
                        .foregroundColor(viewModel.agreeToTerms ? .accent : .gray)
                        .font(.system(size: 20))

                    Text("I agree to the")
                        .foregroundColor(.primary)

                    Text("Terms & Conditions")
                        .foregroundColor(.accent)
                }
            }
            .sheet(isPresented: $showTermsAndConditions) {
                PolicyView(
                    title: "Terms & Conditions",
                    content: viewModel.termsAndConditionsContent,
                    onAccept: {
                        viewModel.agreeToTerms = true
                    },
                    onReject: {
                        viewModel.agreeToTerms = false
                    }
                )
            }

            if let error = viewModel.validationError.termsAndConditions {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Privacy Policy
            Button {
                showPrivacyPolicy.toggle()
            } label: {
                HStack {
                    Image(systemName: viewModel.agreeToPrivacy ? "checkmark.square.fill" : "square")
                        .foregroundColor(viewModel.agreeToPrivacy ? .accent : .gray)
                        .font(.system(size: 20))

                    Text("I agree to the")
                        .foregroundColor(.primary)

                    Text("Privacy Policy")
                        .foregroundColor(.accent)
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PolicyView(
                    title: "Privacy Policy",
                    content: viewModel.privacyPolicyContent,
                    onAccept: {
                        viewModel.agreeToPrivacy = true
                    },
                    onReject: {
                        viewModel.agreeToPrivacy = false
                    }
                )
            }

            if let error = viewModel.validationError.privacyPolicy {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sign Up Button

    private var signUpButton: some View {
        Button {
            Task {
                await viewModel.sendMailVerificationCode(isOrganization: isOrganization)

                // await viewModel.signUp(isOrganization: isOrganization)
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accent.opacity(viewModel.canSignUp ? 1 : 0.5))
                    .cornerRadius(12)
            } else {
                Text("SIGN UP")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accent.opacity(viewModel.canSignUp ? 1 : 0.5))
                    .cornerRadius(12)
            }
        }
        .disabled(viewModel.isLoading || !viewModel.canSignUp)
    }

    // MARK: - Sign In Link

    private var signInLink: some View {
        HStack {
            Text("Already have an account?")
                .foregroundColor(.gray)
            Button("Sign In") {
                // Dismiss all presented views
                NavigationManager.shared.dismiss()
            }
            .foregroundColor(.accent)
        }
    }
}

// MARK: - Preview

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .withNavigation()
    }
}
