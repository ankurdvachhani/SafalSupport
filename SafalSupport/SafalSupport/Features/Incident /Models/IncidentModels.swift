import Foundation
import SwiftUI

// MARK: - Field Configuration Model

struct FieldConfig: Identifiable, Codable, Equatable {
    let id: String
    var fieldKey: String
    var value: FieldConfigValue
    var isDefault: Bool
    var isHidden: Bool
    var isRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case fieldKey
        case value
        case isDefault = "default"
        case isHidden = "hidden"
        case isRequired = "required"
    }
    
    init(fieldKey: String = "",
         value: FieldConfigValue = .string(""),
         isDefault: Bool = false,
         isHidden: Bool = false,
         isRequired: Bool = false,
         id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.fieldKey = fieldKey
        self.value = value
        self.isDefault = isDefault
        self.isHidden = isHidden
        self.isRequired = isRequired
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        fieldKey = try container.decode(String.self, forKey: .fieldKey)
        value = try {
            if let intVal = try? container.decode(Int.self, forKey: .value) {
                return .int(intVal)
            } else if let doubleVal = try? container.decode(Double.self, forKey: .value) {
                return .double(doubleVal)
            } else if let boolVal = try? container.decode(Bool.self, forKey: .value) {
                return .bool(boolVal)
            } else if let strArray = try? container.decode([String].self, forKey: .value) {
                return .stringArray(strArray)
            } else if let strVal = try? container.decode(String.self, forKey: .value) {
                return .string(strVal)
            }
            throw DecodingError.typeMismatch(
                FieldConfigValue.self,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type for value")
            )
        }()
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fieldKey, forKey: .fieldKey)
        try container.encode(value, forKey: .value)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(isRequired, forKey: .isRequired)
    }
    
    static func == (lhs: FieldConfig, rhs: FieldConfig) -> Bool {
        return lhs.id == rhs.id &&
               lhs.fieldKey == rhs.fieldKey &&
               lhs.value == rhs.value &&
               lhs.isDefault == rhs.isDefault &&
               lhs.isHidden == rhs.isHidden &&
               lhs.isRequired == rhs.isRequired
    }
}

enum FieldConfigValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let strArray = try? container.decode([String].self) {
            self = .stringArray(strArray)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                FieldConfigValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let intVal):
            try container.encode(intVal)
        case .double(let doubleVal):
            try container.encode(doubleVal)
        case .bool(let boolVal):
            try container.encode(boolVal)
        case .string(let strVal):
            try container.encode(strVal)
        case .stringArray(let arrVal):
            try container.encode(arrVal)
        }
    }
}

extension FieldConfigValue {
    var displayText: String {
        switch self {
        case .string(let str):
            return str
        case .int(let intVal):
            return String(intVal)
        case .double(let doubleVal):
            return String(format: "%.1f", doubleVal)
        case .bool(let boolVal):
            return boolVal ? "Yes" : "No"
        case .stringArray(let arr):
            return arr.joined(separator: ", ")
        }
    }
}

// MARK: - Notification Model

