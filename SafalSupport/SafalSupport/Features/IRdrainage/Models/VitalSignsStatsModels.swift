import Foundation

// MARK: - Vital Signs Stats Models

struct VitalSignsStatsResponse: Codable {
    let success: Bool
    let data: VitalSignsStatsData
    let filter: VitalSignsFilter
    let errors: [String]
    let tz: String
    let timestamp: String
    let message: String
}

struct VitalSignsStatsData: Codable {
    let temperature: VitalSignsMetric
    let heartRate: VitalSignsMetric
    let bloodPressureS: VitalSignsMetric
    let bloodPressureD: VitalSignsMetric
    let respiratoryRate: VitalSignsMetric
    let oxygenSaturation: VitalSignsMetric
}

struct VitalSignsMetric: Codable {
    let min: Double
    let max: Double
    let avg: Double
    let minColor: String
    let maxColor: String
    let avgColor: String
    let minStackedValue: Double
    let maxStackedValue: Double
    let avgStackedValue: Double
    let stackColor: String
    
    // Computed properties for difference calculations
    var minDifference: Double {
        return min - minStackedValue
    }
    
    var maxDifference: Double {
        return max - maxStackedValue
    }
    
    var avgDifference: Double {
        return avg - avgStackedValue
    }
}

struct VitalSignsFilter: Codable {
    let patientId: String?
    let incident: String?
    let duration: String
    let recordedAt: RecordedAtRange?
}

struct RecordedAtRange: Codable {
    let gte: String?
    let lte: String?
    
    enum CodingKeys: String, CodingKey {
        case gte = "$gte"
        case lte = "$lte"
    }
}

// MARK: - Duration Options

enum VitalSignsDuration: String, CaseIterable, Identifiable {
    case today = "today"
    case week = "week"
    case month = "month"
    case last3month = "last3month"
    case last6month = "last6month"
    case overall = "overall"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .last3month:
            return "Last 3 Months"
        case .last6month:
            return "Last 6 Months"
        case .overall:
            return "Overall"
        }
    }
}

// MARK: - Single Vital Signs Models

struct SingleVitalSignsResponse: Codable {
    let success: Bool
    let data: [SingleVitalSignData]
    let filter: SingleVitalSignsFilter
    let errors: [String]
    let tz: String
    let timestamp: String
    let message: String
}

struct SingleVitalSignData: Codable, Identifiable {
    let id: String
    let value: Double
    let value2: Double? // For blood pressure diastolic value
    let label: String
    let labelColor: String
    let drainageId: String
    let recordedAt: String
    let drainageType: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case value, value2, label, labelColor, drainageId, recordedAt, drainageType
    }
}

struct SingleVitalSignsFilter: Codable {
    let patientId: String?
    let incident: String?
    let duration: String
    let vitalType: String
    let recordedAt: RecordedAtRange?
    
    enum CodingKeys: String, CodingKey {
        case patientId, incident, duration, vitalType, recordedAt
    }
}

// MARK: - Vital Sign Types

enum VitalSignType: String, CaseIterable, Identifiable {
    case temperature = "temperature"
    case heartRate = "heartRate"
    case bloodPressure = "bloodPressure"
    case respiratoryRate = "respiratoryRate"
    case oxygenSaturation = "oxygenSaturation"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .temperature:
            return "Temperature"
        case .heartRate:
            return "Heart Rate"
        case .bloodPressure:
            return "Blood Pressure"
        case .respiratoryRate:
            return "Respiratory Rate"
        case .oxygenSaturation:
            return "Oxygen Saturation"
        }
    }
}

// MARK: - Chart Data Models

struct VitalSignsChartData: Identifiable {
    let id = UUID()
    let vitalSign: String
    let min: Double
    let max: Double
    let avg: Double
    
    var displayName: String {
        switch vitalSign {
        case "temperature":
            return "Temperature"
        case "heartRate":
            return "Heart Rate"
        case "bloodPressureS":
            return "BP - Systolic"
        case "bloodPressureD":
            return "BP - Diastolic"
        case "respiratoryRate":
            return "Respiratory Rate"
        case "oxygenSaturation":
            return "Oxygen Saturation"
        default:
            return vitalSign.capitalized
        }
    }
}
