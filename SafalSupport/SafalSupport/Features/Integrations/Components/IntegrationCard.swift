//
//  IntegrationCard.swift
//  SafalCalendar
//
//  Created by Apple on 24/06/25.
//
import SwiftUI
import Foundation

// MARK: - Integration Card
struct IntegrationCard: View {
    let integration: IntegrationItem
    @Binding var showLoginPopup: Bool
    @Binding var selectedIntegration: IntegrationItem?
    @ObservedObject var connectionManager: IntegrationConnectionManager
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showDisconnectConfirmation = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    private let service = IntegrationsService()
    
    private func handleDisconnect() {
        Task {
            isLoading = true
            do {
                switch integration.title {
                case "Epic MyChart":
                    print("Epic MyChart")
                    let response = try await service.disconnectEpicMyChart()
                    await MainActor.run {
                        isLoading = false
                        if response.success {
                            showDisconnectConfirmation = false
                            connectionManager.forceUIUpdate()
                        } else {
                            showError = true
                            errorMessage = response.message ?? ""
                        }
                    }
                case "SafalCalendar":
                    print("SafalCalendar")
                    let response = try await service.disconnectSafalCalendar()
                    await MainActor.run {
                        isLoading = false
                        if response.success {
                            showDisconnectConfirmation = false
                            connectionManager.forceUIUpdate()
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
                    if let integrationError = error as? IntegrationError {
                        errorMessage = integrationError.message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Icon
            Image(integration.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Title and Status
            VStack(spacing: 8) {
                Text(integration.title)
                    .font(.system(size: 24, weight: .semibold))
                
                if integration.isConnected {
                    Text("Connected")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(20)
                    
                    if let userName = integration.connectedUser {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to \(userName)")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 4)
                    }
                } else if !integration.status.isEmpty {
                    Text(integration.status)
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)
                }
            }
            
            // Description
            Text(integration.description)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            // Connect/Disconnect Button
            Button(action: {
                if integration.isConnected {
                    showDisconnectConfirmation = true
                } else {
                   // if integration.title != "Epic MyChart"{
                        selectedIntegration = integration
                        showLoginPopup = true
                   // }
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(integration.isConnected ? "Disconnect" : "Connect")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(buttonColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(integration.status == "Coming soon" || isLoading)
            
            if showError {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .confirmationDialog(
            "Disconnect \(integration.title)?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive, action: handleDisconnect)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to disconnect from \(integration.title)? This will remove all synced data.")
        }
    }
    
    private var buttonColor: Color {
        if integration.status == "Coming soon" {
            return Color(.systemGray4)
        }
        return integration.isConnected ? .red : Color(red: 0, green: 0.8, blue: 0.7) // Turquoise color for connect
    }
}
