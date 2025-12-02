import Foundation
import SwiftUI

// MARK: - Dashboard Models

struct DashboardStats {
    let totalPatients: Int
    let todayEntries: Int
    let totalEntries: Int
    let criticalAlerts: Int
    let totalVolume: Double
    let averageVolume: Double
    let overdueEntries: Int
}

struct CriticalAlert: Identifiable {
    let id = UUID()
    let patientName: String
    let alertType: AlertType
    let severity: AlertSeverity
    let timestamp: Date
    let description: String
    
    enum AlertType: String, CaseIterable {
        case highVolume = "High Volume"
        case abnormalColor = "Abnormal Color"
        case odorPresent = "Odor Present"
        case highPain = "High Pain Level"
        case fever = "Fever"
        case overdue = "Overdue Entry"
        
        var icon: String {
            switch self {
            case .highVolume: return "drop.fill"
            case .abnormalColor: return "eyedropper"
            case .odorPresent: return "nose.fill"
            case .highPain: return "heart.fill"
            case .fever: return "thermometer"
            case .overdue: return "clock.badge.exclamationmark"
            }
        }
        
        var color: Color {
            switch self {
            case .highVolume: return .red
            case .abnormalColor: return .orange
            case .odorPresent: return .yellow
            case .highPain: return .purple
            case .fever: return .red
            case .overdue: return .orange
            }
        }
    }
    
    enum AlertSeverity: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

struct PatientSummary: Identifiable {
    let id = UUID()
    let patientId: String
    let patientName: String
    let lastEntryDate: Date?
    let totalEntries: Int
    let averageVolume: Double
    let status: PatientStatus
    let assignedNurse: String?
    
    enum PatientStatus: String, CaseIterable {
        case active = "Active"
        case monitoring = "Monitoring"
        case discharged = "Discharged"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .active: return .green
            case .monitoring: return .blue
            case .discharged: return .gray
            case .critical: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .monitoring: return "eye.fill"
            case .discharged: return "person.fill.xmark"
            case .critical: return "exclamationmark.triangle.fill"
            }
        }
    }
}

struct DrainageTrend: Identifiable {
    let id = UUID()
    let date: Date
    let totalVolume: Double
    let entryCount: Int
    let averageVolume: Double
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let action: QuickActionType
    
    enum QuickActionType {
        case addEntry
        case patientList
        case criticalAlerts
        case reports
        case settings
        case notifications
    }
}

struct EducationalTip: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: TipCategory
    let icon: String
    
    enum TipCategory: String, CaseIterable {
        case aftercare = "Aftercare"
        case hygiene = "Hygiene"
        case nutrition = "Nutrition"
        case exercise = "Exercise"
        case medication = "Medication"
        
        var color: Color {
            switch self {
            case .aftercare: return .blue
            case .hygiene: return .green
            case .nutrition: return .orange
            case .exercise: return .purple
            case .medication: return .red
            }
        }
    }
}

// MARK: - Dashboard Data Models

struct NurseDashboardData {
    let stats: DashboardStats
    let assignedPatients: [PatientSummary]
    let recentEntries: [DrainageEntry]
    let overdueEntries: [DrainageEntry]
    let quickActions: [QuickAction]
}

struct PatientDashboardData {
    let stats: DashboardStats
    let recentEntries: [DrainageEntry]
    let drainageTrends: [DrainageTrend]
    let educationalTips: [EducationalTip]
    let alerts: [CriticalAlert]
    let upcomingDrainage: [UpcomingDrainageItem]?
    let latestComments: [LatestComment]?
}

// MARK: - API Response Models

struct DashboardAPIResponse: Codable {
    let success: Bool
    let data: DashboardAPIData
    let filter: DashboardFilter
    let errors: [String]
    let timestamp: String
    let message: String
}

struct DashboardAPIData: Codable {
    let totalDrainageCount: Int
    let drainageCount: Int
    let totalVolume: Double
    let averageVolume: Double
    let recentDrainage: [DrainageEntry]
    let drainageHistory: [DrainageHistoryItem]
    let healthTips: [HealthTip]?
}

struct DrainageHistoryItem: Codable {
    let label: String
    let value: Double
}

struct HealthTip: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let category: String
    let icon: String?
    
    var tipCategory: EducationalTip.TipCategory {
        switch category.lowercased() {
        case "hygiene": return .hygiene
        case "nutrition": return .nutrition
        case "aftercare": return .aftercare
        case "wellness": return .aftercare // Map wellness to aftercare
        case "activity": return .exercise
        default: return .aftercare
        }
    }
}

struct DashboardFilter: Codable {
    let drainageType: String
    let patientId: String
    let endDate: String
    let startDate: String
    let duration: String
}

