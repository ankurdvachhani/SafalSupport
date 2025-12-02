import SwiftUI
import LocalAuthentication

struct BiometricSettingsView: View {
    @ObservedObject private var biometricService = BiometricAuthenticationService.shared
    @State private var showDisableAlert = false
    @State private var showEnableAlert = false
    
    var body: some View {
        List {
            // Biometric Status Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: biometricService.biometricType.iconName)
                        .font(.title2)
                        .foregroundColor(.dynamicAccent)
                        .frame(width: 32, height: 32)
                        .background(Color.dynamicAccent.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(biometricService.biometricType.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(biometricService.isBiometricAuthenticationEnabled() ? "Enabled" : "Disabled")
                            .font(.subheadline)
                            .foregroundColor(biometricService.isBiometricAuthenticationEnabled() ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if biometricService.isBiometricAvailable {
                        Toggle("", isOn: Binding(
                            get: { biometricService.isBiometricAuthenticationEnabled() },
                            set: { newValue in
                                if newValue {
                                    showEnableAlert = true
                                } else {
                                    showDisableAlert = true
                                }
                            }
                        ))
                        .tint(.dynamicAccent)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Biometric Authentication")
            } footer: {
                if biometricService.isBiometricAvailable {
                    Text("Use \(biometricService.biometricType.displayName) to sign in quickly and securely. Your credentials are encrypted and stored securely on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Biometric authentication is not available on this device. Please set up \(LAContext().biometryType == .faceID ? "Face ID" : "Touch ID") in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Information Section
            if biometricService.isBiometricAvailable {
                Section {
                    BioInfoRow(
                        icon: "shield.checkered",
                        title: "Security",
                        description: "Your credentials are encrypted using device-specific keys"
                    )
                    
                    BioInfoRow(
                        icon: "bolt.fill",
                        title: "Convenience",
                        description: "Sign in with just a touch or glance"
                    )
                    
                    BioInfoRow(
                        icon: "lock.fill",
                        title: "Privacy",
                        description: "Only you can access your saved credentials"
                    )
                } header: {
                    Text("Benefits")
                }
            }
            
            // Troubleshooting Section
            if biometricService.isBiometricAvailable {
                Section {
                    Button(action: {
                        // Test biometric authentication
                        Task {
                            let success = await biometricService.authenticateWithBiometrics(
                                reason: "Test \(biometricService.biometricType.displayName) authentication"
                            )
                            
                            if success {
                                // Show success message
                                print("Biometric test successful")
                            } else {
                                print("Biometric test failed")
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.dynamicAccent)
                            Text("Test \(biometricService.biometricType.displayName)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Troubleshooting")
                } footer: {
                    Text("Test your biometric authentication to ensure it's working properly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Biometric Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enable Biometric Authentication", isPresented: $showEnableAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Enable") {
                biometricService.enableBiometricAuthentication()
            }
        } message: {
            Text("This will enable \(biometricService.biometricType.displayName) authentication for quick sign-in.")
        }
        .alert("Disable Biometric Authentication", isPresented: $showDisableAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                biometricService.disableBiometricAuthentication()
            }
        } message: {
            Text("This will disable \(biometricService.biometricType.displayName) authentication. You'll need to sign in with your email and password.")
        }
    }
}

struct BioInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.dynamicAccent)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        BiometricSettingsView()
    }
}
