import Combine
import Foundation

struct VerifiedPhone: Hashable {
    let phone: String
    let id: String
}

// MARK: - Validation Error

struct ValidationError {
    var firstName: String?
    var lastName: String?
    var email: String?
    var phoneNumber: String?
    var password: String?
    var confirmPassword: String?
    var country: String?
    var termsAndConditions: String?
    var privacyPolicy: String?
    var role: String?
    var patientId: String?
    var organizationId: String?
    var NCPINumber:String?
    var hasErrors: Bool {
        firstName != nil ||
            lastName != nil ||
            email != nil ||
            password != nil ||
            confirmPassword != nil ||
            country != nil ||
            (phoneNumber != nil && !phoneNumber!.isEmpty) ||
            termsAndConditions != nil ||
            privacyPolicy != nil ||
            role != nil ||
            patientId != nil
    }
}

@MainActor
final class SignUpViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var country = "USA"
    @Published var role = "Individual" // Default role
    @Published var phoneNumber = ""
    @Published var patientId = ""
    @Published var patientMongoId = ""
    @Published var patientMongoORGId = ""
    @Published var organizationId = ""
    @Published var NCPINumber = ""
    @Published var countryCode = "+1" // Default to USA
    @Published var isPatientIdValid = false
    @Published var isOrganizationIdValid = false
    @Published var organizationMongoId = ""
    @Published var organizationName = ""
    @Published var otp = ""
    @Published var agreeToTerms = false
    @Published var agreeToPrivacy = false
    @Published var showPassword = false
    @Published var showConfirmPassword = false
    @Published var isLoading = false
    @Published var successMessage: String?
    @Published var successMessageOTP: String?
    @Published var errorMessage: String?
    @Published var isPhoneVerified = false
    @Published var showOTPVerification = false
    @Published var showTermsAndConditions = false
    @Published var showPrivacyPolicy = false
    @Published private var termsAndConditionsId = ""
    @Published private var privacyPolicyId = ""
    @Published private var termsOfServiceId = ""
    @Published var termsAndConditionsContent = ""
    @Published var privacyPolicyContent = ""
    @Published var termsOfServiceContent = ""
    @Published var isRegistrationComplete: Bool = false
    @Published var OrganizationShareId = ""
    @Published var isDetailsFetched: Bool = false

    // MARK: - Validation Properties

    @Published var validationError = ValidationError()

    // MARK: - Computed Properties

    var formattedPhoneNumber: String {
        guard !phoneNumber.isEmpty else { return "" }
        return String("\(countryCode)\(phoneNumber)".dropFirst())
    }

    var canSignUp: Bool {
        !firstName.isEmpty &&
            validationError.firstName == nil &&
            validationError.lastName == nil &&
            validationError.email == nil &&
            validationError.password == nil &&
            validationError.confirmPassword == nil &&
            validationError.country == nil &&
            validationError.phoneNumber == nil &&
            agreeToTerms &&
            agreeToPrivacy
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let networkManager: NetworkManager
    private let application = APIConfig.applicationId
    @Published private var verifyId: String = ""
    @Published var mailverifyId: String = ""
    private var verifiedPhoneNumbers: Set<VerifiedPhone> = []
    private var verificationId: String = ""

    // MARK: - Initialization

    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
        setupValidation()
        Task {
            await fetchPolicyData()
        }
    }

    // MARK: - Public Methods



    func signUp(isOrganization: Bool) async {
        // Validate organization name differently
        validateFirstName(firstName, isOrganization: isOrganization)

        // Rest of the validation
        validateLastName(lastName)
        validateEmail(email)
        validatePassword(password)
        validateConfirmPassword(password, confirmPassword)
        validateCountry(country)

        if !phoneNumber.isEmpty {
            validatePhoneNumber(phoneNumber)
        }

        // Check for validation errors
        if validationError.hasErrors ||
            (!isOrganization && !agreeToTerms) ||
            (!isOrganization && !agreeToPrivacy) {
            return
        }

        // Check if phone verification is required
        if !phoneNumber.isEmpty && !isPhoneVerified && !isCurrentNumberVerified() {
            errorMessage = "Please verify your phone number before signing up"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response: SignUpResponse
            if isOrganization {
                let request = OrganizationSignUpRequest(
                    firstName: firstName,
                    email: email,
                    password: password,
                    country: country,
                    phoneNumber: phoneNumber.isEmpty ? nil : formattedPhoneNumber,
                    termAndConditionsId: termsAndConditionsId,
                    privacyPolicyId: privacyPolicyId,
                    phoneNumberVerifyId: phoneNumber.isEmpty ? nil : verifyId
                )
                response = try await networkManager.signUpOrganization(request: request)
            } else {
                let request = UserSignUpRequest(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password,
                    confirmPassword: confirmPassword,
                    country: country,
                    termAndConditionsId: termsAndConditionsId,
                    privacyPolicyId: privacyPolicyId,
                    phoneNumber: phoneNumber.isEmpty ? nil : formattedPhoneNumber,
                    phoneNumberVerifyId: phoneNumber.isEmpty ? nil : verifyId,
                    emailVerifiedId: mailverifyId,
                    role: role,
                    metadata: [:]
                )
                response = try await networkManager.signUp(request: request, id: "", orgId: "")
            }

            isLoading = false
            if response.success ?? true {
                successMessage = response.message
                isRegistrationComplete = true
                if response.data?.role == "Organization" {
                    OrganizationShareId = response.data?.userSlug ?? ""
                }
                clearForm()
            } else {
                errorMessage = response.error ?? response.message ?? "Something went wrong"
            }
        } catch let error as NetworkError {
            isLoading = false
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func handleTermsAndPrivacyAgreement(termsId: String, privacyId: String) {
        termsAndConditionsId = termsId
        privacyPolicyId = privacyId
        agreeToTerms = true
        agreeToPrivacy = true
    }

    // MARK: - Private Methods

    private func validateInputs(isOrganization: Bool) -> Bool {
        validationError = ValidationError()

        // Common validations
        if firstName.isEmpty {
            validationError.firstName = isOrganization ? "Organization name is required" : "First name is required"
        }

        if !isOrganization && lastName.isEmpty {
            validationError.lastName = "Last name is required"
        }

        if email.isEmpty {
            validationError.email = "Email is required"
        } else if !isValidEmail(email) {
            validationError.email = "Please enter a valid email"
        }

        if password.isEmpty {
            validationError.password = "Password is required"
        } else if password.count < 8 {
            validationError.password = "Password must be at least 8 characters"
        }

        if confirmPassword.isEmpty {
            validationError.confirmPassword = "Please confirm your password"
        } else if password != confirmPassword {
            validationError.confirmPassword = "Passwords do not match"
        }

        if country.isEmpty {
            validationError.country = "Please select a country"
        }


        if role.isEmpty {
            validationError.role = "Please select a role"
        }

        if !agreeToTerms {
            validationError.termsAndConditions = "Please agree to the Terms and Conditions"
        }

        if !agreeToPrivacy {
            validationError.privacyPolicy = "Please agree to the Privacy Policy"
        }

        if agreeToTerms && termsAndConditionsId.isEmpty {
            validationError.termsAndConditions = "Please review and accept the Terms and Conditions"
        }

        if agreeToPrivacy && privacyPolicyId.isEmpty {
            validationError.privacyPolicy = "Please review and accept the Privacy Policy"
        }

        return !validationError.hasErrors
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

        func clearForm() {
        firstName = ""
        lastName = ""
        email = ""
        password = ""
        confirmPassword = ""
        country = ""
        phoneNumber = ""
        otp = ""
        agreeToTerms = false
        agreeToPrivacy = false
        isPhoneVerified = false
        showOTPVerification = false
        isDetailsFetched = false
        
    }

    private func setupValidation() {
        // First Name Validation
        $firstName
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.validateFirstName(name)
            }
            .store(in: &cancellables)

        
        // Last Name Validation
        $lastName
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.validateLastName(name)
            }
            .store(in: &cancellables)
        

        // Email Validation
        $email
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] email in
                self?.validateEmail(email)
            }
            .store(in: &cancellables)

        // Phone Number Validation
        $phoneNumber
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] number in
                self?.validatePhoneNumber(number)
            }
            .store(in: &cancellables)

        // Password Validation
        $password
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] password in
                self?.validatePassword(password)
            }
            .store(in: &cancellables)

        // Confirm Password Validation
        Publishers.CombineLatest($password, $confirmPassword)
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] password, confirmPassword in
                self?.validateConfirmPassword(password, confirmPassword)
            }
            .store(in: &cancellables)

        // Country Validation
        $country
            .dropFirst()
            .sink { [weak self] country in
                self?.validateCountry(country)
            }
            .store(in: &cancellables)

        $role
            .dropFirst()
            .sink { [weak self] country in
                self?.validateRole(country)
            }
            .store(in: &cancellables)

        // Clear error messages after 3 seconds
        $errorMessage
            .dropFirst()
            .filter { $0 != nil }
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.errorMessage = nil
            }
            .store(in: &cancellables)

        $successMessage
            .dropFirst()
            .filter { $0 != nil }
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.successMessage = nil
            }
            .store(in: &cancellables)
    }

    private func validateFirstName(_ name: String, isOrganization: Bool = false) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            validationError.firstName = isOrganization ? "Organization name is required" : "First name is required"
        } else if !isOrganization && (name.hasPrefix(" ") || name.hasSuffix(" ")) {
            validationError.firstName = "First name cannot start or end with spaces"
        } else {
            validationError.firstName = nil
        }
    }

    
    

    private func validateLastName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if !name.isEmpty {
            if name.hasPrefix(" ") || name.hasSuffix(" ") {
                validationError.lastName = "Last name cannot start or end with spaces"
            } else {
                validationError.lastName = nil
            }
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

    private func validatePhoneNumber(_ number: String) {
        // Remove any non-numeric characters
        let numericOnly = number.filter { $0.isNumber }

        // If the number has changed, update it with numeric-only version
        if numericOnly != number {
            DispatchQueue.main.async {
                self.phoneNumber = numericOnly
            }
        }

        if !number.isEmpty {
            if numericOnly.count > 10 {
                DispatchQueue.main.async {
                    self.phoneNumber = String(numericOnly.prefix(10))
                }
            }

            if numericOnly.count < 10 {
                validationError.phoneNumber = "Phone number must be 10 digits"
            } else {
                validationError.phoneNumber = nil
                // Check if this is a previously verified number
                if isCurrentNumberVerified() {
                    isPhoneVerified = true
                    showOTPVerification = false
                }
            }
        } else {
            validationError.phoneNumber = nil
        }
    }

    private func validatePassword(_ password: String) {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedPassword.isEmpty {
            validationError.password = "Password is required"
        } else if trimmedPassword != password {
            validationError.password = "Password cannot contain spaces"
        } else if password.count < 8 {
            validationError.password = "Password must be at least 8 characters"
        } else {
            validationError.password = nil
        }

        // Also validate confirm password when password changes
        if !confirmPassword.isEmpty {
            validateConfirmPassword(password, confirmPassword)
        }
    }

    private func validateConfirmPassword(_ password: String, _ confirmPassword: String) {
        if confirmPassword.isEmpty {
            validationError.confirmPassword = "Please confirm your password"
        } else if confirmPassword != password {
            validationError.confirmPassword = "Passwords do not match"
        } else {
            validationError.confirmPassword = nil
        }
    }

    private func validateCountry(_ country: String) {
        if country.isEmpty {
            validationError.country = "Please select your country"
        } else {
            validationError.country = nil
        }
    }

    private func validateRole(_ country: String) {
        if country.isEmpty {
            validationError.role = "Please select your role"
        } else {
            validationError.role = nil
        }
    }

    // MARK: - Phone Verification Methods

    func resetPhoneVerification() {
        // Check if current number is already verified
        let currentNumber = "\(countryCode)\(phoneNumber)"
        if verifiedPhoneNumbers.contains(where: { $0.phone == currentNumber }) {
            isPhoneVerified = true
            showOTPVerification = false
            return
        }

        // If not verified, reset everything
        showOTPVerification = false
        isPhoneVerified = false
        otp = ""
        verifyId = ""
    }

    func sendVerificationCode() async {
        guard validatePhoneNumber() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkManager.sendCodeForVerification(
                type: "PhoneNumber",
                value: formattedPhoneNumber, phoneNumber: "",
                isSendRequest: true
            )

            isLoading = false

            if response.success ?? false {
                verifyId = response.verifyId ?? ""
                showOTPVerification = true
                successMessageOTP = response.message ?? "Verification code sent to your phone"
            } else {
                errorMessage = response.message ?? "Failed to send verification code"
            }
        } catch let error as NetworkError {
            isLoading = false
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func sendMailVerificationCode(isOrganization:Bool) async {
        guard validateEmail() else { return }
        validateFirstName(firstName, isOrganization: isOrganization)

        // Rest of the validation
        validateLastName(lastName)
        validateEmail(email)
        validatePassword(password)
        validateConfirmPassword(password, confirmPassword)
        validateCountry(country)

        if !phoneNumber.isEmpty {
            validatePhoneNumber(phoneNumber)
        }


        // Check if phone verification is required
        if !phoneNumber.isEmpty && !isPhoneVerified && !isCurrentNumberVerified() {
            errorMessage = "Please verify your phone number before signing up"
            return
        }
        // set validateInputs
        guard validateInputs(isOrganization: isOrganization) else { return }
        
        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkManager.sendCodeForVerification(
                type: "Email",
                value: email, phoneNumber: "",
                isSendRequest: true
            )

            isLoading = false

            if response.success ?? false {
                mailverifyId = response.verifyId ?? ""
                // showOTPVerification = true
                successMessageOTP = response.message ?? "Verification code sent to your phone"
            } else {
                errorMessage = response.message ?? "Failed to send verification code"
            }
        } catch let error as NetworkError {
            isLoading = false
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func verifyEmailOTP() async {
        guard validateOTP() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkManager.sendCodeForVerification(
                type: otp,
                value: mailverifyId,
                phoneNumber: email,
                isSendRequest: false
            )

            isLoading = false

            if response.success ?? false {
                await signUp(isOrganization: false)

                // successMessageOTP = response.message ?? "Email verified successfully"
            } else {
                errorMessage = response.message ?? "Invalid verification code"
            }
        } catch let error as NetworkError {
            isLoading = false
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func verifyOTP() async {
        guard validateOTP() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await networkManager.sendCodeForVerification(
                type: otp,
                value: verifyId,
                phoneNumber: formattedPhoneNumber,
                isSendRequest: false
            )

            isLoading = false

            if response.success ?? false {
                showOTPVerification = false
                isPhoneVerified = true
                // Add the verified number to our set
                verifiedPhoneNumbers.insert(VerifiedPhone(phone: formattedPhoneNumber, id: verifyId))
                verificationId = verifyId
                successMessageOTP = response.message ?? "Phone number verified successfully"
            } else {
                errorMessage = response.message ?? "Invalid verification code"
            }
        } catch let error as NetworkError {
            isLoading = false
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Validation Methods

    private func validatePhoneNumber() -> Bool {
        validationError.phoneNumber = nil

        if phoneNumber.isEmpty {
            validationError.phoneNumber = "Phone number is required for verification"
            return false
        }

        // Basic phone number validation (can be enhanced)
        if phoneNumber.count < 10 {
            validationError.phoneNumber = "Please enter a valid phone number"
            return false
        }

        return true
    }

    private func validateEmail() -> Bool {
        validationError.email = nil

        if email.isEmpty {
            validationError.email = "Email is required for verification"
            return false
        }

        // Basic email format validation using regex
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !predicate.evaluate(with: email) {
            validationError.email = "Please enter a valid email address"
            return false
        }

        return true
    }

    private func validateOTP() -> Bool {
        if otp.isEmpty {
            errorMessage = "Please enter the verification code"
            return false
        }

        if otp.count != 6 {
            errorMessage = "Please enter a valid verification code"
            return false
        }

        return true
    }

    private func fetchPolicyData() async {
        do {
            // Fetch Terms & Conditions
            let termsResponse = try await networkManager.fetchPolicyData(
                type: "TermsAndConditions",
                application: application
            )
            termsAndConditionsContent = termsResponse.data.content ?? ""
            termsAndConditionsId = termsResponse.data.id ?? ""

            // Fetch Privacy Policy
            let privacyResponse = try await networkManager.fetchPolicyData(
                type: "PrivacyPolicy",
                application: application
            )
            privacyPolicyContent = privacyResponse.data.content ?? ""
            privacyPolicyId = privacyResponse.data.id ?? ""

            // Fetch Terms of Service
            do {
                let termsOfServiceResponse = try await networkManager.fetchPolicyData(
                    type: "TermsOfService",
                    application: application
                )
                termsOfServiceContent = termsOfServiceResponse.data.content ?? ""
                termsOfServiceId = termsOfServiceResponse.data.id ?? ""
            } catch {
                // If TermsOfService is not available, use TermsAndConditions as fallback
                termsOfServiceContent = termsAndConditionsContent
                termsOfServiceId = termsAndConditionsId
            }

        } catch {
            errorMessage = "Failed to load policy data"
        }
    }

    // Add method to check if current number is verified
    private func isCurrentNumberVerified() -> Bool {
        let currentNumber = "\(countryCode)\(phoneNumber)"
        if verifiedPhoneNumbers.contains(where: { $0.phone == currentNumber }) {
            if let match = verifiedPhoneNumbers.first(where: { $0.phone == currentNumber }) {
                verifyId = match.id
            }
        }
        return verifiedPhoneNumbers.contains(where: { $0.phone == currentNumber })
    }
}