struct NotificationRule: Identifiable, Codable, Equatable {
    let id: String
    var fieldKey: String
    var condition: String
    var value: NotificationValue
    var notificationLevel: String
    var ageMin: Int?
    var ageMax: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fieldKey
        case condition
        case value
        case notificationLevel
        case ageMin
        case ageMax
    }
    
    init(fieldKey: String = "",
            condition: String = "",
            value: NotificationValue = .string(""),
            notificationLevel: String = "HIGH",
            ageMin: Int? = nil,
            ageMax: Int? = nil,
            id: String? = nil) {
           self.id = id ?? UUID().uuidString
           self.fieldKey = fieldKey
           self.condition = condition
           self.value = value
           self.notificationLevel = notificationLevel
           self.ageMin = ageMin
           self.ageMax = ageMax
       }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        fieldKey = try container.decode(String.self, forKey: .fieldKey)
        condition = try container.decode(String.self, forKey: .condition)
        value = try {
            if let intVal = try? container.decodeIfPresent(Int.self, forKey: .value) {
                return .int(intVal)
            } else if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .value) {
                return .double(doubleVal)
            } else if let strArray = try? container.decodeIfPresent([String].self, forKey: .value) {
                return .stringArray(strArray)
            } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .value) {
                return .string(strVal)
            }
            throw DecodingError.typeMismatch(
                NotificationValue.self,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type for value")
            )
        }()
        notificationLevel = try container.decode(String.self, forKey: .notificationLevel)
        ageMin = try container.decodeIfPresent(Int.self, forKey: .ageMin)
        ageMax = try container.decodeIfPresent(Int.self, forKey: .ageMax)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fieldKey, forKey: .fieldKey)
        try container.encode(condition, forKey: .condition)
        try container.encode(value, forKey: .value)
        try container.encode(notificationLevel, forKey: .notificationLevel)
        try container.encodeIfPresent(ageMin, forKey: .ageMin)
        try container.encodeIfPresent(ageMax, forKey: .ageMax)
    }
    
    static func == (lhs: NotificationRule, rhs: NotificationRule) -> Bool {
        return lhs.id == rhs.id &&
               lhs.fieldKey == rhs.fieldKey &&
               lhs.condition == rhs.condition &&
               lhs.value == rhs.value &&
               lhs.notificationLevel == rhs.notificationLevel &&
               lhs.ageMin == rhs.ageMin &&
               lhs.ageMax == rhs.ageMax
    }
}

enum NotificationValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case stringArray([String])
    case bool(Bool)
    case null
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let strArray = try? container.decode([String].self) {
            self = .stringArray(strArray)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else if container.decodeNil() {
            self = .null
        } else {
            print("⚠️ Unsupported NotificationValue:", decoder.codingPath.map { $0.stringValue }.joined(separator: " -> "))
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let intVal):
            try container.encode(intVal)
        case .double(let doubleVal):
            try container.encode(doubleVal)
        case .bool(let boolVal):
            try container.encode(boolVal)
        case .string(let strVal):
            try container.encode(strVal)
        case .stringArray(let arrVal):
            try container.encode(arrVal)
        case .null, .unknown:
            try container.encodeNil()
        }
    }
}

extension NotificationValue {
    var displayText: String {
        switch self {
        case .string(let str):
            return str
        case .int(let intVal):
            return String(intVal)
        case .double(let doubleVal):
            // Pretty print: 100.5 → "100.5", 100.0 → "100"
            if doubleVal.rounded() == doubleVal {
                return String(Int(doubleVal))
            } else {
                return String(doubleVal)
            }
        case .bool(let boolVal):
            return boolVal ? "True" : "False"
        case .stringArray(let arr):
            return arr.joined(separator: ", ")
        case .null:
            return "—"
        case .unknown:
            return "Unsupported"
        }
    }
}

// MARK: - Schedule Model

struct Schedule: Identifiable, Codable, Equatable {
    let id: String
    var startDate: Date
    var endDate: Date
    var interval: String
    var duration: Int
    var recurring: Bool
    var dateTimeArray: [Date]
    var notificationBuffer: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case startDate
        case endDate
        case interval
        case duration
        case recurring
        case dateTimeArray
        case notificationBuffer
    }
    
    init(startDate: Date, endDate: Date, interval: String = "", duration: Int = 0, recurring: Bool = false, dateTimeArray: [Date] = [], notificationBuffer: Int = 30, id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.startDate = startDate
        self.endDate = endDate
        self.interval = interval
        self.duration = duration
        self.recurring = recurring
        self.dateTimeArray = dateTimeArray
        self.notificationBuffer = notificationBuffer
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        interval = try container.decode(String.self, forKey: .interval)
        duration = try container.decode(Int.self, forKey: .duration)
        recurring = try container.decode(Bool.self, forKey: .recurring)
        dateTimeArray = try container.decode([Date].self, forKey: .dateTimeArray)
        notificationBuffer = try container.decode(Int.self, forKey: .notificationBuffer)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(interval, forKey: .interval)
        try container.encode(duration, forKey: .duration)
        try container.encode(recurring, forKey: .recurring)
        try container.encode(dateTimeArray, forKey: .dateTimeArray)
        try container.encode(notificationBuffer, forKey: .notificationBuffer)
    }
    
    static func == (lhs: Schedule, rhs: Schedule) -> Bool {
        return lhs.id == rhs.id &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.interval == rhs.interval &&
               lhs.duration == rhs.duration &&
               lhs.recurring == rhs.recurring &&
               lhs.dateTimeArray == rhs.dateTimeArray &&
               lhs.notificationBuffer == rhs.notificationBuffer
    }
}

