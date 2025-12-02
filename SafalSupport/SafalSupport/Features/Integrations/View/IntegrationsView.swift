//
//  IntegrationLoginView.swift
//  SafalCalendar
//
//  Created by Apple on 24/06/25.
//


import SwiftUI
import Foundation


// MARK: - Main View
struct IntegrationsView: View {
    @StateObject private var connectionManager = IntegrationConnectionManager()
    @State private var selectedIntegration: IntegrationItem?
    @State private var showLoginPopup = false
    @State private var searchText = ""
    @State private var appearAnimation = false
    @StateObject private var themeManager = ThemeManager.shared
    
    let columns = [GridItem(.flexible())]  // Changed to single column
    
    var filteredIntegrations: [IntegrationItem] {
        let integrations = searchText.isEmpty ? connectionManager.integrations : connectionManager.integrations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        
        return integrations.sorted { first, second in
            // If connection status is different, connected items come first
            if first.isConnected != second.isConnected {
                return first.isConnected
            }
            // If connection status is the same, sort alphabetically by title
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Integration cards
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(filteredIntegrations.enumerated()), id: \.element.id) { index, integration in
                        IntegrationCard(
                            integration: integration,
                            showLoginPopup: $showLoginPopup,
                            selectedIntegration: $selectedIntegration,
                            connectionManager: connectionManager
                        )
                        .padding(.horizontal, 24)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(index) * 0.1),
                            value: appearAnimation
                        )
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Integrations")
        .background(Color(.systemGroupedBackground))
        .overlay(loginPopupOverlay)
        .onAppear {
            connectionManager.updateConnectionStatus()
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            TextField("Search Integrations...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var loginPopupOverlay: some View {
        if showLoginPopup, let integration = selectedIntegration {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showLoginPopup = false
                }
            
            IntegrationLoginView(
                integration: integration,
                isPresented: $showLoginPopup,
                onLoginSuccess: { [weak connectionManager] in
                    connectionManager?.updateConnectionStatus()
                }
            )
            .transition(.scale)
        }
    }
}


#Preview {
    IntegrationsView()
}

