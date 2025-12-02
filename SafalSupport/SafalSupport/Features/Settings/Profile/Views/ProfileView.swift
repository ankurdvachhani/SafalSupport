import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isEditMode = false
    @State private var firstName: String = ""
    @State private var profileImage: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var countryCode: String = "+1"
    @State private var country: String = ""
    @State private var ncpiNumber: String = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showImagePicker = false
    @State private var showImageSourcePicker = false
    @State private var selectedImage: UIImage?
    @State private var isImageChanged = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showEmailOTPView = false
    @State private var showPhoneOTPView = false
    
    var body: some View {
        ZStack {
            Group {
                if viewModel.isLoading && viewModel.profile.firstName.isEmpty {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isEditMode {
                            // Save changes
                            Task {
                                var imagePath: String? = nil
                                
                                // Only upload image if it was changed
                                if isImageChanged, let image = selectedImage {
                                    imagePath = try await viewModel.uploadImage(image)
                                    if let path = imagePath {
                                        imagePath = String(path.dropFirst())
                                        print("Image uploaded successfully, path: \(imagePath!)")
                                    }
                                }
                                
                                let fullPhoneNumber = phoneNumber.isEmpty ? "" : "\(countryCode)\(phoneNumber)"
                                await viewModel.updateProfile(
                                    firstName: firstName,
                                    lastName: lastName,
                                    email: email,
                                    phoneNumber: fullPhoneNumber,
                                    country: country,
                                    profilePicture: imagePath ?? "",
                                    ncpiNumber: ncpiNumber.isEmpty ? nil : ncpiNumber
                                )
                                if viewModel.errorMessage == nil {
                                    // Update the stored user name in TokenManager
                                    TokenManager.shared.updateUserName(firstName: firstName, lastName: lastName)
                                    isEditMode = false
                                    isImageChanged = false
                                }
                            }
                        } else {
                            // Enter edit mode
                            firstName = viewModel.profile.firstName
                            lastName = viewModel.profile.lastName
                            email = viewModel.profile.email
                            country = viewModel.profile.country
                            ncpiNumber = viewModel.profile.ncpiNumber ?? ""
                            
                            // Set phone number and country code based on profile phone number
                            let profilePhone = viewModel.profile.phoneNumber
                            let country = viewModel.profile.country

                            switch country.uppercased() {
                            case "IND":
                                countryCode = "+91"
                                phoneNumber = String(profilePhone.dropFirst(2)) // Drops "+91"

                            case "USA":
                                countryCode = "+1"
                                phoneNumber = String(profilePhone.dropFirst(1)) // Drops "+1"

                            default:
                                countryCode = ""
                                phoneNumber = profilePhone // Keep full number if country is unknown
                            }
                            
                            
                            selectedImage = nil
                            isImageChanged = false
                            isEditMode = true
                        }
                    }) {
                        if viewModel.isLoading && isEditMode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .scaleEffect(0.8)
                        } else {
                            Text(isEditMode ? "Save" : "Edit")
                                .foregroundColor(isEditMode && !viewModel.canSave ? .gray : .accentColor)
                        }
                    }
                    .disabled(isEditMode && (!viewModel.canSave || viewModel.isLoading))
                }
                
                if isEditMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isEditMode = false
                            // Reset fields
                            firstName = viewModel.profile.firstName
                            lastName = viewModel.profile.lastName
                            email = viewModel.profile.email
                            ncpiNumber = viewModel.profile.ncpiNumber ?? ""
                            
                            // Set phone number and country code based on profile phone number
                            let profilePhone = viewModel.profile.phoneNumber
                            let country = viewModel.profile.country

                            switch country.uppercased() {
                            case "IND":
                                countryCode = "+91"
                                phoneNumber = String(profilePhone.dropFirst(2)) // Drops "+91"

                            case "USA":
                                countryCode = "+1"
                                phoneNumber = String(profilePhone.dropFirst(1)) // Drops "+1"

                            default:
                                countryCode = ""
                                phoneNumber = profilePhone // Keep full number if country is unknown
                            }
                           
                            
                           
                            selectedImage = nil
                            isImageChanged = false
                            viewModel.resetPhoneVerification()
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            
            // Loading overlay
            if viewModel.isLoading && isEditMode {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Saving changes...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    )
            }
        }
        