// MARK: - Linked Incident Model

struct LinkedIncident: Identifiable, Codable, Equatable {
    let id: String
    let incident: LinkedIncidentData?
    let linkedDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case incident
        case linkedDate
    }
    
    init(incident: LinkedIncidentData? = nil, linkedDate: Date, id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.incident = incident
        self.linkedDate = linkedDate
    }
    
    // Convenience initializer for backward compatibility
    init(incidentId: String, linkedDate: Date, id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.incident = LinkedIncidentData(id: incidentId)
        self.linkedDate = linkedDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        
        // Handle both string (old format) and object (new format) for incident
        if let incidentString = try? container.decode(String.self, forKey: .incident) {
            // Old format: incident is just a string ID
            incident = LinkedIncidentData(id: incidentString)
        } else {
            // New format: incident is a full object
            incident = try container.decode(LinkedIncidentData.self, forKey: .incident)
        }
        
        // Decode linkedDate - handle both ISO 8601 string and timestamp formats
        if let linkedDateString = try? container.decode(String.self, forKey: .linkedDate) {
            // Try ISO 8601 format first
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: linkedDateString) {
                linkedDate = date
            } else {
                // Fallback to timestamp format
                if let timestamp = Double(linkedDateString) {
                    linkedDate = Date(timeIntervalSince1970: timestamp)
                } else {
                    linkedDate = Date()
                }
            }
        } else if let timestamp = try? container.decode(Double.self, forKey: .linkedDate) {
            // Handle timestamp format
            linkedDate = Date(timeIntervalSince1970: timestamp)
        } else {
            linkedDate = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(incident, forKey: .incident)
        
        // Format linkedDate as ISO 8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let linkedDateString = dateFormatter.string(from: linkedDate)
        try container.encode(linkedDateString, forKey: .linkedDate)
    }
    
    static func == (lhs: LinkedIncident, rhs: LinkedIncident) -> Bool {
        return lhs.id == rhs.id &&
               lhs.incident == rhs.incident &&
               lhs.linkedDate == rhs.linkedDate
    }
}

// MARK: - Linked Incident Data Model