// MARK: - Duration Options
enum DashboardDuration: String, CaseIterable {
    case today = "today"
    case week = "week"
    case month = "month"
    case overall = "overall"
    
    var displayName: String {
        switch self {
        case .today: return "Today's"
        case .week: return "Week"
        case .month: return "Month"
        case .overall: return "Overall"
        }
    }
}

enum LineChartDashboardDuration: String, CaseIterable {
    case week = "week"
    case month = "month"
    case last3month = "last3month"
    case last6month = "last6month"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Monthly"
        case .last3month: return "Last 3 Months"
        case .last6month: return "Last 6 Months"
        }
    }
}

// MARK: - Upcoming Drainage Models

struct UpcomingDrainageResponse: Codable {
    let success: Bool
    let data: UpcomingDrainageData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct UpcomingDrainageData: Codable {
    let upcomingDateTime: String
    let upcomingArray: [UpcomingDrainageItem]
}

struct UpcomingDrainageItem: Codable, Identifiable {
    let id: String
    let incidentId: String
    let incidentName: String
    let upcomingDateTime: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case incidentId
        case incidentName
        case upcomingDateTime
    }
    
    var formattedTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: upcomingDateTime) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            return timeFormatter.string(from: date)
        }
        return "N/A"
    }
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: upcomingDateTime) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "MM/dd/yyyy"
            return timeFormatter.string(from: date)
        }
        return "N/A"
    }
    
    var isUpcoming: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: upcomingDateTime) {
            return date > Date()
        }
        return false
    }
} 

// MARK: - Doctor Dashboard API Response Models

struct ActiveIncidentResponse: Codable {
    let success: Bool
    let data: ActiveIncidentData
    let filter: DashboardFilter
    let errors: [String]
    let tz: String
    let timestamp: String
    let message: String
}

struct ActiveIncidentData: Codable {
    let totalActive: Int
    let data: [DrainageTypeCount]
}

struct DrainageTypeCount: Codable {
    let drainageType: String
    let count: Int
}

struct DrainageStatsResponse: Codable {
    let success: Bool
    let data: DrainageStatsData
    let filter: DashboardFilter
    let errors: [String]
    let tz: String
    let timestamp: String
    let message: String
}

struct DrainageStatsData: Codable {
    let totalDrainageCount: Int
    let totalDrainageAmount: Int
    let byDrainageType: [DrainageTypeStats]
    let byPatient: [PatientDrainageStats]
}

struct DrainageTypeStats: Codable, Identifiable, Equatable {
    let id = UUID()
    let drainageType: String
    let count: Int
    let amount: Int
    
    static func == (lhs: DrainageTypeStats, rhs: DrainageTypeStats) -> Bool {
        return lhs.id == rhs.id
    }
}

struct PatientDrainageStats: Codable, Identifiable {
    let id = UUID()
    let patientId: String
    let patientName: String
    let count: Int
    let amount: Int
}

struct MissedDrainageResponse: Codable {
    let success: Bool
    let data: [MissedDrainageItem]
    let filter: MissedDrainageFilter
    let errors: [String]
    let tz: String
    let timestamp: String
    let message: String
}

struct MissedDrainageItem: Codable, Identifiable {
    let id: String
    let patientId: String
    let patientName: String
    let scheduleTime: String
    let incidentName: String
    let drainageType: String
    let incidentId: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case patientId
        case patientName
        case scheduleTime
        case incidentName
        case drainageType
        case incidentId
    }
    
    var formattedScheduleTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: scheduleTime) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            return timeFormatter.string(from: date)
        }
        return "N/A"
    }
    
    var relativeTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: scheduleTime) {
            return date.timeAgoDisplay()
        }
        return "N/A"
    }
}

struct MissedDrainageFilter: Codable {
    let drainageType: String
    let patientId: String
}

// MARK: - New API Response Models for Doctor Dashboard

// 1. Patient Stats API Response
struct PatientStatsResponse: Codable {
    let success: Bool
    let data: PatientStatsData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct PatientStatsData: Codable {
    let totalPatientCount: Int
    let totalIncidentCount: Int
    let totalDrainageCount: Int
    let totalClosedDrainageCount: Int
    let totalActiveDrainageCount: Int
    let totalActiveIncidentCount: Int
    let totalClosedIncidentCount: Int
    let patientList: [PatientStatsItem]
}

struct PatientStatsItem: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let userSlug: String
    let totalDrainageCount: Int
    let totalAmountCount: Int
    let totalIncidentCount: Int
    let totalActiveIncidentCount: Int
    let totalActiveDrainageCount: Int
    let totalActiveAmountCount: Int
    let totalClosedIncidentCount: Int
    let totalClosedAmountCount: Int
    let totalClosedDrainageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, lastName, userSlug, totalDrainageCount, totalAmountCount
        case totalIncidentCount, totalActiveIncidentCount, totalActiveDrainageCount
        case totalActiveAmountCount, totalClosedIncidentCount, totalClosedAmountCount
        case totalClosedDrainageCount
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// 2. Incident Stats API Response
struct IncidentStatsResponse: Codable {
    let success: Bool
    let data: IncidentStatsData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct IncidentStatsData: Codable {
    let totalIncidentCount: Int
    let totalDrainageCount: Int
    let totalAmountCount: Int
    let incidentList: [IncidentStatsItem]
}

struct IncidentStatsItem: Codable, Identifiable {
    let name: String
    let incidentId: String
    let status: String
    let patientId: String
    let patientName: String
    let patientData: PatientData? // New field for patient data including priority
    let id: String
    let totalDrainageCount: Int
    let totalAmountCount: Int
    
