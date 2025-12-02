import SwiftUI

struct DrainageTypeNotificationsListView: View {
    let notifications: [DrainageTypeNotification]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case exceeding = "Exceeding Max"
        case normal = "Normal"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    private var filteredNotifications: [DrainageTypeNotification] {
        var filtered = notifications
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { notification in
                notification.patientName.localizedCaseInsensitiveContains(searchText) ||
                notification.incident.name.localizedCaseInsensitiveContains(searchText) ||
                notification.drainageType.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .exceeding:
            filtered = filtered.filter { $0.isExceedingMax }
        case .normal:
            filtered = filtered.filter { !$0.isExceedingMax }
        }
        
        return filtered.sorted { $0.recordedAt > $1.recordedAt }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
              //  headerSection
                
                // Search and filter section
             //   searchAndFilterSection
                
                // Notifications list
                notificationsListSection
            }
            .navigationTitle("Drainage Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Notifications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(notifications.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Exceeding Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(notifications.filter { $0.isExceedingMax }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search notifications...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var notificationsListSection: some View {
        Group {
            if filteredNotifications.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredNotifications) { notification in
                        DrainageTypeNotificationListRow(notification: notification)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    // Add refresh functionality if needed
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No notifications found")
                .font(.headline)
                .foregroundColor(.primary)
            
            if !searchText.isEmpty || selectedFilter != .all {
                Text("Try adjusting your search or filter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Clear Filters") {
                    searchText = ""
                    selectedFilter = .all
                }
                .foregroundColor(.blue)
            } else {
                Text("All caught up! No drainage notifications at the moment.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Enhanced DrainageTypeNotificationRow for List View
struct DrainageTypeNotificationListRow: View {
    let notification: DrainageTypeNotification
    
    var body: some View {
        Button(action: {
            // Navigate to incident detail
            NavigationManager.shared.navigate(to: .incidentDetailById(incidentId: notification.incident.id))
        }) {
            VStack(spacing: 12) {
                // Header with incident name and status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.incident.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            // Priority indicator
                            if let patientData = notification.patientData,
                               let priority = patientData.metadata.priority,
                               priority != .none {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(priority.swiftUIColor)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(priority.rawValue.capitalized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(priority.swiftUIColor)
                                }
                            }
                            
                            // Exceeding max indicator
                            if notification.isExceedingMax {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    
                                    Text("Exceeding Max")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Amount display
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(notification.amount)\(notification.amountUnit)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(notification.isExceedingMax ? .red : .primary)
                        
                        Text(notification.drainageType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Patient and drainage info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(notification.patientName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(notification.drainageType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(notification.formattedRecordedAt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !notification.minMaxDisplay.isEmpty {
                            Text(notification.minMaxDisplay)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Config info if available
                if let config = notification.config {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Configuration")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                if let minAmount = config.minAmount, minAmount > 0 {
                                    Text("Min: \(minAmount)\(notification.amountUnit)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let maxAmount = config.maxAmount, maxAmount > 0 {
                                    Text("Max: \(maxAmount)\(notification.amountUnit)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let avgAmount = config.avgAmount, avgAmount > 0 {
                                    Text("Avg: \(avgAmount)\(notification.amountUnit)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct DrainageTypeNotificationsListView_Previews: PreviewProvider {
    static var previews: some View {
        DrainageTypeNotificationsListView(notifications: [])
    }
}