struct LinkedIncidentData: Identifiable, Codable, Equatable {
    let id: String
    let name: String?
    let patientName: String?
    let patientId: String?
    let drainageType: String?
    let location: String?
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let catheterInsertionDate: Date?
    let status: String?
    let incidentId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let linked: [LinkedIncident]?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case patientName
        case patientId
        case drainageType
        case location
        case description
        case startDate
        case endDate
        case catheterInsertionDate = "catheterInsertion"
        case status
        case incidentId
        case createdAt
        case updatedAt
        case linked
    }
    
    init(id: String, 
         name: String? = nil,
         patientName: String? = nil,
         patientId: String? = nil,
         drainageType: String? = nil,
         location: String? = nil,
         description: String? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         catheterInsertionDate: Date? = nil,
         status: String? = nil,
         incidentId: String? = nil,
         createdAt: Date? = nil,
         updatedAt: Date? = nil,
         linked: [LinkedIncident]? = nil) {
        self.id = id
        self.name = name
        self.patientName = patientName
        self.patientId = patientId
        self.drainageType = drainageType
        self.location = location
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.catheterInsertionDate = catheterInsertionDate
        self.status = status
        self.incidentId = incidentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linked = linked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        patientName = try container.decodeIfPresent(String.self, forKey: .patientName)
        patientId = try container.decodeIfPresent(String.self, forKey: .patientId)
        drainageType = try container.decodeIfPresent(String.self, forKey: .drainageType)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        catheterInsertionDate = try container.decodeIfPresent(Date.self, forKey: .catheterInsertionDate)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        incidentId = try container.decodeIfPresent(String.self, forKey: .incidentId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        linked = try container.decodeIfPresent([LinkedIncident].self, forKey: .linked)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(patientName, forKey: .patientName)
        try container.encodeIfPresent(patientId, forKey: .patientId)
        try container.encodeIfPresent(drainageType, forKey: .drainageType)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(catheterInsertionDate, forKey: .catheterInsertionDate)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(incidentId, forKey: .incidentId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(linked, forKey: .linked)
    }
    
    static func == (lhs: LinkedIncidentData, rhs: LinkedIncidentData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.patientName == rhs.patientName &&
               lhs.patientId == rhs.patientId &&
               lhs.drainageType == rhs.drainageType &&
               lhs.location == rhs.location &&
               lhs.description == rhs.description &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.catheterInsertionDate == rhs.catheterInsertionDate &&
               lhs.status == rhs.status &&
               lhs.incidentId == rhs.incidentId &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.linked == rhs.linked
    }
}

// MARK: - Incident Model

struct Incident: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let patientId: String
    let patientName: String
    let patientData: PatientData? // New field for patient data including priority
    var name: String
    var drainageType: String
    var location: String
    var description: String?
    var startDate: Date
    var endDate: Date
    var catheterInsertionDate: Date?
    var access: [String]
    var schedule: [Schedule]?
    var notification: [NotificationRule]?
    var fieldConfig: [FieldConfig]?
    var createdAt: Date
    var updatedAt: Date
    var incidentId: String?
    var drainageCount: Int?
    var status: String
    var linked: [LinkedIncident]?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case patientId
        case patientName
        case patientData
        case name
        case drainageType
        case location
        case description
        case startDate
        case endDate
        case catheterInsertionDate
        case access
        case schedule
        case notification
        case fieldConfig = "field"
        case createdAt
        case updatedAt
        case incidentId
        case drainageCount
        case status
        case linked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? "1"
        patientId = try container.decodeIfPresent(String.self, forKey: .patientId) ?? ""
        patientName = try container.decodeIfPresent(String.self, forKey: .patientName) ?? ""
        patientData = try container.decodeIfPresent(PatientData.self, forKey: .patientData)
        name = try container.decode(String.self, forKey: .name)
        drainageType = try container.decode(String.self, forKey: .drainageType)
        location = try container.decode(String.self, forKey: .location)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        catheterInsertionDate = try container.decodeIfPresent(Date.self, forKey: .catheterInsertionDate)
        access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
        schedule = try container.decodeIfPresent([Schedule].self, forKey: .schedule)
        notification = try container.decodeIfPresent([NotificationRule].self, forKey: .notification)
        fieldConfig = try container.decodeIfPresent([FieldConfig].self, forKey: .fieldConfig)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        incidentId = try container.decodeIfPresent(String.self, forKey: .incidentId)
        drainageCount = try container.decodeIfPresent(Int.self, forKey: .drainageCount)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Active"
        linked = try container.decodeIfPresent([LinkedIncident].self, forKey: .linked)
    }
    
    init(id: String = "",
         userId: String = "",
         patientId: String,
         patientName: String,
         patientData: PatientData? = nil,
         name: String,
         drainageType: String,
         location: String,
         description: String? = nil,
         startDate: Date,
         endDate: Date,
         catheterInsertionDate: Date? = nil,
         access: [String] = [],
         schedule: [Schedule]? = nil,
         notification: [NotificationRule]? = nil,
         fieldConfig: [FieldConfig]? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         incidentId: String? = nil,
         drainageCount: Int? = nil,
         status: String = "Active",
         linked: [LinkedIncident]? = nil) {
        self.id = id
        self.userId = userId
        self.patientId = patientId
        self.patientName = patientName
        self.patientData = patientData
        self.name = name
        self.drainageType = drainageType
        self.location = location
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.catheterInsertionDate = catheterInsertionDate
        self.access = access
        self.schedule = schedule
        self.notification = notification
        self.fieldConfig = fieldConfig
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.incidentId = incidentId
        self.drainageCount = drainageCount
        self.status = status
        self.linked = linked
    }
    
    static func == (lhs: Incident, rhs: Incident) -> Bool {
        return lhs.id == rhs.id &&
            lhs.userId == rhs.userId &&
            lhs.patientId == rhs.patientId &&
            lhs.patientName == rhs.patientName &&
            lhs.patientData == rhs.patientData &&
            lhs.name == rhs.name &&
            lhs.drainageType == rhs.drainageType &&
            lhs.location == rhs.location &&
            lhs.description == rhs.description &&
            lhs.startDate == rhs.startDate &&
            lhs.endDate == rhs.endDate &&
            lhs.catheterInsertionDate == rhs.catheterInsertionDate &&
            lhs.access == rhs.access &&
            lhs.schedule == rhs.schedule &&
            lhs.notification == rhs.notification &&
            lhs.fieldConfig == rhs.fieldConfig &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt &&
            lhs.incidentId == rhs.incidentId &&
            lhs.drainageCount == rhs.drainageCount &&
            lhs.status == rhs.status &&
            lhs.linked == rhs.linked
    }
}

