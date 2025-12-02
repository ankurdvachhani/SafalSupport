//
//  IntegrationLoginView.swift
//  SafalCalendar
//
//  Created by Apple on 24/06/25.
//

import SwiftUI
import Foundation


// MARK: - Login View
struct IntegrationLoginView: View {
    let integration: IntegrationItem
    @Binding var isPresented: Bool
    var onLoginSuccess: (() -> Void)?
    @State private var userId: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showConfirmation = false
    @State private var integrationId: String = ""
    @State private var userName: String = ""
    @State private var userImage: String? = ""
    private let service = IntegrationsService()
    
    private var isValidForm: Bool {
        !userId.isEmpty && password.count >= 6
    }
    
    private func handleLogin() {
        guard isValidForm else {
            showError = true
            errorMessage = "Please fill in all fields correctly"
            return
        }
        
        withAnimation {
            isLoading = true
            showError = false
        }
        
        Task {
            do {
                switch integration.title {
                case "Epic MyChart":
                    print("Epic MyChart")
                    let response = try await service.loginToEpicMyChart(email: userId, password: password)
                    await MainActor.run {
                        isLoading = false
                        if response.success {
                            integrationId = response.data.id
                            userName = "\(response.data.firstName) \(response.data.lastName)"
                            userImage = "" // Epic MyChart doesn't have profile image in the response
                            showConfirmation = true
                        } else {
                            showError = true
                            errorMessage = response.message
                        }
                    }
                case "SafalCalendar":
                    print("SafalCalendar")
                    let response = try await service.loginToSafalCalendar(email: userId, password: password)
                    await MainActor.run {
                        isLoading = false
                        if response.success {
                            integrationId = response.data.id
                            userName = "\(response.data.firstName) \(response.data.lastName)"
                            userImage = "" // SafalCalendar doesn't have profile image in the response
                            showConfirmation = true
                        } else {
                            showError = true
                            errorMessage = response.message
                        }
                    }
                default:
                    break
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    if let integrationError = error as? IntegrationError {
                        errorMessage = integrationError.message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func handleConnect() {
        Task {
            do {
                isLoading = true
                switch integration.title {
                case "Epic MyChart":
                    print("Epic MyChart")
                    // Create EpicMyChartUser object from stored data
                    let user = EpicMyChartUser(
                        id: integrationId,
                        firstName: userName.components(separatedBy: " ").first ?? "",
                        lastName: userName.components(separatedBy: " ").dropFirst().joined(separator: " "),
                        email: userId, // Using userId as email since that's what was entered
                        role: "User",
                        country: "USA",
                        profilePicture: nil
                    )
                    let response = try await service.connectEpicMyChart(user: user)
                    await MainActor.run {
                        isLoading = false
                        if response.success {
                            onLoginSuccess?()
                            isPresented = false
                        } else {
                            showError = true
                            errorMessage = response.message ?? ""
                        }
                    }
                case "SafalCalendar":
                    print("SafalCalendar")
                    // Create SafalCalendarUser object from stored data
                    let user = SafalCalendarUser(
                        id: integrationId,
                        firstName: userName.components(separatedBy: " ").first ?? "",
                        lastName: userName.components(separatedBy: " ").dropFirst().joined(separator: " "),
                        email: userId, // Using userId as email since that's what was entered
                        role: "User",
                        country: "USA",
                        profilePicture: nil
                    )
                    let response = try await service.connectSafalCalendar(user: user)
                    await MainActor.run {
                        isLoading = false
                        if response.success {
                            onLoginSuccess?()
                            isPresented = false
                        } else {
                            showError = true
                            errorMessage = response.message ?? ""
                        }
                    }
                default:
                    break
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            loginHeader
            loginDescription
            loginFields
            
            if showError {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            loginButtons
        }
        .padding(24)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .overlay(confirmationAlert)
    }
    
    private var loginHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Login to \(integration.title)")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Connect your account")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
        }
    }
    
    private var loginDescription: some View {
        HStack(spacing: 16) {
            Image(integration.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            if integration.title == "Epic MyChart" {
                Text("Login your \(integration.title) account to sync your Drainage & Incident Activities.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else if integration.title == "SafalCalendar" {
                Text("Login your \(integration.title) account to sync your Drainage Activities.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Login your \(integration.title) account to sync your events and data.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
    
    private var loginFields: some View {
        VStack(spacing: 16) {
            CustomIntegrationTextField(
                title: "Mail",
                placeholder: "Enter your mail id",
                text: $userId
            )
            
            CustomIntegrationTextField(
                title: "Password",
                placeholder: "Enter your password",
                text: $password,
                isSecure: true
            )
        }
    }
    
    private var loginButtons: some View {
        VStack(spacing: 12) {
            Button(action: handleLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isValidForm ? Color.dynamicAccent : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isValidForm || isLoading)
            
            Button(action: { isPresented = false }) {
                Text("Cancel")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var confirmationAlert: some View {
        if showConfirmation {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // ✅ USER IMAGE
                if let imageURL = URL(string: userImage ?? "") {
                       AsyncImage(url: imageURL) { image in
                           image
                               .resizable()
                               .scaledToFill()
                               .frame(width: 72, height: 72)
                               .clipShape(Circle())
                       } placeholder: {
                           Circle()
                               .fill(Color.gray.opacity(0.2))
                               .frame(width: 72, height: 72)
                               .overlay(
                                   ProgressView()
                               )
                       }
                   }
                VStack(spacing: 8) {
                    Text("Confirm Connection")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("Do you want to connect your \(integration.title) account?")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Account:")
                            .foregroundColor(.secondary)
                        Text(userName)
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 14))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)
                
                HStack(spacing: 12) {
                    Button(action: { showConfirmation = false }) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    
                    Button(action: handleConnect) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Connect")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.dynamicAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
        }
    }
}
