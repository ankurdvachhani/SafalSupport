//
//  NotificationsListView.swift
//  SafalCalendar
//
//  Created by Apple on 27/06/25.
//

import SwiftUI

struct NotificationsListView: View {
    let module: String
    @StateObject private var viewModel = NotificationsViewModel.shared
    @State private var refreshTask: Task<Void, Never>?
    
    var filteredNotifications: [NotificationItem] {
        viewModel.getNotifications(for: module)
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            }  else if filteredNotifications.isEmpty {
                Text("No notifications")
                    .foregroundColor(.gray)
            } else {
                List {
                    ForEach(filteredNotifications) { notification in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notification.title)
                                .font(.headline)
                            
                            Text(notification.content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(notification.createdAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    // Cancel any existing refresh task
                    refreshTask?.cancel()
                    
                    // Create new refresh task
                    refreshTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                            await viewModel.fetchNotifications()
                        } catch {
                            if error is CancellationError {
                                // Ignore cancellation errors
                                return
                            }
                            // Handle other errors if needed
                            print("Refresh error: \(error)")
                        }
                    }
                    
                    // Wait for the refresh task to complete
                    await refreshTask?.value
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchNotificationsByModule(module)
                await viewModel.fetchNotificationCount()
                await viewModel.resetNotificationCount(for: module)
            }
        }
        .onDisappear {
            // Cancel any ongoing refresh task when view disappears
            refreshTask?.cancel()
        }
        .navigationTitle("\(getModuleDisplayTitle(module)) Notifications")
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
    
    private func getModuleDisplayTitle(_ module: String) -> String {
        switch module.lowercased() {
        case "general":
            return "General"
        case "drainagereminder":
            return "Drainage Reminder"
        case "drainagetriggerlow":
            return "Drainage Alert (Low)"
        case "drainagetriggermid":
            return "Drainage Alert (Mid)"
        case "drainagetriggerhigh":
            return "Drainage Alert (High)"
        default:
            return module.capitalized
        }
    }
}

#Preview {
    NotificationsListView(module: "general")
}
