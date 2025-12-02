import SwiftUI
import Charts

struct DoctorDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var configService = ConfigurationService.shared
    @State private var selectedTimeRange: DashboardViewModel.TimeRange = .week
    @State private var showAllPatientStats = false
    @State private var showingPatientStatsSheet = false
    @StateObject private var vitalSignsStatsService = VitalSignsStatsService()
    @State private var selectedVitalSignsDuration: VitalSignsDuration = .overall
    @State private var selectedVitalSignsPatient: PatientData?
    @State private var selectedVitalSignsIncident: Incident?
    @State private var showingVitalSignsPatientList = false
    @State private var showingVitalSignsIncidentList = false
    
    // Single Vital Signs Line Chart
    @StateObject private var singleVitalSignsService = SingleVitalSignsService()
    @State private var selectedVitalSignType: VitalSignType = .temperature
    @State private var selectedSingleVitalSignsDuration: VitalSignsDuration = .overall
    @State private var selectedSingleVitalSignsPatient: PatientData?
    @State private var selectedSingleVitalSignsIncident: Incident?
    @State private var showingSingleVitalSignsPatientList = false
    @State private var showingSingleVitalSignsIncidentList = false
    
    // Section visibility states
    @State private var showMissedDrainages = true
    @State private var showCriticalAlerts = true
    @State private var showQuickActions = true
    @State private var showActiveIncidents = true
    @State private var showDrainageTypeNotifications = true
    @State private var showWeeklyChart = true
    @State private var showDrainageTypePieChart = true
    @State private var showPatientBarChart = true
    @State private var showVitalSignsStats = true
    @State private var showSingleVitalSigns = true
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Filter Section
                filterSection
                
                // Stats Cards
                statsSection
                
                // Section Controls
                sectionControlsView
                
                // Missed Drainages Section
                if showMissedDrainages, let missedDrainages = viewModel.doctorDashboardData?.missedDrainages, !missedDrainages.isEmpty {
                    missedDrainagesSection
                }
                
                // Critical Alerts
                if showCriticalAlerts, !NotificationsViewModel.shared.getNotifications(for: "drainageTriggerHigh", isSeen: false).isEmpty {
                    criticalAlertsSection
                }
                
                // Quick Actions
                if showQuickActions {
                    quickActionsSection
                }
                
                // Active Incidents Section
                if showActiveIncidents {
                    activeIncidentsSection
                }
                
                // Drainage Type Notifications Section
                if showDrainageTypeNotifications, let drainageNotifications = viewModel.doctorDashboardData?.drainageTypeNotifications, !drainageNotifications.isEmpty {
                    drainageTypeNotificationsSection
                }
                
                // Weekly Drainage Chart Section
                if showWeeklyChart {
                    weeklyDrainageChartSection
                }
                
                // Patient Summary
             //   patientSummarySection
                
                // Drainage Type Pie Chart
                if showDrainageTypePieChart {
                    drainageTypePieChartSection
                }
                
                // Patient-wise Drainage Bar Chart
                if showPatientBarChart {
                    patientDrainageBarChartSection
                }
                
                // Vital Signs Stats Section
                if showVitalSignsStats {
                    vitalSignsStatsSection
                }
                
                // Single Vital Signs Line Chart Section
                if showSingleVitalSigns {
                    singleVitalSignsLineChartSection
                }
                
                // Drainage Trends Chart
              //  drainageTrendsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadSectionStates()
        }
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
        .sheet(isPresented: $showingPatientStatsSheet) {
            if let patientStats = viewModel.doctorDashboardData?.patientDrainageStats {
                PatientStatsBottomSheet(stats: patientStats)
            }
        }
        .sheet(isPresented: $showingVitalSignsPatientList) {
            VitalSignsPatientSelectionSheet(
                selectedPatient: $selectedVitalSignsPatient,
                isPresented: $showingVitalSignsPatientList
            )
        }
        .sheet(isPresented: $showingVitalSignsIncidentList) {
            VitalSignsIncidentSelectionSheet(
                selectedIncident: $selectedVitalSignsIncident,
                isPresented: $showingVitalSignsIncidentList
            )
        }
        .sheet(isPresented: $showingSingleVitalSignsPatientList) {
            VitalSignsPatientSelectionSheet(
                selectedPatient: $selectedSingleVitalSignsPatient,
                isPresented: $showingSingleVitalSignsPatientList
            )
        }
        .sheet(isPresented: $showingSingleVitalSignsIncidentList) {
            VitalSignsIncidentSelectionSheet(
                selectedIncident: $selectedSingleVitalSignsIncident,
                isPresented: $showingSingleVitalSignsIncidentList
            )
        }
    }
    
    // MARK: - Section Controls View
    private var sectionControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dashboard Sections")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: toggleAllSections) {
                    Text(areAllSectionsVisible ? "Hide All" : "Show All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.dynamicAccent)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SectionToggleButton(
                        title: "Missed Drainages",
                        icon: "clock.badge.exclamationmark",
                        isVisible: $showMissedDrainages
                    ) {
                        saveSectionState(key: "showMissedDrainages", value: showMissedDrainages)
                    }
                    
                    SectionToggleButton(
                        title: "Critical Alerts",
                        icon: "exclamationmark.triangle.fill",
                        isVisible: $showCriticalAlerts
                    ) {
                        saveSectionState(key: "showCriticalAlerts", value: showCriticalAlerts)
                    }
                    
                    SectionToggleButton(
                        title: "Quick Actions",
                        icon: "bolt.fill",
                        isVisible: $showQuickActions
                    ) {
                        saveSectionState(key: "showQuickActions", value: showQuickActions)
                    }
                    
                    SectionToggleButton(
                        title: "Active Incidents",
                        icon: "note.text.badge.plus",
                        isVisible: $showActiveIncidents
                    ) {
                        saveSectionState(key: "showActiveIncidents", value: showActiveIncidents)
                    }
                    
                    SectionToggleButton(
                        title: "Type Notifications",
                        icon: "bell.fill",
                        isVisible: $showDrainageTypeNotifications
                    ) {
                        saveSectionState(key: "showDrainageTypeNotifications", value: showDrainageTypeNotifications)
                    }
                    
                    SectionToggleButton(
                        title: "Weekly Chart",
                        icon: "chart.line.uptrend.xyaxis",
                        isVisible: $showWeeklyChart
                    ) {
                        saveSectionState(key: "showWeeklyChart", value: showWeeklyChart)
                    }
                    
                    SectionToggleButton(
                        title: "Type Pie Chart",
                        icon: "chart.pie.fill",
                        isVisible: $showDrainageTypePieChart
                    ) {
                        saveSectionState(key: "showDrainageTypePieChart", value: showDrainageTypePieChart)
                    }
                    
                    SectionToggleButton(
                        title: "Patient Bar Chart",
                        icon: "chart.bar.fill",
                        isVisible: $showPatientBarChart
                    ) {
                        saveSectionState(key: "showPatientBarChart", value: showPatientBarChart)
                    }
                    
                    SectionToggleButton(
                        title: "Vital Signs Stats",
                        icon: "heart.text.square.fill",
                        isVisible: $showVitalSignsStats
                    ) {
                        saveSectionState(key: "showVitalSignsStats", value: showVitalSignsStats)
                    }
                    
                    SectionToggleButton(
                        title: "Vital Trends",
                        icon: "waveform.path.ecg",
                        isVisible: $showSingleVitalSigns
                    ) {
                        saveSectionState(key: "showSingleVitalSigns", value: showSingleVitalSigns)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var areAllSectionsVisible: Bool {
        showMissedDrainages && showCriticalAlerts && showQuickActions &&
        showActiveIncidents && showDrainageTypeNotifications && showWeeklyChart &&
        showDrainageTypePieChart && showPatientBarChart && showVitalSignsStats &&
        showSingleVitalSigns
    }
    
    private func toggleAllSections() {
        let newState = !areAllSectionsVisible
        withAnimation {
            showMissedDrainages = newState
            showCriticalAlerts = newState
            showQuickActions = newState
            showActiveIncidents = newState
            showDrainageTypeNotifications = newState
            showWeeklyChart = newState
            showDrainageTypePieChart = newState
            showPatientBarChart = newState
            showVitalSignsStats = newState
            showSingleVitalSigns = newState
        }
        saveAllSectionStates()
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Duration Segmented Picker
//                VStack(alignment: .leading, spacing: 8) {
//                    Label("Duration", systemImage: "calendar")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//
//                    Picker("Duration", selection: $viewModel.selectedDuration) {
//                        ForEach(DashboardDuration.allCases, id: \.self) { duration in
//                            Text(duration.displayName).tag(duration)
//                        }
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
//                    .onChange(of: viewModel.selectedDuration) { _ in
//                        Task {
//                            await viewModel.loadDashboardData()
//                        }
//                    }
//                    
//                    // Display current filter date range
//                    if !viewModel.filterDateRange.isEmpty {
//                        HStack {
//                            Image(systemName: "calendar.badge.clock")
//                                .font(.caption)
//                                .foregroundColor(.blue)
//                            
//                            Text(viewModel.filterDateRange)
//                                .font(.caption)
//                                .foregroundColor(.blue)
//                                .fontWeight(.medium)
//                            
//                            Spacer()
//                        }
//                        .padding(.top, 4)
//                    }
//                }
//
//                Divider()

                // Drainage Type Filter
                VStack(alignment: .leading, spacing: 8) {
                    Label("Drainage Type", systemImage: "drop.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Menu {
                        Button {
                            viewModel.selectedDrainageType = ""
                            Task { await viewModel.loadDashboardData() }
                        } label: {
                            Label("All Types", systemImage: viewModel.selectedDrainageType.isEmpty ? "checkmark" : "")
                        }

                        ForEach(DrainageEntry.drainageTypeOptions, id: \.self) { type in
                            Button {
                                viewModel.selectedDrainageType = type
                                Task { await viewModel.loadDashboardData() }
                            } label: {
                                Label(type, systemImage: viewModel.selectedDrainageType == type ? "checkmark" : "")
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
    
    // MARK: - Stats Section
    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Total Patients",
                value: "\(viewModel.doctorDashboardData?.stats.totalPatients ?? 0)",
                icon: "person.3.fill",
                color: .blue
            )
            .onTapGesture {
                NavigationManager.shared.navigate(to: .patientList)
            }
            
            StatCard(
                title: "Active Incidents",
                value: "\(viewModel.doctorDashboardData?.stats.activeIncidents ?? 0)",
                icon: "note.text.badge.plus",
                color: .orange
            )
            .onTapGesture {
                appState.selectedTab = .IncidentList
                // Set pending filter flag
                IncidentFilterManager.pendingActiveFilter = true
            }
            
            
//            StatCard(
//                title: "Total Drainage Count",
//                value: "\(viewModel.doctorDashboardData?.stats.totalDrainageCount ?? 0)",
//                icon: "list.clipboard.fill",
//                color: .green
//            )
//            
//            StatCard(
//                title: "Total Drainage Amount",
//                value: String(format: "%.0f ml", Double(viewModel.doctorDashboardData?.stats.totalDrainageAmount ?? 0)),
//                icon: "drop.fill",
//                color: .purple
//            )
        }
    }
    
    // MARK: - Critical Alerts Section
    private var criticalAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drainages Alerts")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                let notifications = NotificationsViewModel.shared.getNotifications(for: "drainageTriggerHigh", isSeen: false)
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
            
            let notifications = NotificationsViewModel.shared.getNotifications(for: "drainageTriggerHigh", isSeen: false)
            if !notifications.isEmpty {
                ForEach(notifications.prefix(3)) { notification in
                    NotificationAlertRow(notification: notification)
                }
                
                if notifications.count > 3 {
                    Button("View All Alerts (\(notifications.count))") {
                        NavigationManager.shared.navigate(to: .notificationview)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No critical alerts")
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
                await NotificationsViewModel.shared.fetchNotificationsByModule("drainageTriggerHigh", isSeen: false)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.doctorDashboardData?.quickActions ?? []) { action in
                    QuickActionCard(action: action) {
                        handleQuickAction(action.action)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Active Incidents Section
    private var activeIncidentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Incidents")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let activeIncidents = viewModel.doctorDashboardData?.activeIncidents, !activeIncidents.isEmpty {
                    Text("\(activeIncidents.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            
            if let activeIncidents = viewModel.doctorDashboardData?.activeIncidents, !activeIncidents.isEmpty {
                ForEach(activeIncidents.prefix(3)) { incident in
                    ActiveIncidentRow(incident: incident)
                }
                
                if activeIncidents.count > 3 {
                    Button("View All Active (\(activeIncidents.count))") {
                        appState.selectedTab = .IncidentList
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No active incidents")
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
    }
    
    // MARK: - Drainage Type Notifications Section
    private var drainageTypeNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drainage Type Notification")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let notifications = viewModel.doctorDashboardData?.drainageTypeNotifications, !notifications.isEmpty {
                    Text("\(notifications.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            
            if let notifications = viewModel.doctorDashboardData?.drainageTypeNotifications, !notifications.isEmpty {
                ForEach(notifications.prefix(3)) { notification in
                    DrainageTypeNotificationRow(notification: notification)
                }
                
                if notifications.count > 3 {
                    Button("View All Notifications (\(notifications.count))") {
                        NavigationManager.shared.navigate(
                            to: .drainageTypeNotificationsList(notifications: notifications),
                            style: .presentSheet()
                        )
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No drainage notifications")
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
    }
    
    // MARK: - Weekly Drainage Chart Section
    private var weeklyDrainageChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Drainage Trends")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                Picker("Duration", selection: $viewModel.selectedLineChartDuration) {
                    ForEach(LineChartDashboardDuration.allCases, id: \.self) { duration in
                        Text(duration.displayName)
                            .foregroundColor(.black)
                            .tag(duration)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1) // border line
                )
                .onChange(of: viewModel.selectedLineChartDuration) { _ in
                    Task {
                        await viewModel.loadWeeklyDrainageData()
                    }
                }
            }
            
            if let weeklyData = viewModel.doctorDashboardData?.weeklyDrainageData, !weeklyData.isEmpty {
                WeeklyDrainageChart(data: weeklyData)
                    .frame(height: 200)
            } else {
                Text("No weekly drainage data available")
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
    }
    
    // MARK: - Patient Summary Section
    private var patientSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Patient Overview")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to patient list
                    NavigationManager.shared.navigate(to: .patientList)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let patients = viewModel.doctorDashboardData?.patientSummaries, !patients.isEmpty {
                ForEach(patients.prefix(3)) { patient in
                    PatientSummaryRow(patient: patient)
                }
            } else {
                Text("No patients assigned")
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
    }
    
    // MARK: - Missed Drainages Section
    private var missedDrainagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Missed Drainages")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let missedDrainages = viewModel.doctorDashboardData?.missedDrainages, !missedDrainages.isEmpty {
                    Text("\(missedDrainages.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            
            if let missedDrainages = viewModel.doctorDashboardData?.missedDrainages, !missedDrainages.isEmpty {
                ForEach(missedDrainages.prefix(3)) { missed in
                    MissedDrainageRow(missed: missed)
                }
                
                if missedDrainages.count > 3 {
                    Button("View All Missed (\(missedDrainages.count))") {
                        // Navigate to missed drainages list
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No missed drainages")
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
    }
    
    // MARK: - Drainage Type Pie Chart Section
    private var drainageTypePieChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drainage Types Distribution")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let drainageTypeStats = viewModel.doctorDashboardData?.drainageTypeStats, !drainageTypeStats.isEmpty {
                DrainageTypePieChart(stats: drainageTypeStats)
                    .frame(height: 400)
            } else {
                Text("No drainage type data available")
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
    }
    
    // MARK: - Patient Drainage Bar Chart Section
    private var patientDrainageBarChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Patient-wise Drainage Amount")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let patientStats = viewModel.doctorDashboardData?.patientDrainageStats, !patientStats.isEmpty {
                    Text("\(patientStats.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            
            if let patientStats = viewModel.doctorDashboardData?.patientDrainageStats, !patientStats.isEmpty {
                PatientDrainageBarChartView(
                    stats: patientStats,
                    showingSheet: $showingPatientStatsSheet
                )
            } else {
                Text("No patient drainage data available")
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
    }
    
    // MARK: - Drainage Trends Section
    private var drainageTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drainage Trends")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(DashboardViewModel.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            if let trends = viewModel.doctorDashboardData?.drainageTrends, !trends.isEmpty {
                DrainageTrendsChart(trends: trends)
                    .frame(height: 200)
            } else {
                Text("No trend data available")
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
                .onChange(of: selectedVitalSignsPatient) { _ in
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
                // Patient Filter
                Button {
                    showingVitalSignsPatientList = true
                } label: {
                    HStack {
                        Text(selectedVitalSignsPatient?.fullName ?? "All Patients")
                            .foregroundColor(selectedVitalSignsPatient != nil ? .primary : .secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
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
                // Patient Filter
                Button {
                    showingSingleVitalSignsPatientList = true
                } label: {
                    HStack {
                        Text(selectedSingleVitalSignsPatient?.fullName ?? "All Patients")
                            .foregroundColor(selectedSingleVitalSignsPatient != nil ? .primary : .secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
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
            .onChange(of: selectedSingleVitalSignsPatient) { _ in
                Task {
                    await loadSingleVitalSigns()
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
            patientId: selectedVitalSignsPatient?.userSlug,
            incidentId: selectedVitalSignsIncident?.id
        )
    }
    
    private func loadSingleVitalSigns() async {
        await singleVitalSignsService.fetchSingleVitalSigns(
            vitalType: selectedVitalSignType,
            duration: selectedSingleVitalSignsDuration,
            patientId: selectedSingleVitalSignsPatient?.userSlug,
            incidentId: selectedSingleVitalSignsIncident?.id
        )
    }
    
    private func handleQuickAction(_ action: QuickAction.QuickActionType) {
        switch action {
        case .addEntry:
            if configService.isIncidentEnabled {
                NavigationManager.shared.navigate(
                    to: .addDrainage(),
                    style: .presentSheet()
                )
            }
        case .patientList:
            NavigationManager.shared.navigate(to: .patientList)
        case .criticalAlerts:
            NavigationManager.shared.navigate(to: .notificationview)
            break
        case .reports:
            NavigationManager.shared.navigate(to: .incidentReportList)
        case .settings:
            appState.selectedTab = .settings
        case .notifications:
            NavigationManager.shared.navigate(to: .notificationview)
        }
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
    
    // MARK: - UserDefaults Helper Methods
    
    /// Load all section states from UserDefaults
    private func loadSectionStates() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLoadedSectionPreferences")
        
        if isFirstLaunch {
            // First time - all sections visible by default
            showMissedDrainages = true
            showCriticalAlerts = true
            showQuickActions = true
            showActiveIncidents = true
            showDrainageTypeNotifications = true
            showWeeklyChart = true
            showDrainageTypePieChart = true
            showPatientBarChart = true
            showVitalSignsStats = true
            showSingleVitalSigns = true
            
            UserDefaults.standard.set(true, forKey: "hasLoadedSectionPreferences")
            saveAllSectionStates()
        } else {
            // Load saved preferences
            showMissedDrainages = UserDefaults.standard.bool(forKey: "showMissedDrainages")
            showCriticalAlerts = UserDefaults.standard.bool(forKey: "showCriticalAlerts")
            showQuickActions = UserDefaults.standard.bool(forKey: "showQuickActions")
            showActiveIncidents = UserDefaults.standard.bool(forKey: "showActiveIncidents")
            showDrainageTypeNotifications = UserDefaults.standard.bool(forKey: "showDrainageTypeNotifications")
            showWeeklyChart = UserDefaults.standard.bool(forKey: "showWeeklyChart")
            showDrainageTypePieChart = UserDefaults.standard.bool(forKey: "showDrainageTypePieChart")
            showPatientBarChart = UserDefaults.standard.bool(forKey: "showPatientBarChart")
            showVitalSignsStats = UserDefaults.standard.bool(forKey: "showVitalSignsStats")
            showSingleVitalSigns = UserDefaults.standard.bool(forKey: "showSingleVitalSigns")
        }
    }
    
    /// Save a single section state to UserDefaults
    private func saveSectionState(key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    /// Save all section states to UserDefaults
    private func saveAllSectionStates() {
        UserDefaults.standard.set(showMissedDrainages, forKey: "showMissedDrainages")
        UserDefaults.standard.set(showCriticalAlerts, forKey: "showCriticalAlerts")
        UserDefaults.standard.set(showQuickActions, forKey: "showQuickActions")
        UserDefaults.standard.set(showActiveIncidents, forKey: "showActiveIncidents")
        UserDefaults.standard.set(showDrainageTypeNotifications, forKey: "showDrainageTypeNotifications")
        UserDefaults.standard.set(showWeeklyChart, forKey: "showWeeklyChart")
        UserDefaults.standard.set(showDrainageTypePieChart, forKey: "showDrainageTypePieChart")
        UserDefaults.standard.set(showPatientBarChart, forKey: "showPatientBarChart")
        UserDefaults.standard.set(showVitalSignsStats, forKey: "showVitalSignsStats")
        UserDefaults.standard.set(showSingleVitalSigns, forKey: "showSingleVitalSigns")
        UserDefaults.standard.synchronize()
    }
    
    /// Call this method on logout to remove all section preferences from UserDefaults
    static func clearDashboardPreferences() {
        let keys = [
            "showMissedDrainages",
            "showCriticalAlerts",
            "showQuickActions",
            "showActiveIncidents",
            "showDrainageTypeNotifications",
            "showWeeklyChart",
            "showDrainageTypePieChart",
            "showPatientBarChart",
            "showVitalSignsStats",
            "showSingleVitalSigns",
            "hasLoadedSectionPreferences"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        print("🧹 [DoctorDashboardView] Cleared all section preferences")
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if title == "Active Incidents" {
                HStack {
                Image("incident_icon_high") // ✅ your custom image
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(.dynamicAccent)
                    .frame(width: 30, height: 30)
                    .font(.title2)
                
                Spacer()
            }
               
            }else{
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title2)
                    
                    Spacer()
                }
            }
       
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct CriticalAlertRow: View {
    let alert: CriticalAlert
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.alertType.icon)
                .foregroundColor(alert.alertType.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.patientName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(alert.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(alert.severity.rawValue)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(alert.severity.color)
                    .clipShape(Capsule())
                
                Text(alert.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct NotificationAlertRow: View {
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
            Image(systemName: "exclamationmark.triangle.fill")
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
                Text("High")
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

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(action.color)
                
                Text(action.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActiveIncidentRow: View {
    let incident: IncidentStatsItem
    
    var body: some View {
        Button(action: {
            NavigationManager.shared.navigate(to: .incidentDetailById(incidentId: incident.id))
        }) {
            HStack(spacing: 12) {
               // Image(systemName: "note.text.badge.plus")
                Image("incident_icon_high") // ✅ your custom image
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.orange)
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(incident.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        // Priority color dot (only show if priority exists and is not none)
                        if let patientData = incident.patientData,
                           let priority = patientData.metadata.priority,
                           priority != .none {
                            Circle()
                                .fill(priority.swiftUIColor)
                                .frame(width: 6, height: 6)
                        }
                        
                        Text(incident.patientName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text("ID: \(incident.incidentId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(incident.status)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(incident.totalDrainageCount) drainages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(incident.totalAmountCount) ml")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PatientSummaryRow: View {
    let patient: PatientSummary
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.patientName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(patient.totalEntries) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: patient.status.icon)
                        .foregroundColor(patient.status.color)
                        .font(.caption)
                    
                    Text(patient.status.rawValue)
                        .font(.caption)
                        .foregroundColor(patient.status.color)
                }
                
                Text(String(format: "%.1f ml avg", patient.averageVolume))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MissedDrainageRow: View {
    let missed: MissedDrainageItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.red)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(missed.patientName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(missed.incidentName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("Incident ID: \(missed.incidentId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(missed.drainageType)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Highlight the scheduled time
                Text(missed.formattedScheduleTime)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DrainageTypePieChart: View {
    let stats: [DrainageTypeStats]
    
    // Define colors for each drainage type
    private let colors: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .pink, .indigo]
    
    private func colorForIndex(_ index: Int) -> Color {
        colors[index % colors.count]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Pie Chart
            Chart(stats) { stat in
                SectorMark(
                    angle: .value("Amount", stat.amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 2.0
                )
                .foregroundStyle(colorForIndex(stats.firstIndex(of: stat) ?? 0))
            }
            .chartLegend(.hidden)
            .frame(height: 150)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    if let plotFrame = chartProxy.plotFrame {
                        let frame = geometry[plotFrame]
                        VStack {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stats.reduce(0) { $0 + $1.amount }) ml")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            
            // Scrollable legend with matching colors
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(colorForIndex(index))
                                .frame(width: 16, height: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.drainageType)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(stat.count) entries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(stat.amount) ml")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("\(Int((Double(stat.amount) / Double(stats.reduce(0) { $0 + $1.amount })) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 200)
        }
    }
}

struct PatientDrainageBarChartView: View {
    let stats: [PatientDrainageStats]
    @Binding var showingSheet: Bool
    
    private var sortedStats: [PatientDrainageStats] {
        stats.sorted { $0.amount > $1.amount }
    }
    
    private var topThreeStats: [PatientDrainageStats] {
        Array(sortedStats.prefix(3))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Always show top 3 in the main chart
            Chart(topThreeStats) { stat in
                BarMark(
                    x: .value("Amount", stat.amount),
                    y: .value("Patient", stat.patientName)
                )
                .foregroundStyle(by: .value("Patient", stat.patientName))
                .annotation(position: .trailing) {
                    Text("\(stat.amount) ml")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
            
            // Show More button to open bottom sheet
            if stats.count > 3 {
                Button(action: {
                    showingSheet = true
                }) {
                    HStack(spacing: 4) {
                        Text("Show All (\(stats.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct PatientDrainageBarChart: View {
    let stats: [PatientDrainageStats]
    
    var body: some View {
        Chart(stats) { stat in
            BarMark(
                x: .value("Amount", stat.amount),
                y: .value("Patient", stat.patientName)
            )
            .foregroundStyle(by: .value("Patient", stat.patientName))
            .annotation(position: .trailing) {
                Text("\(stat.amount) ml")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
            }
        }
    }
}

struct DrainageTrendsChart: View {
    let trends: [DrainageTrend]
    
    var body: some View {
        Chart(trends) { trend in
            LineMark(
                x: .value("Date", trend.date),
                y: .value("Volume", trend.totalVolume)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 3))
            
            AreaMark(
                x: .value("Date", trend.date),
                y: .value("Volume", trend.totalVolume)
            )
            .foregroundStyle(.blue.opacity(0.1))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

struct WeeklyDrainageChart: View {
    let data: [WeeklyDrainageItem]
    
    var body: some View {
        VStack(spacing: 12) {
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    Text("Amount (ml)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
//                HStack(spacing: 4) {
//                    Circle()
//                        .fill(.green)
//                        .frame(width: 8, height: 8)
//                    Text("Count")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Combined Chart
            Chart(data) { item in
                // Drainage Amount Line
                LineMark(
                    x: .value("Day", shortDayName(item.dayName)),
                    y: .value("Amount", item.drainageAmount)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("Day", shortDayName(item.dayName)),
                    y: .value("Amount", item.drainageAmount)
                )
                .foregroundStyle(.blue)
                .annotation(position: .automatic) {
                    Text("\(item.drainageAmount)")
                        .font(.caption2)
                        .foregroundColor(.black)
                }
                
//                // Drainage Count Line
//                LineMark(
//                    x: .value("Day", shortDayName(item.dayName)),
//                    y: .value("Count", item.drainageCount)
//                )
//                .foregroundStyle(.green)
//                .lineStyle(StrokeStyle(lineWidth: 2))
//                
//                PointMark(
//                    x: .value("Day", shortDayName(item.dayName)),
//                    y: .value("Count", item.drainageCount)
//                )
//                .foregroundStyle(.green)
//                .annotation(position: .bottom) {
//                    Text("\(item.drainageCount)")
//                        .font(.caption2)
//                        .foregroundColor(.green)
//                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
    }
    
    private func shortDayName(_ fullName: String) -> String {
        switch fullName.lowercased() {
        case "sunday": return "SUN"
        case "monday": return "MON"
        case "tuesday": return "TUE"
        case "wednesday": return "WED"
        case "thursday": return "THU"
        case "friday": return "FRI"
        case "saturday": return "SAT"
        default: return fullName.prefix(3).uppercased()
        }
    }
}

struct DrainageTypeNotificationRow: View {
    let notification: DrainageTypeNotification
    
    var body: some View {
        Button(action: {
            // Navigate to drainage detail or incident detail
            NavigationManager.shared.navigate(to: .incidentDetailById(incidentId: notification.incident.id))
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.incident.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        // Priority color dot (only show if priority exists and is not none)
                        if let patientData = notification.patientData,
                           let priority = patientData.metadata.priority,
                           priority != .none {
                            Circle()
                                .fill(priority.swiftUIColor)
                                .frame(width: 6, height: 6)
                        }
                        
                        Text(notification.patientName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Text(notification.drainageType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(notification.formattedRecordedAt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(notification.amount)\(notification.amountUnit)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(notification.isExceedingMax ? .red : .primary)
                        
                        if notification.isExceedingMax {
                            Text("⚠️")
                                .font(.caption2)
                        }
                    }
                    
                    if !notification.minMaxDisplay.isEmpty {
                        Text(notification.minMaxDisplay)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.drainageId)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PatientStatsBottomSheet: View {
    let stats: [PatientDrainageStats]
    @Environment(\.dismiss) private var dismiss
    
    private var sortedStats: [PatientDrainageStats] {
        stats.sorted { $0.amount > $1.amount }
    }
    
    private var totalAmount: Int {
        stats.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                Divider()
                contentSection
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            HStack {
                Text("Patient-wise Drainage Amount")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
                .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
    
    private var contentSection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                summarySection
                chartSection
                patientListSection
                Spacer().frame(height: 20)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var summarySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Patients")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(stats.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Amount")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(totalAmount) ml")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drainage Amount by Patient")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            PatientStatsChart(stats: sortedStats)
                .padding(.horizontal, 20)
        }
    }
    
    private var patientListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patient Details")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, stat in
                    PatientStatsRow(stat: stat, rank: index + 1)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PatientStatsChart: View {
    let stats: [PatientDrainageStats]
    
    var body: some View {
        Chart(stats) { stat in
            BarMark(
                x: .value("Amount", stat.amount),
                y: .value("Patient", stat.patientName)
            )
            .foregroundStyle(by: .value("Patient", stat.patientName))
            .annotation(position: .trailing) {
                Text("\(stat.amount) ml")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                    .foregroundStyle(Color(.systemGray4))
                AxisValueLabel()
                    .font(.caption)
                 
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption)
                   
            }
        }
        .frame(height: CGFloat(max(300, stats.count * 50)))
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

struct PatientStatsRow: View {
    let stat: PatientDrainageStats
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.patientName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Patient ID: \(stat.patientId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.amount) ml")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(stat.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Vital Sign Model

struct VitalSign: Identifiable {
    let id = UUID()
    let displayName: String
    let type: String // "Min", "Avg", "Max"
    let value: Double
    let color: String
}

// MARK: - Vital Signs Stats Chart

struct VitalSignsStatsChart: View {
    let data: VitalSignsStatsData
    
    // Helper function to convert hex string to Color
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    private var chartData: [VitalSign] {
        var allData: [VitalSign] = []
        
        // Temperature
        allData.append(VitalSign(displayName: "Temperature", type: "Min", value: data.temperature.min, color: data.temperature.minColor))
        allData.append(VitalSign(displayName: "Temperature", type: "Avg", value: data.temperature.avg, color: data.temperature.avgColor))
        allData.append(VitalSign(displayName: "Temperature", type: "Max", value: data.temperature.max, color: data.temperature.maxColor))
        
        // Heart Rate
        allData.append(VitalSign(displayName: "Heart Rate", type: "Min", value: data.heartRate.min, color: data.heartRate.minColor))
        allData.append(VitalSign(displayName: "Heart Rate", type: "Avg", value: data.heartRate.avg, color: data.heartRate.avgColor))
        allData.append(VitalSign(displayName: "Heart Rate", type: "Max", value: data.heartRate.max, color: data.heartRate.maxColor))
        
        // Oxygen Saturation
        allData.append(VitalSign(displayName: "Oxygen Saturation", type: "Min", value: data.oxygenSaturation.min, color: data.oxygenSaturation.minColor))
        allData.append(VitalSign(displayName: "Oxygen Saturation", type: "Avg", value: data.oxygenSaturation.avg, color: data.oxygenSaturation.avgColor))
        allData.append(VitalSign(displayName: "Oxygen Saturation", type: "Max", value: data.oxygenSaturation.max, color: data.oxygenSaturation.maxColor))
        
        // Respiratory Rate
        allData.append(VitalSign(displayName: "Respiratory Rate", type: "Min", value: data.respiratoryRate.min, color: data.respiratoryRate.minColor))
        allData.append(VitalSign(displayName: "Respiratory Rate", type: "Avg", value: data.respiratoryRate.avg, color: data.respiratoryRate.avgColor))
        allData.append(VitalSign(displayName: "Respiratory Rate", type: "Max", value: data.respiratoryRate.max, color: data.respiratoryRate.maxColor))
        
        // Blood Pressure Diastolic
        allData.append(VitalSign(displayName: "BP Diastolic", type: "Min", value: data.bloodPressureD.min, color: data.bloodPressureD.minColor))
        allData.append(VitalSign(displayName: "BP Diastolic", type: "Avg", value: data.bloodPressureD.avg, color: data.bloodPressureD.avgColor))
        allData.append(VitalSign(displayName: "BP Diastolic", type: "Max", value: data.bloodPressureD.max, color: data.bloodPressureD.maxColor))
        
        // Blood Pressure Systolic
        allData.append(VitalSign(displayName: "BP Systolic", type: "Min", value: data.bloodPressureS.min, color: data.bloodPressureS.minColor))
        allData.append(VitalSign(displayName: "BP Systolic", type: "Avg", value: data.bloodPressureS.avg, color: data.bloodPressureS.avgColor))
        allData.append(VitalSign(displayName: "BP Systolic", type: "Max", value: data.bloodPressureS.max, color: data.bloodPressureS.maxColor))
        
        return allData
    }
    
    private var stackedChartData: [VitalSign] {
        var allData: [VitalSign] = []
        
        // Temperature - only add if stacked values are not 0
        if data.temperature.minStackedValue > 0 {
            allData.append(VitalSign(displayName: "Temperature", type: "Min", value: data.temperature.minStackedValue, color: data.temperature.stackColor))
        }
        if data.temperature.avgStackedValue > 0 {
            allData.append(VitalSign(displayName: "Temperature", type: "Avg", value: data.temperature.avgStackedValue, color: data.temperature.stackColor))
        }
        if data.temperature.maxStackedValue > 0 {
            allData.append(VitalSign(displayName: "Temperature", type: "Max", value: data.temperature.maxStackedValue, color: data.temperature.stackColor))
        }
        
        // Heart Rate - only add if stacked values are not 0
        if data.heartRate.minStackedValue > 0 {
            allData.append(VitalSign(displayName: "Heart Rate", type: "Min", value: data.heartRate.minStackedValue, color: data.heartRate.stackColor))
        }
        if data.heartRate.avgStackedValue > 0 {
            allData.append(VitalSign(displayName: "Heart Rate", type: "Avg", value: data.heartRate.avgStackedValue, color: data.heartRate.stackColor))
        }
        if data.heartRate.maxStackedValue > 0 {
            allData.append(VitalSign(displayName: "Heart Rate", type: "Max", value: data.heartRate.maxStackedValue, color: data.heartRate.stackColor))
        }
        
        // Oxygen Saturation - only add if stacked values are not 0
        if data.oxygenSaturation.minStackedValue > 0 {
            allData.append(VitalSign(displayName: "Oxygen Saturation", type: "Min", value: data.oxygenSaturation.minStackedValue, color: data.oxygenSaturation.stackColor))
        }
        if data.oxygenSaturation.avgStackedValue > 0 {
            allData.append(VitalSign(displayName: "Oxygen Saturation", type: "Avg", value: data.oxygenSaturation.avgStackedValue, color: data.oxygenSaturation.stackColor))
        }
        if data.oxygenSaturation.maxStackedValue > 0 {
            allData.append(VitalSign(displayName: "Oxygen Saturation", type: "Max", value: data.oxygenSaturation.maxStackedValue, color: data.oxygenSaturation.stackColor))
        }
        
        // Respiratory Rate - only add if stacked values are not 0
        if data.respiratoryRate.minStackedValue > 0 {
            allData.append(VitalSign(displayName: "Respiratory Rate", type: "Min", value: data.respiratoryRate.minStackedValue, color: data.respiratoryRate.stackColor))
        }
        if data.respiratoryRate.avgStackedValue > 0 {
            allData.append(VitalSign(displayName: "Respiratory Rate", type: "Avg", value: data.respiratoryRate.avgStackedValue, color: data.respiratoryRate.stackColor))
        }
        if data.respiratoryRate.maxStackedValue > 0 {
            allData.append(VitalSign(displayName: "Respiratory Rate", type: "Max", value: data.respiratoryRate.maxStackedValue, color: data.respiratoryRate.stackColor))
        }
        
        // Blood Pressure Diastolic - only add if stacked values are not 0
        if data.bloodPressureD.minStackedValue > 0 {
            allData.append(VitalSign(displayName: "BP Diastolic", type: "Min", value: data.bloodPressureD.minStackedValue, color: data.bloodPressureD.stackColor))
        }
        if data.bloodPressureD.avgStackedValue > 0 {
            allData.append(VitalSign(displayName: "BP Diastolic", type: "Avg", value: data.bloodPressureD.avgStackedValue, color: data.bloodPressureD.stackColor))
        }
        if data.bloodPressureD.maxStackedValue > 0 {
            allData.append(VitalSign(displayName: "BP Diastolic", type: "Max", value: data.bloodPressureD.maxStackedValue, color: data.bloodPressureD.stackColor))
        }
        
        // Blood Pressure Systolic - only add if stacked values are not 0
        if data.bloodPressureS.minStackedValue > 0 {
            allData.append(VitalSign(displayName: "BP Systolic", type: "Min", value: data.bloodPressureS.minStackedValue, color: data.bloodPressureS.stackColor))
        }
        if data.bloodPressureS.avgStackedValue > 0 {
            allData.append(VitalSign(displayName: "BP Systolic", type: "Avg", value: data.bloodPressureS.avgStackedValue, color: data.bloodPressureS.stackColor))
        }
        if data.bloodPressureS.maxStackedValue > 0 {
            allData.append(VitalSign(displayName: "BP Systolic", type: "Max", value: data.bloodPressureS.maxStackedValue, color: data.bloodPressureS.stackColor))
        }
        
        return allData
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Legend with dynamic colors
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFromHex(data.temperature.minColor))
                        .frame(width: 12, height: 8)
                    Text("Min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFromHex(data.temperature.avgColor))
                        .frame(width: 12, height: 8)
                    Text("Avg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFromHex(data.temperature.maxColor))
                        .frame(width: 12, height: 8)
                    Text("Max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
//                HStack(spacing: 4) {
//                    RoundedRectangle(cornerRadius: 2)
//                        .fill(colorFromHex(data.temperature.stackColor))
//                        .frame(width: 12, height: 8)
//                    Text("Stacked")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Chart with stacked bars showing actual values and stacked values
            Chart {
                // Stacked values (base layer) - only show if not 0
                ForEach(stackedChartData) { item in
                    BarMark(
                        x: .value("Vital Sign", item.displayName),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(colorFromHex(item.color))
                    .position(by: .value("Type", item.type))
                }
                
                // Actual values (top layer showing difference)
                ForEach(chartData) { item in
                    BarMark(
                        x: .value("Vital Sign", item.displayName),
                        y: .value("Value", item.value)
                    )
                    .foregroundStyle(colorFromHex(item.color))
                    .position(by: .value("Type", item.type))
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text("\(Int(item.value))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            // Show difference only if there's a corresponding stacked value and meaningful difference
                            if let stackedItem = stackedChartData.first(where: { $0.displayName == item.displayName && $0.type == item.type }),
                               abs(item.value - stackedItem.value) > 0.1 {
                                let difference = item.value - stackedItem.value
                                Text(difference > 0 ? "+\(Int(difference))" : "\(Int(difference))")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(colorFromHex(item.color))
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(4)
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .frame(minWidth: 1000) // Minimum width for proper spacing
        }
    }
}

// MARK: - Vital Signs Patient Selection Sheet

struct VitalSignsPatientSelectionSheet: View {
    @Binding var selectedPatient: PatientData?
    @Binding var isPresented: Bool
    
    @StateObject private var patientViewModel = PatientSelectionViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search patients...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            patientViewModel.searchPatients()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                
                // Patient List
                List {
                    // "All Patients" option
                    Button {
                        selectedPatient = nil
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("All Patients")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Show all patients")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedPatient == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.dynamicAccent)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ForEach(filteredPatients) { patient in
                        Button {
                            selectedPatient = patient
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(patient.fullName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(patient.email ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPatient?.id == patient.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.dynamicAccent)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await patientViewModel.fetchPatients()
            }
        }
    }
    
    private var filteredPatients: [PatientData] {
        if searchText.isEmpty {
            return patientViewModel.patients
        } else {
            return patientViewModel.patients.filter { patient in
                patient.fullName.localizedCaseInsensitiveContains(searchText) ||
                (patient.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

// MARK: - Vital Signs Incident Selection Sheet

struct VitalSignsIncidentSelectionSheet: View {
    @Binding var selectedIncident: Incident?
    @Binding var isPresented: Bool
    
    @StateObject private var incidentViewModel = IncidentStore()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search incidents...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            // Implement search if needed
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                
                // Incident List
                List {
                    // "All Incidents" option
                    Button {
                        selectedIncident = nil
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("All Incidents")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Show all incidents")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedIncident == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.dynamicAccent)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ForEach(filteredIncidents) { incident in
                        Button {
                            selectedIncident = incident
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(incident.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(incident.patientName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedIncident?.id == incident.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.dynamicAccent)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Incident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await incidentViewModel.fetchIncidents()
            }
        }
    }
    
    private var filteredIncidents: [Incident] {
        if searchText.isEmpty {
            return incidentViewModel.incidents
        } else {
            return incidentViewModel.incidents.filter { incident in
                incident.name.localizedCaseInsensitiveContains(searchText) ||
                incident.patientName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Single Vital Signs Line Chart

struct SingleVitalSignsLineChart: View {
    let data: [SingleVitalSignData]
    let vitalType: VitalSignType
    
    // Helper function to convert hex string to Color
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Helper function to format date for display
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd MMM - hh:mm a"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Legend for blood pressure
            if vitalType == .bloodPressure {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Systolic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                        Text("Diastolic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            // Chart
            Chart {
                if vitalType == .bloodPressure {
                    // Systolic Line (Red)
                    ForEach(data) { item in
                        LineMark(
                            x: .value("Date", formatDate(item.recordedAt)),
                            y: .value("Pressure", item.value),
                            series: .value("Type", "Systolic")
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Date", formatDate(item.recordedAt)),
                            y: .value("Pressure", item.value)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(40)
                        .annotation(position: .top) {
                            Text("\(Int(item.value))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Diastolic Line (Blue)
                    ForEach(data) { item in
                        if let value2 = item.value2 {
                            LineMark(
                                x: .value("Date", formatDate(item.recordedAt)),
                                y: .value("Pressure", value2),
                                series: .value("Type", "Diastolic")
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                            
                            PointMark(
                                x: .value("Date", formatDate(item.recordedAt)),
                                y: .value("Pressure", value2)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(40)
                            .annotation(position: .bottom) {
                                Text("\(Int(value2))")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(4)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(4)
                            }
                        }
                    }
                } else {
                    // Other vital signs: Single line
                    ForEach(data) { item in
                        LineMark(
                            x: .value("Date", formatDate(item.recordedAt)),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(colorFromHex(item.labelColor))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Date", formatDate(item.recordedAt)),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(colorFromHex(item.labelColor))
                        .symbolSize(40)
                        .annotation(position: .top) {
                            Text("\(Int(item.value))")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.caption)
                       
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .frame(height: 250)
            .frame(minWidth: 1000)
        }
    }
}

// MARK: - Section Toggle Button Component

struct SectionToggleButton: View {
    let title: String
    let icon: String
    @Binding var isVisible: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isVisible.toggle()
            }
            onToggle()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isVisible ? .dynamicAccent : .secondary)
                    .frame(height: 24)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                
                Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                    .font(.caption2)
                    .foregroundColor(isVisible ? .green : .secondary)
            }
            .frame(width: 100)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isVisible ? Color(.systemGray6) : Color(.systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isVisible ? Color.dynamicAccent.opacity(0.4) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct DoctorDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DoctorDashboardView(
            viewModel: DashboardViewModel()
        )
    }
} 
