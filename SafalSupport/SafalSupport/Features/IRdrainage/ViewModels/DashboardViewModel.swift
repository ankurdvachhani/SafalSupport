import Foundation
import SwiftUI
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var doctorDashboardData: DoctorDashboardData?
    @Published var nurseDashboardData: NurseDashboardData?
    @Published var patientDashboardData: PatientDashboardData?
    @StateObject private var configService = ConfigurationService.shared
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTimeRange: TimeRange = .day
    @Published var selectedDuration: DashboardDuration = .today
    @Published var selectedLineChartDuration: LineChartDashboardDuration = .week
    @Published var selectedDrainageType: String = ""
    @Published var patientData: PatientData?
    @Published var currentFilter: DashboardFilter?
    var drainageStore: DrainageStore?
    private let networkManager = NetworkManager()
    private var cancellables = Set<AnyCancellable>()
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "7 Days"
        case month = "30 Days"
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }
    
    // MARK: - Filter Date Display
    var filterDateRange: String {
        guard let filter = currentFilter else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, yyyy"
        
        if let startDate = dateFormatter.date(from: filter.startDate),
           let endDate = dateFormatter.date(from: filter.endDate) {
            return "\(displayFormatter.string(from: startDate)) - \(displayFormatter.string(from: endDate))"
        }
        
        return ""
    }
    
    init(patient: PatientData? = nil) {
        self.patientData = patient
        Task { @MainActor in
            self.drainageStore = DrainageStore(patientSlug: patientData?.userSlug)
            self.setupBindings()
        }
    }
    
    func setPatient(_ patient: PatientData) {
        self.patientData = patient
        Task { @MainActor in
            self.drainageStore = DrainageStore(patientSlug: patient.userSlug)
            self.setupBindings()
            await loadPatientSpecificData()
        }
    }
    
    private func setupBindings() {
        drainageStore?.$entries
            .sink { [weak self] entries in
                self?.updateDashboardData(with: entries)
            }
            .store(in: &cancellables)
    }
    
    func loadDashboardData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let userRole = TokenManager.shared.loadCurrentUser()?.role ?? "Patient"
            
            switch userRole {
            case "Patient":
                await loadPatientDashboardData()
            case "Doctor":
                await loadDoctorDashboardData()
            case "Nurse":
          //      await loadNurseDashboardData()
                await loadDoctorDashboardData()
            default:
                await loadPatientDashboardData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadPatientDashboardData() async {
        do {
            // Get current device time zone
            let timeZone = TimeZone.current.identifier
            
            var queryItems = [
                URLQueryItem(name: "duration", value: selectedDuration.rawValue),
                URLQueryItem(name: "tz", value: timeZone)
            ]
            
            // Add drainage type filter if selected
            if !selectedDrainageType.isEmpty {
                queryItems.append(URLQueryItem(name: "drainageType", value: selectedDrainageType))
            }
            
            let endpoint = Endpoint(
                path: "/api/dashboard",
                queryItems: queryItems
            )
            
            let response: DashboardAPIResponse = try await networkManager.fetch(endpoint)
            
            // Store the current filter data
            currentFilter = response.filter
            
            // Fetch upcoming drainage data
            let upcomingDrainage = await fetchUpcomingDrainage()
            
            // Fetch latest comments data
            let latestComments = await fetchLatestComments()
            
            if response.success {
                // Convert API data to PatientDashboardData
                let stats = DashboardStats(
                    totalPatients: 1, // Patient dashboard shows only their own data
                    todayEntries: response.data.drainageCount, totalEntries: response.data.totalDrainageCount,
                    criticalAlerts: 0, // Will be calculated from entries
                    totalVolume: response.data.totalVolume,
                    averageVolume: response.data.averageVolume,
                    overdueEntries: 0
                )
                
                // Convert drainage history to trends
                let drainageTrends = response.data.drainageHistory.map { historyItem in
                    let date: Date
                    
                    // Handle different label formats based on duration
                    if selectedDuration == .today {
                        // For today, labels are time format like "08:00", "10:00"
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "HH:mm"
                        if let parsedTime = timeFormatter.date(from: historyItem.label) {
                            // Create today's date with the parsed time
                            let calendar = Calendar.current
                            let today = Date()
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                            date = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: today) ?? today
                        } else {
                            date = Date()
                        }
                    } else {
                        // For other durations, labels are date format like "5 Aug"
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "d MMM"
                        date = dateFormatter.date(from: historyItem.label) ?? Date()
                    }
                    
                    return DrainageTrend(
                        date: date,
                        totalVolume: historyItem.value,
                        entryCount: historyItem.value > 0 ? 1 : 0,
                        averageVolume: historyItem.value
                    )
                }
                
                // Convert health tips to educational tips
                let educationalTips: [EducationalTip] = (response.data.healthTips ?? []).map {
                    EducationalTip(
                        title: $0.title,
                        description: $0.description ?? "",
                        category: $0.tipCategory,
                        icon: $0.icon ?? ""
                    )
                }
                
                // Generate alerts from recent drainage entries
                let alerts = generatePatientAlerts(from: response.data.recentDrainage)
                
                patientDashboardData = PatientDashboardData(
                    stats: stats,
                    recentEntries: response.data.recentDrainage,
                    drainageTrends: drainageTrends,
                    educationalTips: educationalTips,
                    alerts: alerts,
                    upcomingDrainage: upcomingDrainage,
                    latestComments: latestComments
                )
            } else {
                errorMessage = "Failed to load dashboard data"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchUpcomingDrainage() async -> [UpcomingDrainageItem]? {
        do {
            let endpoint = Endpoint(path: "/api/dashboard/upcoming-drainage")
            let response: UpcomingDrainageResponse = try await networkManager.fetch(endpoint)
            
            if response.success {
                return response.data.upcomingArray.filter { $0.isUpcoming }
            } else {
                return nil
            }
        } catch {
            print("Failed to fetch upcoming drainage: \(error)")
            return nil
        }
    }
    
    private func fetchLatestComments() async -> [LatestComment]? {
        do {
            let endpoint = Endpoint(path: "/api/dashboard/latest-comments")
            let response: LatestCommentsResponse = try await networkManager.fetch(endpoint)
            
            if response.success {
                return response.data
            } else {
                return nil
            }
        } catch {
            print("Failed to fetch latest comments: \(error)")
            return nil
        }
    }
    
    private func loadDoctorDashboardData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current device time zone
            let timeZone = TimeZone.current.identifier
            
            // Build query parameters
            var queryItems = [
                URLQueryItem(name: "duration", value: selectedDuration.rawValue),
                URLQueryItem(name: "tz", value: timeZone)
            ]
            
            // Add drainage type filter if selected
            if !selectedDrainageType.isEmpty {
                queryItems.append(URLQueryItem(name: "drainageType", value: selectedDrainageType))
            }
            
            // Add patient filter if available
            if let patientId = patientData?.userSlug {
                queryItems.append(URLQueryItem(name: "patientId", value: patientId))
            }
            
            // 1. Fetch Patient Stats API
            let patientStatsEndpoint = Endpoint(path: "/api/dashboard/patient-stats")
            let patientStatsResponse: PatientStatsResponse = try await networkManager.fetch(patientStatsEndpoint)
            
            // 2. Fetch Incident Stats API
            let incidentStatsEndpoint = Endpoint(
                path: "/api/dashboard/incident-stats",
                queryItems: queryItems
            )
            let incidentStatsResponse: IncidentStatsResponse = try await networkManager.fetch(incidentStatsEndpoint)
            
            // 3. Fetch Weekly Drainage API
            var weeklyDrainageQueryItems = [
                URLQueryItem(name: "duration", value: selectedLineChartDuration.rawValue),
                URLQueryItem(name: "tz", value: timeZone)
            ]
            
            // Add drainage type filter if selected
            if !selectedDrainageType.isEmpty {
                weeklyDrainageQueryItems.append(URLQueryItem(name: "drainageType", value: selectedDrainageType))
            }
            
            // Add patient filter if available
            if let patientId = patientData?.userSlug {
                weeklyDrainageQueryItems.append(URLQueryItem(name: "patientId", value: patientId))
            }
            
            let weeklyDrainageEndpoint = Endpoint(
                path: "/api/dashboard/weekly-drainage",
                queryItems: weeklyDrainageQueryItems
            )
            let weeklyDrainageResponse: WeeklyDrainageResponse = try await networkManager.fetch(weeklyDrainageEndpoint)
            
            // 4. Fetch active incidents (existing)
            let activeIncidentEndpoint = Endpoint(
                path: "/api/dashboard/active-incident",
                queryItems: queryItems
            )
            let activeIncidentResponse: ActiveIncidentResponse = try await networkManager.fetch(activeIncidentEndpoint)
            
            // 5. Fetch drainage stats (existing)
            let drainageStatsEndpoint = Endpoint(
                path: "/api/dashboard/drainage-stats",
                queryItems: queryItems
            )
            let drainageStatsResponse: DrainageStatsResponse = try await networkManager.fetch(drainageStatsEndpoint)
            
            // 6. Fetch missed drainages (existing)
            let missedDrainageEndpoint = Endpoint(
                path: "/api/dashboard/missed-drainage",
                queryItems: queryItems
            )
            let missedDrainageResponse: MissedDrainageResponse = try await networkManager.fetch(missedDrainageEndpoint)
            
            // 7. Fetch Drainage Type Notifications API
            let drainageNotificationEndpoint = Endpoint(path: "/api/dashboard/drainage-type-notification")
            let drainageNotificationResponse: DrainageTypeNotificationResponse = try await networkManager.fetch(drainageNotificationEndpoint)
            
            if patientStatsResponse.success && incidentStatsResponse.success && weeklyDrainageResponse.success && 
               activeIncidentResponse.success && drainageStatsResponse.success && missedDrainageResponse.success && 
               drainageNotificationResponse.success {
                
                // Create doctor dashboard data with new API responses
                let stats = DoctorDashboardStats(
                    totalPatients: patientStatsResponse.data.totalPatientCount,
                    activeIncidents: incidentStatsResponse.data.totalIncidentCount,
                    totalDrainageCount: drainageStatsResponse.data.totalDrainageCount,
                    totalDrainageAmount: drainageStatsResponse.data.totalDrainageAmount
                )
                
                // Generate other data (critical alerts, patient summaries, etc.)
                let criticalAlerts = generateCriticalAlerts(from: []) // Will be populated from API later
                let patientSummaries = generatePatientSummaries(from: []) // Will be populated from API later
                let drainageTrends = generateDrainageTrends(from: []) // Will be populated from API later
                let quickActions = generateDoctorQuickActions()
                
                doctorDashboardData = DoctorDashboardData(
                    stats: stats,
                    criticalAlerts: criticalAlerts,
                    patientSummaries: patientSummaries,
                    drainageTrends: drainageTrends,
                    quickActions: quickActions,
                    missedDrainages: missedDrainageResponse.data,
                    drainageTypeStats: drainageStatsResponse.data.byDrainageType,
                    patientDrainageStats: drainageStatsResponse.data.byPatient,
                    activeIncidents: incidentStatsResponse.data.incidentList,
                    weeklyDrainageData: weeklyDrainageResponse.data,
                    drainageTypeNotifications: drainageNotificationResponse.data
                )
            } else {
                errorMessage = "Failed to load dashboard data"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadNurseDashboardData() async {
        // For now, use mock data for nurse dashboard
        await generateMockData()
    }
    
    func refreshDashboard() async {
        await loadDashboardData()
    }
    
    /// Load only weekly drainage data without affecting other dashboard sections
    func loadWeeklyDrainageData() async {
        do {
            // Get current device time zone
            let timeZone = TimeZone.current.identifier
            
            // Build query parameters for weekly drainage
            var weeklyDrainageQueryItems = [
                URLQueryItem(name: "duration", value: selectedLineChartDuration.rawValue),
                URLQueryItem(name: "tz", value: timeZone)
            ]
            
            // Add drainage type filter if selected
            if !selectedDrainageType.isEmpty {
                weeklyDrainageQueryItems.append(URLQueryItem(name: "drainageType", value: selectedDrainageType))
            }
            
            // Add patient filter if available
            if let patientId = patientData?.userSlug {
                weeklyDrainageQueryItems.append(URLQueryItem(name: "patientId", value: patientId))
            }
            
            let weeklyDrainageEndpoint = Endpoint(
                path: "/api/dashboard/weekly-drainage",
                queryItems: weeklyDrainageQueryItems
            )
            let weeklyDrainageResponse: WeeklyDrainageResponse = try await networkManager.fetch(weeklyDrainageEndpoint)
            
            if weeklyDrainageResponse.success {
                // Update only the weekly drainage data
                doctorDashboardData?.weeklyDrainageData = weeklyDrainageResponse.data
            } else {
                errorMessage = "Failed to load weekly drainage data"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadPatientSpecificData() async {
        guard let patient = patientData else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load patient-specific drainage data
            await drainageStore?.fetchEntries()
            
            // Generate patient-specific dashboard data
            if let entries = drainageStore?.entries {
                patientDashboardData = generatePatientDashboardData(from: entries)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func updateDashboardData(with entries: [DrainageEntry]) {
        let userRole = TokenManager.shared.loadCurrentUser()?.role ?? "Patient"
        
        switch userRole {
        case "Doctor":
            doctorDashboardData = generateDoctorDashboardData(from: entries)
        case "Nurse":
            nurseDashboardData = generateNurseDashboardData(from: entries)
        case "Patient":
            patientDashboardData = generatePatientDashboardData(from: entries)
        default:
            doctorDashboardData = generateDoctorDashboardData(from: entries)
           // patientDashboardData = generatePatientDashboardData(from: entries)
        }
    }
    
    // MARK: - Data Generation Methods
    
    private func generateDoctorDashboardData(from entries: [DrainageEntry]) -> DoctorDashboardData {
        let stats = DoctorDashboardStats(
            totalPatients: 0,
            activeIncidents: 0,
            totalDrainageCount: 0,
            totalDrainageAmount: 0
        )
        let criticalAlerts = generateCriticalAlerts(from: entries)
        let patientSummaries = generatePatientSummaries(from: entries)
        let drainageTrends = generateDrainageTrends(from: entries)
        let quickActions = generateDoctorQuickActions()
        
        return DoctorDashboardData(
            stats: stats,
            criticalAlerts: criticalAlerts,
            patientSummaries: patientSummaries,
            drainageTrends: drainageTrends,
            quickActions: quickActions,
            missedDrainages: [],
            drainageTypeStats: [],
            patientDrainageStats: [],
            activeIncidents: [],
            weeklyDrainageData: [],
            drainageTypeNotifications: []
        )
    }
    
    private func generateNurseDashboardData(from entries: [DrainageEntry]) -> NurseDashboardData {
        let stats = calculateStats(from: entries)
        let assignedPatients = generatePatientSummaries(from: entries)
        let recentEntries = Array(entries.prefix(5))
        let overdueEntries = generateOverdueEntries(from: entries)
        let quickActions = generateNurseQuickActions()
        
        return NurseDashboardData(
            stats: stats,
            assignedPatients: assignedPatients,
            recentEntries: recentEntries,
            overdueEntries: overdueEntries,
            quickActions: quickActions
        )
    }
    
    private func generatePatientDashboardData(from entries: [DrainageEntry]) -> PatientDashboardData {
        let stats = calculateStats(from: entries)
        let recentEntries = Array(entries.prefix(10))
        let drainageTrends = generateDrainageTrends(from: entries)
        let educationalTips = generateEducationalTips()
        let alerts = generatePatientAlerts(from: entries)
        
        return PatientDashboardData(
            stats: stats,
            recentEntries: recentEntries,
            drainageTrends: drainageTrends,
            educationalTips: educationalTips,
            alerts: alerts,
            upcomingDrainage: nil,
            latestComments: nil // Will be fetched separately
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateStats(from entries: [DrainageEntry]) -> DashboardStats {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = entries.filter { Calendar.current.isDate($0.recordedAt, inSameDayAs: today) }
        
        let totalVolume = entries.reduce(0) { $0 + $1.amount }
        let averageVolume = entries.isEmpty ? 0 : totalVolume / Double(entries.count)
        
        let uniquePatients = Set(entries.compactMap { $0.patientId })
        let criticalAlerts = generateCriticalAlerts(from: entries).count
        let overdueEntries = generateOverdueEntries(from: entries).count
        
        return DashboardStats(
            totalPatients: uniquePatients.count,
            todayEntries: todayEntries.count, totalEntries: entries.count,
            criticalAlerts: criticalAlerts,
            totalVolume: totalVolume,
            averageVolume: averageVolume,
            overdueEntries: overdueEntries
        )
    }
    
    private func generateCriticalAlerts(from entries: [DrainageEntry]) -> [CriticalAlert] {
        var alerts: [CriticalAlert] = []
        
        for entry in entries {
            // High volume alert (> 70ml)
            if entry.amount > 200 {
                alerts.append(CriticalAlert(
                    patientName: entry.patientName ?? "Unknown Patient",
                    alertType: .highVolume,
                    severity: .high,
                    timestamp: entry.recordedAt,
                    description: "High drainage volume: \(entry.amount) \(entry.amountUnit)"
                ))
            }
            
            // Abnormal color alert (yellow or pus-like)
            if entry.color.lowercased().contains("yellow") || entry.color.lowercased().contains("pus") {
                alerts.append(CriticalAlert(
                    patientName: entry.patientName ?? "Unknown Patient",
                    alertType: .abnormalColor,
                    severity: .medium,
                    timestamp: entry.recordedAt,
                    description: "Abnormal fluid color: \(entry.color)"
                ))
            }
            
            // Odor present alert
            if entry.odorPresent == true {
                alerts.append(CriticalAlert(
                    patientName: entry.patientName ?? "Unknown Patient",
                    alertType: .odorPresent,
                    severity: .medium,
                    timestamp: entry.recordedAt,
                    description: "Odor detected in drainage"
                ))
            }
            
            // High pain level alert
            if let painLevel = entry.painLevel, painLevel >= 7 {
                alerts.append(CriticalAlert(
                    patientName: entry.patientName ?? "Unknown Patient",
                    alertType: .highPain,
                    severity: .high,
                    timestamp: entry.recordedAt,
                    description: "High pain level: \(painLevel)/10"
                ))
            }
        }
        
        return alerts.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func generatePatientSummaries(from entries: [DrainageEntry]) -> [PatientSummary] {
        let groupedEntries = Dictionary(grouping: entries) { $0.patientId ?? "" }
        
        return groupedEntries.map { patientId, patientEntries in
            let totalVolume = patientEntries.reduce(0) { $0 + $1.amount }
            let averageVolume = patientEntries.isEmpty ? 0 : totalVolume / Double(patientEntries.count)
            let lastEntry = patientEntries.max { $0.recordedAt < $1.recordedAt }
            
            let status: PatientSummary.PatientStatus = {
                if patientEntries.contains(where: { $0.amount > 70 }) {
                    return .critical
                } else if let lastEntry = lastEntry, 
                          Calendar.current.dateInterval(of: .day, for: Date())?.contains(lastEntry.recordedAt) == true {
                    return .active
                } else {
                    return .monitoring
                }
            }()
            
            return PatientSummary(
                patientId: patientId,
                patientName: patientEntries.first?.patientName ?? "Unknown Patient",
                lastEntryDate: lastEntry?.recordedAt,
                totalEntries: patientEntries.count,
                averageVolume: averageVolume,
                status: status,
                assignedNurse: "Nurse Smith" // Mock data
            )
        }.sorted { $0.lastEntryDate ?? Date.distantPast > $1.lastEntryDate ?? Date.distantPast }
    }
    
    private func generateDrainageTrends(from entries: [DrainageEntry]) -> [DrainageTrend] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        var trends: [DrainageTrend] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayEntries = entries.filter { calendar.isDate($0.recordedAt, inSameDayAs: currentDate) }
            let totalVolume = dayEntries.reduce(0) { $0 + $1.amount }
            let averageVolume = dayEntries.isEmpty ? 0 : totalVolume / Double(dayEntries.count)
            
            trends.append(DrainageTrend(
                date: currentDate,
                totalVolume: totalVolume,
                entryCount: dayEntries.count,
                averageVolume: averageVolume
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return trends
    }
    
    private func generateOverdueEntries(from entries: [DrainageEntry]) -> [DrainageEntry] {
        let calendar = Calendar.current
        let now = Date()
        let overdueThreshold = calendar.date(byAdding: .hour, value: -4, to: now) ?? now
        
        return entries.filter { entry in
            entry.recordedAt < overdueThreshold
        }.sorted { $0.recordedAt > $1.recordedAt }
    }
    
    private func generatePatientAlerts(from entries: [DrainageEntry]) -> [CriticalAlert] {
        return generateCriticalAlerts(from: entries).filter { alert in
            alert.severity == .high || alert.severity == .critical
        }
    }
    
    // MARK: - Quick Actions
    
    private func generateDoctorQuickActions() -> [QuickAction] {
        if configService.isIncidentEnabled {
            return [
                QuickAction(title: "Add Entry", icon: "plus.circle.fill", color: .blue, action: .addEntry),
                QuickAction(title: "Patient List", icon: "person.3.fill", color: .green, action: .patientList),
                QuickAction(title: "Critical Alerts", icon: "exclamationmark.triangle.fill", color: .red, action: .criticalAlerts),
                QuickAction(title: "Reports", icon: "chart.bar.fill", color: .purple, action: .reports),
                QuickAction(title: "Settings", icon: "gear", color: .gray, action: .settings),
                QuickAction(title: "Notifications", icon: "bell.fill", color: .orange, action: .notifications)
            ]
        }
        return [
            QuickAction(title: "Patient List", icon: "person.3.fill", color: .green, action: .patientList),
            QuickAction(title: "Critical Alerts", icon: "exclamationmark.triangle.fill", color: .red, action: .criticalAlerts),
            QuickAction(title: "Reports", icon: "chart.bar.fill", color: .purple, action: .reports),
            QuickAction(title: "Settings", icon: "gear", color: .gray, action: .settings),
            QuickAction(title: "Notifications", icon: "bell.fill", color: .orange, action: .notifications)
        ]
    }
    
    private func generateNurseQuickActions() -> [QuickAction] {
        return [
            QuickAction(title: "Record Entry", icon: "plus.circle.fill", color: .green, action: .addEntry),
            QuickAction(title: "My Patients", icon: "person.3.fill", color: .blue, action: .patientList),
            QuickAction(title: "Overdue", icon: "clock.badge.exclamationmark", color: .orange, action: .criticalAlerts),
            QuickAction(title: "Reports", icon: "chart.bar.fill", color: .purple, action: .reports),
            QuickAction(title: "Settings", icon: "gear", color: .gray, action: .settings),
            QuickAction(title: "Notifications", icon: "bell.fill", color: .red, action: .notifications)
        ]
    }
    
    private func generateEducationalTips() -> [EducationalTip] {
        return [
            EducationalTip(
                title: "Proper Wound Care",
                description: "Keep the drainage site clean and dry. Change dressings as instructed by your healthcare provider.",
                category: .aftercare,
                icon: "bandage.fill"
            ),
            EducationalTip(
                title: "Monitor for Infection",
                description: "Watch for signs of infection: increased redness, swelling, or foul odor.",
                category: .hygiene,
                icon: "eye.fill"
            ),
            EducationalTip(
                title: "Stay Hydrated",
                description: "Drink plenty of fluids to help your body heal and maintain proper drainage.",
                category: .nutrition,
                icon: "drop.fill"
            ),
            EducationalTip(
                title: "Gentle Movement",
                description: "Light walking and gentle exercises can help improve circulation and healing.",
                category: .exercise,
                icon: "figure.walk"
            ),
            EducationalTip(
                title: "Medication Schedule",
                description: "Take prescribed medications on time and complete the full course as directed.",
                category: .medication,
                icon: "pills.fill"
            )
        ]
    }
    
    // MARK: - Mock Data Generation (for development)
    
    private func generateMockData() async {
        // This method generates mock data for development purposes
        // In production, this would be replaced with actual API calls
        
        let mockEntries = [
            DrainageEntry(
                id: "1",
                userId: "user1",
                patientId: "patient1",
                patientName: "John Doe",
                patientData: nil, // Mock data doesn't include patient data
                amount: 85.0,
                amountUnit: "ml",
                location: "Chest",
                fluidType: "Serous",
                color: "Clear",
                comments: "Normal drainage",
                odorPresent: false,
                painLevel: 3,
                temperature: 98.6,
                doctorNotified: false,
                recordedAt: Date(),
                createdAt: Date(),
                updatedAt: Date()
            ),
            DrainageEntry(
                id: "2",
                userId: "user1",
                patientId: "patient2",
                patientName: "Jane Smith",
                patientData: nil, // Mock data doesn't include patient data
                amount: 45.0,
                amountUnit: "ml",
                location: "Abdomen",
                fluidType: "Serosanguinous",
                color: "Yellow",
                comments: "Slight odor detected",
                odorPresent: true,
                painLevel: 7,
                temperature: 99.2,
                doctorNotified: true,
                recordedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        // Update the drainage store with mock data
        await MainActor.run {
            self.drainageStore?.entries = mockEntries
        }
    }
} 