    enum CodingKeys: String, CodingKey {
        case name, incidentId, status, patientId, patientName, patientData
        case id = "_id"
        case totalDrainageCount, totalAmountCount
    }
}

// 3. Weekly Drainage API Response
struct WeeklyDrainageResponse: Codable {
    let success: Bool
    let data: [WeeklyDrainageItem]
    let errors: [String]
    let timestamp: String
    let message: String
}

struct WeeklyDrainageItem: Codable, Identifiable {
    let id = UUID()
    let dayName: String
    let drainageCount: Int
    let drainageAmount: Int
    
    enum CodingKeys: String, CodingKey {
        case dayName, drainageCount, drainageAmount
    }
}

// MARK: - Updated Doctor Dashboard Data Model
struct DoctorDashboardData {
    let stats: DoctorDashboardStats
    let criticalAlerts: [CriticalAlert]
    let patientSummaries: [PatientSummary]
    let drainageTrends: [DrainageTrend]
    let quickActions: [QuickAction]
    let missedDrainages: [MissedDrainageItem]
    let drainageTypeStats: [DrainageTypeStats]
    let patientDrainageStats: [PatientDrainageStats]
    let activeIncidents: [IncidentStatsItem]
    var weeklyDrainageData: [WeeklyDrainageItem]
    let drainageTypeNotifications: [DrainageTypeNotification]
}

struct DoctorDashboardStats {
    let totalPatients: Int
    let activeIncidents: Int
    let totalDrainageCount: Int
    let totalDrainageAmount: Int
}

// MARK: - Latest Comments Models
struct LatestComment: Identifiable, Codable {
    let id: String
    let patientId: String
    let patientName: String
    let drainageId: String
    let comment: String
    let userId: String
    let createdAt: String
    let incidentName: String?
    let incidentId: String?
    let userData: CommentUserData
    let commentId: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case patientId, patientName, drainageId, comment, userId, createdAt
        case incidentName, incidentId, userData, commentId
    }
}

struct CommentUserData: Codable {
    let id: String
    let firstName: String
    let email: String
    let role: String
    let userSlug: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName, email, role, userSlug
    }
}

struct LatestCommentsResponse: Codable {
    let success: Bool
    let data: [LatestComment]
    let errors: [String]
    let timestamp: String
    let message: String
}

// MARK: - Drainage Type Notification Models

struct DrainageTypeNotificationResponse: Codable {
    let success: Bool
    let data: [DrainageTypeNotification]
    let errors: [String]
    let timestamp: String
    let message: String
}

struct DrainageTypeNotification: Codable, Identifiable {
    let id: String
    let patientId: String
    let patientName: String
    let drainageType: String
    let userId: String
    let amount: Int
    let amountUnit: String
    let recordedAt: String
    let incident: DrainageNotificationIncident
    let drainageId: String
    let patientData: PatientData?
    let config: DrainageNotificationConfig?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case patientId, patientName, drainageType, userId, amount, amountUnit, recordedAt
        case incident, drainageId, patientData, config
    }
    
    var formattedRecordedAt: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: recordedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy h:mm a"
            return displayFormatter.string(from: date)
        }
        return "N/A"
    }
    
    var isExceedingMax: Bool {
        return amount > config?.maxAmount ?? 0
    }
    
    var minMaxDisplay: String {
        if config?.minAmount ?? 0 == 0 && config?.maxAmount ?? 0 == 0 {
            return ""
        }
        return "Max: \(config?.maxAmount ?? 0)\(amountUnit)"
    }
}

struct DrainageNotificationIncident: Codable {
    let id: String
    let name: String
    let drainageType: String
    let location: String
    let startDate: String
    let endDate: String
    let access: [String]
    let incidentId: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, drainageType, location, startDate, endDate, access, incidentId
    }
}

struct DrainageNotificationConfig: Codable {
    let type: String?
    let minAmount: Int?
    let maxAmount: Int?
    let avgAmount: Int?
    let priority: String?
}
