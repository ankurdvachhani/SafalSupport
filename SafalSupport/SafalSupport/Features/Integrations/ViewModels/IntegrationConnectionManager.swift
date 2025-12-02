import Foundation
import SwiftUI

class IntegrationConnectionManager: ObservableObject {
    @Published var integrations: [IntegrationItem] = []
    private let service = IntegrationsService()
    
    init() {
        loadInitialIntegrations()
        observeUserChanges()
    }
    
    private func loadInitialIntegrations() {
        integrations = [
            IntegrationItem(
                title: "Epic MyChart",
                description: "Connect your Epic MyChart account to sync your Drainage & Incident Activities.",
                icon: "epic",
                status: "Coming soon"
            ),
            IntegrationItem(
                title: "Patient Gateway",
                description: "Connect your Patient Gateway account to sync your Drainage & Incident Activities.",
                icon: "myepic",
                status: "Coming soon"
            ),
            IntegrationItem(
                title: "SafalCalendar",
                description: "Connect your SafalCalendar account to sync your Drainage Activities.",
                icon: "safalCalendar",
                status: "Development Server"
            )
        ]
        updateConnectionStatus()
    }
    
    private func observeUserChanges() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateConnectionStatus()
        }
    }
    
    func updateConnectionStatus() {
        Task {
            do {
                print("🔍 Fetching user extra data...")
                let extraData = try await service.fetchUserExtraData()
                print("🔍 User extra data received: \(extraData)")
                await MainActor.run {
                    updateIntegrationsWithExtraData(extraData.data)
                }
            } catch {
                print("❌ Error fetching user extra data: \(error)")
                await MainActor.run {
                    // If API call fails, reset all integrations to disconnected state
                    resetAllIntegrations()
                }
            }
        }
    }
    
    private func updateIntegrationsWithExtraData(_ data: UserExtraData) {
        print("🔍 Updating integrations with extra data...")
    //    print("🔍 Epic MyChart data: \(data.epicMyChart?.description ?? "nil")")
    //     print("🔍 SafalCalendar data: \(data.safalCalendar?.description ?? "nil")")
        
        // Force UI update notification
        objectWillChange.send()
        
        // Create a new array to trigger @Published update
        var updatedIntegrations = integrations
        
        // Update Epic MyChart connection status
        if let index = updatedIntegrations.firstIndex(where: { integration in integration.title == "Epic MyChart" }) {
            var item = updatedIntegrations[index]
            if let epicMyChart = data.epicMyChart {
                item.isConnected = true
                item.connectedUser = "\(epicMyChart.firstName) \(epicMyChart.lastName)"
                item.status = "Connected"
                print("✅ Epic MyChart connected: \(item.connectedUser ?? "")")
            } else {
                item.isConnected = false
                item.connectedUser = nil
                item.status = "Coming soon"
                print("❌ Epic MyChart disconnected")
            }
            updatedIntegrations[index] = item
        }
        
        // Update SafalCalendar connection status
        if let index = updatedIntegrations.firstIndex(where: { integration in integration.title == "SafalCalendar" }) {
            var item = updatedIntegrations[index]
            if let safalCalendar = data.safalCalendar {
                item.isConnected = true
                item.connectedUser = "\(safalCalendar.firstName) \(safalCalendar.lastName)"
                item.status = "Connected"
                print("✅ SafalCalendar connected: \(item.connectedUser ?? "")")
            } else {
                item.isConnected = false
                item.connectedUser = nil
                item.status = "Development Server"
                print("❌ SafalCalendar disconnected")
            }
            updatedIntegrations[index] = item
        }
        
        // Update the @Published property to trigger UI update
        integrations = updatedIntegrations
        
        // Force another UI update notification after assignment
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
            print("🔄 UI update triggered - integrations count: \(updatedIntegrations.count)")
            print("🔄 SafalCalendar isConnected: \(updatedIntegrations.first(where: { $0.title == "SafalCalendar" })?.isConnected ?? false)")
        }
        print("🔄 UI should update now with new integration status")
    }
    
    private func resetAllIntegrations() {
        var updatedIntegrations = integrations
        for index in updatedIntegrations.indices {
            var item = updatedIntegrations[index]
            item.isConnected = false
            item.connectedUser = nil
            if item.title == "Epic MyChart" {
                item.status = "Coming soon"
            } else if item.title == "SafalCalendar" {
                item.status = "Development Server"
            }
            updatedIntegrations[index] = item
        }
        integrations = updatedIntegrations
        print("🔄 Reset all integrations - UI should update")
    }
    
    // Function to handle disconnect response
    func handleDisconnectResponse(_ response: ConnectResponse, for integrationType: String) {
        if response.success {
            // Update UserDefaults with the new user data
            if let encodedData = try? JSONEncoder().encode(response.data) {
                UserDefaults.standard.set(encodedData, forKey: "currentUser")
            }
            // Update the UI immediately
            updateConnectionStatus()
        }
    }
    
    // Function to force UI update after disconnect
    func forceUIUpdate() {
        print("🔄 Forcing UI update...")
        updateConnectionStatus()
    }
} 
