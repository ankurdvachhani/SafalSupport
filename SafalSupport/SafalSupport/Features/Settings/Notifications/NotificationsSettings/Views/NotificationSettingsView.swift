//
//  NotificationSettingsView.swift
//  SafalCalendar
//
//  Created by Apple on 03/07/25.
//

import SwiftUI
import Foundation

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationsViewModel.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var expandedModule: NotificationModule? = nil
    @State private var showError = false
    
    private func bindingForModule(_ module: NotificationModule) -> Binding<NotificationPreference>? {
        guard let settings = viewModel.settings else { return nil }

        switch module {
        case .general:
            return Binding(get: { settings.general }, set: { settings.general = $0 })
        case .drainageTriggerLow:
            return Binding(get: { settings.drainageTriggerLow }, set: { settings.drainageTriggerLow = $0 })
        case .drainageTriggerMid:
            return Binding(get: { settings.drainageTriggerMid }, set: { settings.drainageTriggerMid = $0 })
        case .drainageTriggerHigh:
            return Binding(get: { settings.drainageTriggerHigh }, set: { settings.drainageTriggerHigh = $0 })
        case .drainageReminder:
            return Binding(get: { settings.drainageReminder }, set: { settings.drainageReminder = $0 })
        }
    }
    
    private func getModulesForUserRole() -> [NotificationModule] {
        let userRole = TokenManager.shared.loadCurrentUser()?.role
        if userRole == "Patient" {
            return [.general, .drainageReminder]
        }
        return NotificationModule.allCases
    }

    var body: some View {
        ZStack {
            List {
                ForEach(getModulesForUserRole(), id: \.self) { module in
                    Section {
                        Button(action: {
                            withAnimation {
                                if expandedModule == module {
                                    expandedModule = nil
                                } else {
                                    expandedModule = module
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: module.icon)
                                    .foregroundColor(Color.dynamicAccent)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(module.displayTitle)
                                            .font(.headline)
                                        
                                        if let priorityLabel = module.priorityLabel {
                                            Text(priorityLabel)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(module.priorityColor)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(module.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                                Image(systemName: expandedModule == module ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }

                        if expandedModule == module {
                            if let binding = bindingForModule(module) {
                                NotificationTogglesView(preference: binding)
                                    .environmentObject(viewModel)
                                    .padding(.leading, 30)
                                    .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await viewModel.fetchNotificationsSettings()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchNotificationsSettings()
            }
        }
        .toast(message: $viewModel.error, type: .error)
        .navigationTitle("Notification Settings")
        .refreshable {
            await viewModel.fetchNotificationsSettings()
        }
    }
}

struct NotificationTogglesView: View {
    @Binding var preference: NotificationPreference
    @EnvironmentObject private var viewModel: NotificationsViewModel
    @State private var isUpdating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Email", isOn: $preference.email)
                .onChange(of: preference.email) { newValue in
                    Task {
                        await updateSettings()
                    }
                }
            Toggle("Mobile push notification", isOn: $preference.pushMobile)
                .onChange(of: preference.pushMobile) { newValue in
                    Task {
                        await updateSettings()
                    }
                }
            Toggle("Text SMS", isOn: $preference.sms)
                .onChange(of: preference.sms) { newValue in
                    Task {
                        await updateSettings()
                    }
                }
            Toggle("In-App notification screen", isOn: $preference.notificationScreen)
                .onChange(of: preference.notificationScreen) { newValue in
                    Task {
                        await updateSettings()
                    }
                }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.dynamicAccent))
        .padding(.top, 5)
        .disabled(isUpdating)
        .overlay {
            if isUpdating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    private func updateSettings() async {
        isUpdating = true
        await viewModel.updateNotificationSettings()
        isUpdating = false
    }
}

#Preview {
    NotificationSettingsView()
}