// MARK: - API Response Models

struct IncidentResponse: Codable {
    let success: Bool
    let data: [Incident]
    let sort: SortInfo
    let pagination: PaginationInfo
    let errors: [String]
    let timestamp: String
    let message: String
}

struct SingleIncidentResponse: Codable {
    let success: Bool
    let data: Incident
    let errors: [String]
    let timestamp: String
    let message: String
}




// MARK: - Request Models

struct IncidentRequest: Codable {
    let patientId: String
    let name: String
    let patientName: String
    let location: String
    let drainageType: String
    let startDate: String
    let endDate: String
    let catheterInsertion: String?
    let description: String?
    let access: [String]
    let schedule: [ScheduleRequest]?
    let notification: [NotificationRule]?
    let field: [FieldConfig]?
    let status: String?
    let linked: [LinkedIncidentRequest]?
}

// MARK: - Linked Incident Request Model for API
struct LinkedIncidentRequest: Codable {
    let incident: String
    let linkedDate: String
    
    init(from linkedIncident: LinkedIncident) {
        self.incident = linkedIncident.incident?.id ?? ""
        self.linkedDate = Self.dateToISO8601(linkedIncident.linkedDate)
    }
    
    private static func dateToISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

// MARK: - Schedule Request Model for API
struct ScheduleRequest: Codable {
    let id: String
    let startDate: String
    let endDate: String
    let interval: String
    let duration: Int
    let recurring: Bool
    let dateTimeArray: [String]
    let notificationBuffer: Int
    
    init(from schedule: Schedule) {
        self.id = schedule.id
        self.startDate = Self.dateToISO8601(schedule.startDate)
        self.endDate = Self.dateToISO8601(schedule.endDate)
        self.interval = schedule.interval
        self.duration = schedule.duration
        self.recurring = schedule.recurring
        self.dateTimeArray = schedule.dateTimeArray.map { Self.dateToISO8601($0) }
        self.notificationBuffer = schedule.notificationBuffer
    }
    