//        .refreshable {
//            await viewModel.fetchProfile()
//        }
        .onChange(of: viewModel.errorMessage) { newValue in
            errorMessage = newValue
        }
        .onChange(of: viewModel.successMessage) { newValue in
            successMessage = newValue
        }
        .toast(message: $errorMessage, type: .error)
        .toast(message: $successMessage, type: .success)
        .toast(message: $viewModel.successMessageOTP, type: .success)
        .disabled(viewModel.isLoading && isEditMode)
        .sheet(isPresented: $showImagePicker) {
            if sourceType == .camera {
                profileImagePicker(image: $selectedImage, isImageChanged: $isImageChanged, sourceType: sourceType)
            } else {
                profilePhotosPicker(image: $selectedImage, isImageChanged: $isImageChanged)
            }
        }
        .actionSheet(isPresented: $showImageSourcePicker) {
            ActionSheet(
                title: Text("Select Photo"),
                message: Text("Choose a source for your profile photo"),
                buttons: [
                    .default(Text("Camera")) {
                        sourceType = .camera
                        showImagePicker = true
                    },
                    .default(Text("Photo Library")) {
                        sourceType = .photoLibrary
                        showImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - EMAIL OTP MODAL
    private var emailOTPModal: some View {
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

                Text("We've sent a 6-digit verification code to your email.\nPlease enter it below to continue.")
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
                    .onChange(of: viewModel.otp) { newValue in
                        // Remove any non-numeric characters
                        let numericOnly = newValue.filter { $0.isNumber }
                        
                        // If the OTP has changed, update it with numeric-only version
                        if numericOnly != newValue {
                            DispatchQueue.main.async {
                                viewModel.otp = numericOnly
                            }
                        }
                        
                        // Limit to 6 digits
                        if numericOnly.count > 6 {
                            DispatchQueue.main.async {
                                viewModel.otp = String(numericOnly.prefix(6))
                            }
                        }
                    }

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.verifyEmailOTP(email: email)
                            if viewModel.isEmailVerified {
                                withAnimation {
                                    showEmailOTPView = false
                                }
                            }
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
                            await viewModel.sendEmailVerificationCode(email: email)
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
        .animation(.easeInOut, value: showEmailOTPView)
    }
    
    // MARK: - PHONE OTP MODAL
    private var phoneOTPModal: some View {
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

                Text("Verify Your Phone Number")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("We've sent a 6-digit verification code to your phone.\nPlease enter it below to continue.")
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
                    .onChange(of: viewModel.otp) { newValue in
                        // Remove any non-numeric characters
                        let numericOnly = newValue.filter { $0.isNumber }
                        
                        // If the OTP has changed, update it with numeric-only version
                        if numericOnly != newValue {
                            DispatchQueue.main.async {
                                viewModel.otp = numericOnly
                            }
                        }
                        
                        // Limit to 6 digits
                        if numericOnly.count > 6 {
                            DispatchQueue.main.async {
                                viewModel.otp = String(numericOnly.prefix(6))
                            }
                        }
                    }

                HStack(spacing: 12) {
                    Button {
                        Task {
                            let fullPhoneNumber = "\(countryCode)\(phoneNumber)".dropFirst()
                            await viewModel.verifyOTP(phoneNumber: String(fullPhoneNumber))
                            if viewModel.isPhoneVerified {
                                withAnimation {
                                    showPhoneOTPView = false
                                }
                            }
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
                            let fullPhoneNumber = "\(countryCode)\(phoneNumber)".dropFirst()
                            await viewModel.sendVerificationCode(phoneNumber: String(fullPhoneNumber))
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
        .animation(.easeInOut, value: showPhoneOTPView)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading profile...")
                .foregroundColor(.secondary)
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeaderSection
                
                if isEditMode {
                    EditableFieldsView(
                        firstName: $firstName,
                        lastName: $lastName,
                        email: $email,
                        phoneNumber: $phoneNumber,
                        countryCode: $countryCode,
                        country: $country,
                        ncpiNumber: $ncpiNumber,
                        viewModel: viewModel,
                        validationError: viewModel.validationError,
                        showEmailOTPView: $showEmailOTPView,
                        showPhoneOTPView: $showPhoneOTPView
                    )
                } else {
                    ProfileDetailsView(profile: viewModel.profile)
                }
            }
            .overlay(content: {
                if showEmailOTPView {
                    emailOTPModal
                }
                if showPhoneOTPView {
                    phoneOTPModal
                }
            })
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Image with edit button overlay
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Group {
                            profileImageView
                        }
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                
                if isEditMode {
                    editButton
                }
            }
            
            nameAndEmailSection
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
    }
    
    private var profileImageView: some View {
        Group {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let profilePictureUrl = viewModel.profile.profilePictureUrl,
                      !profilePictureUrl.isEmpty {
                AsyncImage(url: URL(string: profilePictureUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        defaultProfileImage
                    case .empty:
                        ProgressView()
                    @unknown default:
                        defaultProfileImage
                    }
                }
            } else {
                defaultProfileImage
            }
        }
    }
    
    private var defaultProfileImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .foregroundColor(.gray)
    }
    
    private var editButton: some View {
        Button(action: {
            showImageSourcePicker = true
        }) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                )
        }
        .offset(x: 40, y: 40)
    }
    
    private var nameAndEmailSection: some View {
        VStack(spacing: 8) {
            
           
            if isEditMode {
                Text("\(firstName) \(lastName)")
                    .font(.title2)
                    .fontWeight(.semibold)
            } else {
                Text(viewModel.profile.firstName + " " + viewModel.profile.lastName)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 8) {
                Text(viewModel.profile.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.profile.isEmailVerified {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                }
            }
            Text(viewModel.profile.role)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Editable Fields View
struct EditableFieldsView: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var phoneNumber: String
    @Binding var countryCode: String
    @Binding var country: String
    @Binding var ncpiNumber: String
    @ObservedObject var viewModel: ProfileViewModel
    let validationError: ProfileValidationError
    @Binding var showEmailOTPView: Bool
    @Binding var showPhoneOTPView: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            personalInformationSection
            contactInformationSection
        }
        .padding(16)
    }
    
    private var personalInformationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Personal Information")
            
            VStack(spacing: 16) {
                CustomTextField(
                    title: "First Name*",
                    placeholder: "Enter your first name",
                    text: Binding(
                        get: { firstName },
                        set: { newValue in
                            firstName = newValue
                            viewModel.profile.firstName = newValue
                        }
                    ),
                    error: validationError.firstName
                )
                
                CustomTextField(
                    title: "Last Name*",
                    placeholder: "Enter your last name",
                    text: Binding(
                        get: { lastName },
                        set: { newValue in
                            lastName = newValue
                            viewModel.profile.lastName = newValue
                        }
                    ),
                    error: validationError.lastName
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email*")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        TextField("Enter your email", text: Binding(
                            get: { email },
                            set: { newValue in
                                email = newValue
                                viewModel.profile.email = newValue
                                if !newValue.isEmpty {
                                    viewModel.resetEmailVerification()
                                }
                            }
                        ))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    validationError.email == nil ? Color.gray.opacity(0.2) : Color.red,
                                    lineWidth: 1
                                )
                        )
                        
                        // Verify Button or Verified Badge
                        if !email.isEmpty && viewModel.isValidEmail(email) {
                            Group {
                                if viewModel.isEmailVerified || !viewModel.needsEmailVerification(email: email) {
                                    // Show verified badge
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    }
                                } else {
                                    // Show verify button
                                    Button {
                                        Task {
                                            await viewModel.sendEmailVerificationCode(email: email)
                                            if viewModel.successMessageOTP != nil {
                                                withAnimation {
                                                    showEmailOTPView = true
                                                }
                                            }
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
                    
                    if let error = validationError.email {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // NCPI Number field (only for non-Patient roles)
                if viewModel.profile.role != "Patient" {
                    CustomTextField(
                        title: "NCPI Number*",
                        placeholder: "Enter your NCPI Number",
                        text: Binding(
                            get: { ncpiNumber },
                            set: { newValue in
                                ncpiNumber = newValue
                                viewModel.profile.ncpiNumber = newValue
                            }
                        ),
                        error: validationError.ncpiNumber
                    )
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
    

    
    private var contactInformationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Contact Information")
            
            VStack(spacing: 16) {
                

                CountryPicker(
                    selectedCountry: $country,
                    error: validationError.country
                )
                .onChange(of: country) { newValue in
                    // Update country code and clear phone number when country changes
                    switch newValue {
                    case "IND":
                        countryCode = "+91"
                    case "USA":
                        countryCode = "+1"
                    default:
                        break
                    }
                    
                    // Clear phone number when country changes
                    if !phoneNumber.isEmpty {
                        phoneNumber = ""
                        viewModel.resetPhoneVerification()
                    }
                }
                
                phoneNumberField
                
               
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
    
    private var phoneNumberField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Phone Number (Optional)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                CountryCodePicker(
                    selectedCode: $countryCode
                )
                .disabled(!country.isEmpty) // Disable when country is selected
                .onChange(of: countryCode) { _ in
                    if !phoneNumber.isEmpty {
                        viewModel.resetPhoneVerification()
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Enter phone number", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .onChange(of: phoneNumber) { newValue in
                            // Remove any non-numeric characters
                            let numericOnly = newValue.filter { $0.isNumber }
                            
                            // If the number has changed, update it with numeric-only version
                            if numericOnly != newValue {
                                DispatchQueue.main.async {
                                    phoneNumber = numericOnly
                                }
                            }
                            
                            // Limit to 10 digits
                            if numericOnly.count > 10 {
                                DispatchQueue.main.async {
                                    phoneNumber = String(numericOnly.prefix(10))
                                }
                            }
                            
                            // Reset verification if number changes
                            if !numericOnly.isEmpty && numericOnly != viewModel.profile.phoneNumber {
                                viewModel.resetPhoneVerification()
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    validationError.phoneNumber == nil ? Color.gray.opacity(0.2) : Color.red,
                                    lineWidth: 1
                                )
                        )
                    
                    if let error = validationError.phoneNumber {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Verify Button or Verified Badge
                if phoneNumber.count >= 10 {
                    Group {
                        if viewModel.isPhoneVerified || !viewModel.needsVerification(phoneNumber: phoneNumber) {
                            // Show verified badge
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            }
                        } else {
                            // Show verify button
                            Button {
                                Task {
                                    let fullPhoneNumber = "\(countryCode)\(phoneNumber)".dropFirst()
                                    await viewModel.sendVerificationCode(phoneNumber: String(fullPhoneNumber))
                                    if viewModel.successMessageOTP != nil {
                                        withAnimation {
                                            showPhoneOTPView = true
                                        }
                                    }
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
        }
    }
    

    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - Profile Details View
struct ProfileDetailsView: View {
    let profile: ProfileData
    
    var body: some View {
        VStack(spacing: 16) {
            personalInformationSection
            contactInformationSection
        }
        .padding(16)
    }
    
    private var personalInformationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Personal Information")
            
            VStack(spacing: 0) {
                detailRow("First Name", value: profile.firstName)
                Divider()
                detailRow("Last Name", value: profile.lastName)
                Divider()
                detailRow("Email", value: profile.email, isVerified: profile.isEmailVerified)
                
                // NCPI Number (only for non-Patient roles)
                if profile.role != "Patient" {
                    Divider()
                    detailRow("NCPI Number", value: profile.ncpiNumber ?? "Not set")
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
    
    private var contactInformationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Contact Information")
            
            VStack(spacing: 0) {
                detailRow("Country", value: profile.country)
                if !profile.phoneNumber.isEmpty {
                    detailRow("Phone", value: profile.phoneNumber)
                    Divider()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
    
    private func detailRow(_ title: String, value: String, isVerified: Bool? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    let displayValue = value.isEmpty ? "Not set" : getDisplayValue(title: title, value: value)
                    Text(displayValue)
                        .font(.body)
                    
                    if let isVerified = isVerified {
                        Image(systemName: isVerified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(isVerified ? .green : .orange)
                            .font(.system(size: 14))
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    private func getDisplayValue(title: String, value: String) -> String {
        if title == "Country" {
            switch value {
            case "IND":
                return "India"
            case "USA":
                return "United States"
            default:
                return value
            }
        }
        return value
    }
}

// Image Picker using UIKit
struct profileImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isImageChanged: Bool
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: profileImagePicker
        
        init(_ parent: profileImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.isImageChanged = true
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// Photos Picker using PhotosUI
struct profilePhotosPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isImageChanged: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        let parent: profilePhotosPicker
        
        init(_ parent: profilePhotosPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                        self.parent.isImageChanged = true
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
    }
} 
