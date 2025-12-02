import SwiftUI
import MessageUI

struct ContactUsView: View {
    @State private var message = ""
    @State private var showingMailComposer = false
    @State private var showingCallAlert = false
    @State private var showingMessageSent = false
    @State private var showingMailAlert = false
    @State private var showingCallError = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userEmail = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    @StateObject private var profileViewModel = ProfileViewModel()
    
    // Contact information
    private let supportEmail = "support@safalvir.com"
    private let supportPhone = "+1-201-286-9941"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Contact Information
                contactInfoSection
                
                // Message Section
                messageSection
                
                // Send Message Button
                sendMessageButton
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Message Sent", isPresented: $showingMessageSent) {
            Button("OK") {
                message = ""
            }
        } message: {
            Text("Your message has been sent successfully. We'll get back to you within 24 to 48 hours.")
        }
        .alert("Mail Not Available", isPresented: $showingMailAlert) {
            Button("OK") { }
        } message: {
            Text("Mail app is not configured on this device. Please contact us at \(supportEmail)")
        }
        .alert("Call Not Available", isPresented: $showingCallError) {
            Button("OK") { }
        } message: {
            Text("Unable to make calls on this device. Please contact us at \(supportPhone)")
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposeView(
                recipients: [supportEmail],
                subject: "Support Request",
                messageBody: message
            )
        }
        .onAppear {
            Task {
                if let user = TokenManager.shared.loadCurrentUser() {
                    userEmail = user.email ?? ""
                     firstName = user.firstName ?? ""
                     lastName = user.lastName ?? ""
                    
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.dynamicAccent)
            
            Text("Get in Touch")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("We're here to help! Reach out to our support team for any questions or assistance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Contact Information Section
    private var contactInfoSection: some View {
        VStack(spacing: 16) {
            Text("Contact Information")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Email Contact
            contactRow(
                icon: "envelope.fill",
                title: "Email Support",
                subtitle: supportEmail,
                action: {
                    if MFMailComposeViewController.canSendMail() {
                        showingMailComposer = true
                    } else {
                        showingMailAlert = true
                    }
                }
            )
            
            // Phone Contact
            contactRow(
                icon: "phone.fill",
                title: "Phone Support",
                subtitle: supportPhone,
                action: {
                    if let url = URL(string: "tel://\(supportPhone.replacingOccurrences(of: "-", with: ""))") {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            showingCallError = true
                        }
                    } else {
                        showingCallError = true
                    }
                }
            )
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Message Section
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send us a Message")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Describe your issue or question, and we'll get back to you within 24 to 48 hours.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(minHeight: 120)
                
                if message.isEmpty {
                    Text("Type your message here...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $message)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Send Message Button
    private var sendMessageButton: some View {
        Button(action: {
            sendMessage()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isLoading ? "Sending..." : "Send Message")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(message.isEmpty || isLoading ? Color.gray : Color.dynamicAccent)
            )
        }
        .disabled(message.isEmpty || isLoading)
    }
    
    // MARK: - Contact Row Helper
    private func contactRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.dynamicAccent)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Send Message Function
    private func sendMessage() {
        guard !message.isEmpty else { return }
        guard !userEmail.isEmpty else {
            errorMessage = "User email not available"
            return
        }
        guard !firstName.isEmpty else {
            errorMessage = "User name not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let networkManager: NetworkManager = DIContainer.shared.resolve()
                let response = try await networkManager.sendContactMessage(
                    email: userEmail,
                    message: message,
                    firstName: firstName,
                    lastName: lastName
                )
                
                if response.success {
                    await MainActor.run {
                        isLoading = false
                        showingMessageSent = true
                        message = ""
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = response.message
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to send message: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Mail Compose View
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let messageBody: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(messageBody, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    NavigationView {
        ContactUsView()
    }
}