    private static func dateToISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

// MARK: - Incident Filter Model
struct IncidentFilter {
    var drainageType: [String] = []
    var status: String?
    var patientId: String?
    var isSelfCreated: Bool = false
    
    var hasActiveFilters: Bool {
        return !drainageType.isEmpty || status != nil || patientId != nil || isSelfCreated
    }
    
    mutating func clearAll() {
        drainageType.removeAll()
        status = nil
        patientId = nil
        isSelfCreated = false
    }
}

// MARK: - Incident Sort Options

enum IncidentSortOption: String, CaseIterable, Identifiable {
    case dateDesc = "Date (Latest First)"
    case dateAsc = "Date (Oldest First)"
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case patientAsc = "Patient (A-Z)"
    case patientDesc = "Patient (Z-A)"
    case statusActive = "Status (Active First)"
    case statusClosed = "Status (Closed First)"
    
    var id: String { rawValue }
    
    var sortDescriptor: (Incident, Incident) -> Bool {
        switch self {
        case .dateDesc:
            return { $0.createdAt > $1.createdAt }
        case .dateAsc:
            return { $0.createdAt < $1.createdAt }
        case .nameAsc:
            return { $0.name.lowercased() < $1.name.lowercased() }
        case .nameDesc:
            return { $0.name.lowercased() > $1.name.lowercased() }
        case .patientAsc:
            return { $0.patientName.lowercased() < $1.patientName.lowercased() }
        case .patientDesc:
            return { $0.patientName.lowercased() > $1.patientName.lowercased() }
        case .statusActive:
            return { $0.status == "Active" && $1.status != "Active" }
        case .statusClosed:
            return { $0.status == "Closed" && $1.status != "Closed" }
        }
    }
    
    var apiOrderBy: String {
        switch self {
        case .dateDesc, .dateAsc:
            return "createdAt"
        case .nameAsc, .nameDesc:
            return "name"
        case .patientAsc, .patientDesc:
            return "patientName"
        case .statusActive, .statusClosed:
            return "status"
        }
    }
    
    var apiOrder: String {
        switch self {
        case .dateDesc, .nameDesc, .patientDesc, .statusActive:
            return "desc"
        case .dateAsc, .nameAsc, .patientAsc, .statusClosed:
            return "asc"
        }
    }
}

// MARK: - Nurse Data Model

struct NurseData: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String?
    let userSlug: String
    let role: String
    let status: String
    let profilePicture: String?
    let phoneNumber: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName
        case lastName
        case email
        case userSlug
        case role
        case status
        case profilePicture
        case phoneNumber
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        userSlug = try container.decode(String.self, forKey: .userSlug)
        role = try container.decode(String.self, forKey: .role)
        status = try container.decode(String.self, forKey: .status)
        profilePicture = try container.decodeIfPresent(String.self, forKey: .profilePicture)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    static func == (lhs: NurseData, rhs: NurseData) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(firstName)
        hasher.combine(lastName)
        hasher.combine(userSlug)
    }
}

struct NurseListResponse: Codable {
    let success: Bool
    let data: [NurseData]
    let pagination: PaginationInfo
    let errors: [String]
    let timestamp: String
    let message: String
}

// MARK: - Report Response Models

struct ReportResponse: Codable {
    let success: Bool
    let data: ReportData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct ReportData: Codable {
    let location: String?
    let locationSign: String?
}


struct incidentReportResponse: Codable {
    let success: Bool
    let data: incidentReportData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct incidentReportData: Codable {
    let id: String
    let userId: String
    let reportId: String
    let v: Int
    let title: String
    let organizationId: String
    let refId: String
    let updatedAt: String
    let createdAt: String
    let urlSign: String?
    let url: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case reportId
        case v = "__v"
        case title
        case organizationId
        case refId
        case updatedAt
        case createdAt
        case urlSign
        case url
    }
}
