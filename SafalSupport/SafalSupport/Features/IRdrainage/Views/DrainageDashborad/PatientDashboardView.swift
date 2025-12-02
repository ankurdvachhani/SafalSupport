import Charts
import SwiftUI

struct PatientDashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var configService = ConfigurationService.shared
    @State private var selectedTimeRange: DashboardViewModel.TimeRange = .day
    @EnvironmentObject private var appState: AppState
    
    // Vital Signs Stats
    @StateObject private var vitalSignsStatsService = VitalSignsStatsService()
    @State private var selectedVitalSignsDuration: VitalSignsDuration = .overall
    @State private var selectedVitalSignsIncident: Incident?
    @State private var showingVitalSignsIncidentList = false
    
    // Single Vital Signs Line Chart
    @StateObject private var singleVitalSignsService = SingleVitalSignsService()
    @State private var selectedVitalSignType: VitalSignType = .temperature
    @State private var selectedSingleVitalSignsDuration: VitalSignsDuration = .overall
    @State private var selectedSingleVitalSignsIncident: Incident?
    @State private var showingSingleVitalSignsIncidentList = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Welcome Section
                welcomeSection

                // Upcoming Drainage Alert
                if let upcomingDrainage = viewModel.patientDashboardData?.upcomingDrainage, !upcomingDrainage.isEmpty {
                    upcomingDrainageAlertSection
                }

                // Latest Comments
                if let comments = viewModel.patientDashboardData?.latestComments, !comments.isEmpty {
                    latestCommentsSection
                }

                // Drainage Alert Reminders
                if !NotificationsViewModel.shared.getNotifications(for: "drainageReminder", isSeen: false).isEmpty {
                    drainageAlertRemindersSection
                }

                //  Fillter view
                fillterView

                // Today's Stats
                todayStatsSection

                // Quick Actions
                patientQuickActionsSection

                // Recent Entries
                recentEntriesSection

                // Drainage History Chart
                drainageHistorySection

                // Educational Tips
                educationalTipsSection

                // Vital Signs Stats Section
                vitalSignsStatsSection
                
                // Single Vital Signs Line Chart Section
                singleVitalSignsLineChartSection

                // Alerts
                //   alertsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Vital Signs Error", isPresented: .constant(vitalSignsStatsService.errorMessage != nil)) {
            Button("OK") {
                vitalSignsStatsService.errorMessage = nil
            }
        } message: {
            if let errorMessage = vitalSignsStatsService.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Single Vital Signs Error", isPresented: .constant(singleVitalSignsService.errorMessage != nil)) {
            Button("OK") {
                singleVitalSignsService.errorMessage = nil
            }
        } message: {
            if let errorMessage = singleVitalSignsService.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingVitalSignsIncidentList) {
            VitalSignsIncidentSelectionSheet(
                selectedIncident: $selectedVitalSignsIncident,
                isPresented: $showingVitalSignsIncidentList
            )
        }
        .sheet(isPresented: $showingSingleVitalSignsIncidentList) {
            VitalSignsIncidentSelectionSheet(
                selectedIncident: $selectedSingleVitalSignsIncident,
                isPresented: $showingSingleVitalSignsIncidentList
            )
        }
    }

    private var fillterView: some View {
        VStack(spacing: 16) {
            // Card Container
            VStack(alignment: .leading, spacing: 16) {
                // Duration Segmented Picker
                VStack(alignment: .leading, spacing: 8) {
                    Label("Duration", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Duration", selection: $viewModel.selectedDuration) {
                        ForEach(DashboardDuration.allCases, id: \.self) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.selectedDuration) { _ in
                        Task {
                            await viewModel.loadDashboardData()
                        }
                    }
                    
                    // Display current filter date range
                    if !viewModel.filterDateRange.isEmpty {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(viewModel.filterDateRange)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }

                Divider()

                // Drainage Type Filter
                VStack(alignment: .leading, spacing: 8) {
                    Label("Drainage Type", systemImage: "drop.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Menu {
                        // Menu Items
                        Button {
                            viewModel.selectedDrainageType = ""
                            Task { await viewModel.loadDashboardData() }
                        } label: {
                            Label("All Types", systemImage: "checkmark")
                        }

                        ForEach(DrainageEntry.drainageTypeOptions, id: \.self) { type in
                            Button {
                                viewModel.selectedDrainageType = type
                                Task { await viewModel.loadDashboardData() }
                            } label: {
                                Text(type)
                            }
                        }

                    } label: {
                        HStack {
                            Text(viewModel.selectedDrainageType.isEmpty ? "All Types" : viewModel.selectedDrainageType)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2))
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back! \(TokenManager.shared.getUserName() ?? "")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Track your drainage progress and stay informed about your recovery.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Circle()
                    .fill(Color.teal.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .foregroundColor(.teal)
                            .font(.title)
                    )
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.teal.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }

    // MARK: - Today's Stats Section

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(viewModel.selectedDuration.displayName) Drainage Overview")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                PatientStatCard(
                    title: "Today's Entries",
                    value: "\(viewModel.patientDashboardData?.stats.todayEntries ?? 0)",
                    icon: "list.clipboard.fill",
                    color: .teal,
                    onTap: {
                        // Navigate to DrainageListView with today's date filter
                        appState.selectedTab = .Drainage
                        // Set today's date filter
                        setTodayDateFilter()
                    }
                )

                PatientStatCard(
                    title: "Total Volume",
                    value: String(format: "%.1f ml", viewModel.patientDashboardData?.stats.totalVolume ?? 0),
                    icon: "drop.fill",
                    color: .blue
                )

                PatientStatCard(
                    title: "Average Volume",
                    value: String(format: "%.1f ml", viewModel.patientDashboardData?.stats.averageVolume ?? 0),
                    icon: "chart.bar.fill",
                    color: .purple
                )
                if viewModel.selectedDuration.displayName != "Today\'s" {
                    PatientStatCard(
                        title: "Total Entries",
                        value: "\(viewModel.patientDashboardData?.stats.totalEntries ?? 0)",
                        icon: "number.circle.fill",
                        color: .orange,
                        onTap: {
                            // Navigate to DrainageListView without any date filter
                            appState.selectedTab = .Drainage
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Patient Quick Actions Section

    private var patientQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            HStack(spacing: 16) {
//                if configService.isIncidentEnabled {
//                    PatientQuickActionButton(
//                        title: "Add Entry",
//                        icon: "plus.circle.fill",
//                        color: .teal
//                    ) {
//                        NavigationManager.shared.navigate(
//                            to: .addDrainage(),
//                            style: .presentSheet()
//                        )
//                    }
//                }

                PatientQuickActionButton(
                    title: "View Drainages",
                    icon: "clock.fill",
                    color: .blue
                ) {
                    // Navigate to history
                    appState.selectedTab = .Drainage
                }

                PatientQuickActionButton(
                    title: "Health Tips",
                    icon: "heart.fill",
                    color: .purple
                ) {
                    // Navigate to tips
                    if let tips = viewModel.patientDashboardData?.educationalTips {
                        NavigationManager.shared.navigate(
                            to: .educationalTips(tips: tips),
                            style: .presentSheet()
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Recent Entries Section

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(viewModel.selectedDuration.displayName) Recent Entries")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Button("View All") {
                    // Navigate to entries list
                    appState.selectedTab = .Drainage
                }
                .font(.subheadline)
                .foregroundColor(.teal)
            }

            if let entries = viewModel.patientDashboardData?.recentEntries, !entries.isEmpty {
                ForEach(entries.prefix(5)) { entry in
                    PatientEntryRow(entry: entry)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 50))
                        .foregroundColor(.teal.opacity(0.6))

                    Text("No entries yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Start tracking your drainage by adding your first entry")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

//                    if configService.isIncidentEnabled {
//                        Button("Add First Entry") {
//                            if configService.isIncidentEnabled {
//                                NavigationManager.shared.navigate(
//                                    to: .addDrainage(),
//                                    style: .presentSheet()
//                                )
//                            }
//                        }
//                        .font(.subheadline)
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 24)
//                        .padding(.vertical, 12)
//                        .background(Color.teal)
//                        .cornerRadius(25)
//                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.teal.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Drainage History Section

    private var drainageHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Drainage History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()
            }

            if let trends = viewModel.patientDashboardData?.drainageTrends, !trends.isEmpty {
                PatientDrainageChart(trends: trends, viewModel: viewModel)
                    .frame(height: 200)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.blue.opacity(0.6))

                    Text("No chart data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Add more entries to see your drainage trends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Educational Tips Section

    private var educationalTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Health Tips")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Button("View All") {
                    if let tips = viewModel.patientDashboardData?.educationalTips {
                        NavigationManager.shared.navigate(
                            to: .educationalTips(tips: tips),
                            style: .presentSheet()
                        )
                    }
                }
                .font(.subheadline)
                .foregroundColor(.teal)
            }

            if let tips = viewModel.patientDashboardData?.educationalTips, !tips.isEmpty {
                ForEach(tips.prefix(3)) { tip in
                    EducationalTipCard(tip: tip)
                }
            } else {
                Text("No tips available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Drainage Alert Reminders Section

    private var drainageAlertRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drainage Alert Reminders")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                let notifications = NotificationsViewModel.shared.getNotifications(for: "drainageReminder", isSeen: false)
                if !notifications.isEmpty {
                    Text("\(notifications.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }

            let notifications = NotificationsViewModel.shared.getNotifications(for: "drainageReminder", isSeen: false)
            if !notifications.isEmpty {
                ForEach(notifications.prefix(3)) { notification in
                    PatientNotificationAlertRow(notification: notification)
                }

                if notifications.count > 3 {
                    Button("View All Reminders (\(notifications.count))") {
                        NavigationManager.shared.navigate(to: .notificationview)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No drainage reminders")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            Task {
                await NotificationsViewModel.shared.fetchNotificationsByModule("drainageReminder", isSeen: false)
            }
        }
    }

    // MARK: - Latest Comments Section

    private var latestCommentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Latest Comments")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                if let comments = viewModel.patientDashboardData?.latestComments, !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }

            if let comments = viewModel.patientDashboardData?.latestComments, !comments.isEmpty {
                ForEach(Array(comments.prefix(3)), id: \.commentId) { comment in
                    PatientCommentRow(comment: comment)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "message.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.blue.opacity(0.6))

                    Text("No comments yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Comments from your healthcare team will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Important Alerts")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                if let alerts = viewModel.patientDashboardData?.alerts, !alerts.isEmpty {
                    Text("\(alerts.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }

            if let alerts = viewModel.patientDashboardData?.alerts, !alerts.isEmpty {
                ForEach(alerts.prefix(3)) { alert in
                    PatientAlertRow(alert: alert)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)

                    Text("All good!")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("No important alerts at this time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Upcoming Drainage Alert Section

    private var upcomingDrainageAlertSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Drainage")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            }

            if let upcomingDrainage = viewModel.patientDashboardData?.upcomingDrainage, !upcomingDrainage.isEmpty {
                // Sort upcoming drainage by time only (earliest time first, ignoring date)
                let sortedUpcomingDrainage = upcomingDrainage.sorted { first, second in
                    // Parse the full datetime string to get the actual time
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

                    let firstDate = dateFormatter.date(from: first.upcomingDateTime) ?? Date.distantFuture
                    let secondDate = dateFormatter.date(from: second.upcomingDateTime) ?? Date.distantFuture

                    // Extract time components for comparison
                    let calendar = Calendar.current
                    let firstComponents = calendar.dateComponents([.hour, .minute], from: firstDate)
                    let secondComponents = calendar.dateComponents([.hour, .minute], from: secondDate)

                    // Convert to minutes since midnight for accurate comparison
                    let firstMinutes = (firstComponents.hour ?? 0) * 60 + (firstComponents.minute ?? 0)
                    let secondMinutes = (secondComponents.hour ?? 0) * 60 + (secondComponents.minute ?? 0)

                    return firstMinutes < secondMinutes // Earliest time first
                }

                ForEach(sortedUpcomingDrainage) { item in
                    UpcomingDrainageRow(item: item)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)

                    Text("No upcoming drainage")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("You're all caught up!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Vital Signs Stats Section
    private var vitalSignsStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vital Signs Stats")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Duration Picker
                Picker("Duration", selection: $selectedVitalSignsDuration) {
                    ForEach(VitalSignsDuration.allCases) { duration in
                        Text(duration.displayName)
                            .tag(duration)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onChange(of: selectedVitalSignsDuration) { _ in
                    Task {
                        await loadVitalSignsStats()
                    }
                }
                .onChange(of: selectedVitalSignsIncident) { _ in
                    Task {
                        await loadVitalSignsStats()
                    }
                }
            }
            
            // Date Range Display (only show when not "overall")
            if selectedVitalSignsDuration != .overall,
               let filter = vitalSignsStatsService.filter,
               let recordedAt = filter.recordedAt,
               let dateRange = formatDateRange(start: recordedAt.gte, end: recordedAt.lte) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(dateRange)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            }
        
            // Filter Row
            HStack(spacing: 12) {
                // Incident Filter
                Button {
                    showingVitalSignsIncidentList = true
                } label: {
                    HStack {
                        Text(selectedVitalSignsIncident?.name ?? "All Incidents")
                            .foregroundColor(selectedVitalSignsIncident != nil ? .primary : .secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            if vitalSignsStatsService.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading vital signs data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if let stats = vitalSignsStatsService.stats {
                ScrollView(.horizontal, showsIndicators: true) {
                    VitalSignsStatsChart(data: stats)
                        .frame(height: 300)
                }
                .frame(height: 300)
            } else if let errorMessage = vitalSignsStatsService.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Error loading data")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("No vital signs data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            Task {
                await loadVitalSignsStats()
            }
        }
    }
    
    // MARK: - Single Vital Signs Line Chart Section
    private var singleVitalSignsLineChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
             
                // Vital Sign Type Picker
                Picker("Vital Sign", selection: $selectedVitalSignType) {
                    ForEach(VitalSignType.allCases) { vitalType in
                        Text(vitalType.displayName)
                            .tag(vitalType)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onChange(of: selectedVitalSignType) { _ in
                    Task {
                        await loadSingleVitalSigns()
                    }
                }
                
                // Duration Picker
                Picker("Duration", selection: $selectedSingleVitalSignsDuration) {
                    ForEach(VitalSignsDuration.allCases) { duration in
                        Text(duration.displayName)
                            .tag(duration)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onChange(of: selectedSingleVitalSignsDuration) { _ in
                    Task {
                        await loadSingleVitalSigns()
                    }
                }
            }
            
            // Date Range Display (only show when not "overall")
            if selectedSingleVitalSignsDuration != .overall,
               let filter = singleVitalSignsService.filter,
               let recordedAt = filter.recordedAt,
               let dateRange = formatDateRange(start: recordedAt.gte, end: recordedAt.lte) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(dateRange)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.medium)
                }
                .padding(.top, 4)
            }
        
            // Filter Row
            HStack(spacing: 12) {
                // Incident Filter
                Button {
                    showingSingleVitalSignsIncidentList = true
                } label: {
                    HStack {
                        Text(selectedSingleVitalSignsIncident?.name ?? "All Incidents")
                            .foregroundColor(selectedSingleVitalSignsIncident != nil ? .primary : .secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .onChange(of: selectedSingleVitalSignsIncident) { _ in
                Task {
                    await loadSingleVitalSigns()
                }
            }
            
            if singleVitalSignsService.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading vital signs trend data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if !singleVitalSignsService.data.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    SingleVitalSignsLineChart(data: singleVitalSignsService.data, vitalType: selectedVitalSignType)
                        .frame(width: max(1200, CGFloat(singleVitalSignsService.data.count) * 150))
                }
                .frame(height: 400)
            } else if let errorMessage = singleVitalSignsService.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Error loading data")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("No vital signs trend data available")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            Task {
                await loadSingleVitalSigns()
            }
        }
    }

    // MARK: - Helper Methods
    private func loadVitalSignsStats() async {
        await vitalSignsStatsService.fetchVitalSignsStats(
            duration: selectedVitalSignsDuration,
            patientId: TokenManager.shared.loadCurrentUser()?.userSlug,
            incidentId: selectedVitalSignsIncident?.id
        )
    }
    
    private func loadSingleVitalSigns() async {
        await singleVitalSignsService.fetchSingleVitalSigns(
            vitalType: selectedVitalSignType,
            duration: selectedSingleVitalSignsDuration,
            patientId: TokenManager.shared.loadCurrentUser()?.userSlug,
            incidentId: selectedSingleVitalSignsIncident?.id
        )
    }

    private func setTodayDateFilter() {
        let today = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? today

        // Store the date filter in UserDefaults for DrainageListView to pick up
        UserDefaults.standard.set(startOfDay, forKey: "pendingMinRecordedAt")
        UserDefaults.standard.set(endOfDay, forKey: "pendingMaxRecordedAt")
        UserDefaults.standard.set(true, forKey: "pendingDateFilter")
    }
    
    // MARK: - Date Formatting Helper
    
    /// Formats the date range from the filter's recordedAt object
    /// - Parameters:
    ///   - start: Start date string in ISO format
    ///   - end: End date string in ISO format
    /// - Returns: Formatted date range string or nil if parsing fails
    private func formatDateRange(start: String?, end: String?) -> String? {
        guard let startString = start, let endString = end else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let startDate = dateFormatter.date(from: startString),
              let endDate = dateFormatter.date(from: endString) else {
            return nil
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd MMM yyyy"
        
        let startFormatted = displayFormatter.string(from: startDate)
        let endFormatted = displayFormatter.string(from: endDate)
        
        return "\(startFormatted) - \(endFormatted)"
    }
}

// MARK: - Supporting Views

struct PatientStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let onTap: (() -> Void)?

    init(title: String, value: String, icon: String, color: Color, onTap: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PatientQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if title == "Health Tips" {
                    Image("h_tips")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(color)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PatientEntryRow: View {
    let entry: DrainageEntry

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.teal.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "drop.fill")
                        .foregroundColor(.teal)
                        .font(.title2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.amount, specifier: "%.1f") \(entry.amountUnit)")
                    .font(.headline)
                    .fontWeight(.medium)

                Text("Location: \(entry.location)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(entry.recordedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.fluidType)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.teal)
                    .clipShape(Capsule())

                if entry.odorPresent == true {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.teal.opacity(0.05))
        .cornerRadius(16)
    }
}

struct PatientDrainageChart: View {
    let trends: [DrainageTrend]
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        Chart(trends) { trend in
            LineMark(
                x: .value("Date", trend.date),
                y: .value("Volume", trend.totalVolume)
            )
            .foregroundStyle(.teal)
            .lineStyle(StrokeStyle(lineWidth: 3))

            AreaMark(
                x: .value("Date", trend.date),
                y: .value("Volume", trend.totalVolume)
            )
            .foregroundStyle(.teal.opacity(0.2))
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                if viewModel.selectedDuration == .today {
                    AxisValueLabel(format: .dateTime.hour().minute())
                } else {
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

struct EducationalTipCard: View {
    let tip: EducationalTip

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(tip.category.color.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: tip.icon)
                        .foregroundColor(tip.category.color)
                        .font(.title2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.headline)
                    .fontWeight(.medium)

                Text(tip.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(5)

                Text(tip.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tip.category.color)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding()
        .background(tip.category.color.opacity(0.05))
        .cornerRadius(16)
    }
}

struct PatientAlertRow: View {
    let alert: CriticalAlert

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: alert.alertType.icon)
                .foregroundColor(alert.alertType.color)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(alert.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(alert.severity.rawValue)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(alert.severity.color)
                .clipShape(Capsule())
        }
        .padding()
        .background(alert.severity.color.opacity(0.1))
        .cornerRadius(16)
    }
}

struct UpcomingDrainageRow: View {
    let item: UpcomingDrainageItem

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.incidentName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("Incident ID: \(item.incidentId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.formattedTime)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text(item.formattedDate)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)

                Text("Scheduled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(16)
    }
}

struct PatientNotificationAlertRow: View {
    let notification: NotificationItem

    private func formatNotificationDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        if let date = dateFormatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return "N/A"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .foregroundColor(.red)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(notification.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Reminder")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())

                Text(formatNotificationDate(notification.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PatientCommentRow: View {
    let comment: LatestComment

    private func formatCommentDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        if let date = dateFormatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return "N/A"
    }

    var body: some View {
        Button(action: {
            NavigationManager.shared.navigate(to: .drainageDetailByDrainageId(drainageId: comment.drainageId))
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.userData.firstName)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("(\(comment.userData.role))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(comment.comment)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)

                    HStack {
                        Text("Drainage: \(comment.drainageId)")
                            .font(.caption)
                            .foregroundColor(.blue)

                        if let incidentName = comment.incidentName {
                            Text("• \(incidentName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCommentDate(comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct PatientDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PatientDashboardView(
            viewModel: DashboardViewModel()
        )
    }
}

// MARK: - DrainageDetailByDrainageIdView

struct DrainageDetailByDrainageIdView: View {
    let drainageId: String
    @EnvironmentObject private var store: DrainageStore
    @State private var drainageEntry: DrainageEntry?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading drainage details...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry = drainageEntry {
                DrainageDetailView(entry: entry)
                    .environmentObject(store)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("Drainage Not Found")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("The drainage entry with ID '\(drainageId)' could not be found.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Drainage Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDrainageDetails()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func loadDrainageDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            // Use the existing fetchDrainageDetail function with drainageId
            drainageEntry = try await store.fetchDrainageDetail(id: drainageId)
        } catch {
            errorMessage = "Failed to load drainage details: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
