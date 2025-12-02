//
//  NotificationsView.swift
//  SafalCalendar
//
//  Created by Apple on 27/06/25.
//

import SwiftUI

struct NotificationsView: View {
    @State private var selectedModule: NotificationModule = .general
    @StateObject private var viewModel = NotificationsViewModel.shared

    var body: some View {
        List {
            ForEach(getModulesForUserRole(), id: \.self) { module in
                NavigationLink(destination: NotificationsListView(module: module.rawValue)) {
                    HStack {
                        Image(systemName: module.icon)
                            .foregroundColor(.dynamicAccent)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
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

                        let unreadCount = viewModel.getUnreadCount(for: module.rawValue)
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchNotificationCount()
            }
        }
        .listStyle(.plain)
        .navigationTitle("Notifications")
    }
    
    private func getModulesForUserRole() -> [NotificationModule] {
        let userRole = TokenManager.shared.loadCurrentUser()?.role
        if userRole == "Patient" {
            return [.general, .drainageReminder]
        }
        return NotificationModule.allCases
    }
}

#Preview {
    NotificationsView()
}
