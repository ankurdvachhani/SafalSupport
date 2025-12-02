import Foundation
import SwiftUI

// MARK: - Drainage Comment Model
struct DrainageComment: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let message: String
    let createdAt: Date
    let updatedAt: Date
    let user: CommentUser?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case message
        case createdAt
        case updatedAt
        case user
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        message = try container.decode(String.self, forKey: .message)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        user = try container.decodeIfPresent(CommentUser.self, forKey: .user)
    }
    
    static func == (lhs: DrainageComment, rhs: DrainageComment) -> Bool {
        return lhs.id == rhs.id && lhs.userId == rhs.userId && lhs.message == rhs.message && lhs.createdAt == rhs.createdAt && lhs.updatedAt == rhs.updatedAt && lhs.user == rhs.user
    }
}

// MARK: - Comment User Model
struct CommentUser: Identifiable, Codable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let userSlug: String
    let metadata: UserMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName
        case lastName
        case email
        case role
        case userSlug
        case metadata
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    static func == (lhs: CommentUser, rhs: CommentUser) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - User Metadata Model
struct UserMetadata: Codable, Equatable {
    let ncpiNumber: String?
    let organizationId: String?
}

struct DrainageEntry: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let patientId: String?
    let patientName: String?
    let patientData: PatientData? // New field for patient data including priority
    var amount: Double
    var amountUnit: String
    var location: String
    var fluidType: String
    var color: String
    var colorOther: String? // New field for "Other" color specification
    var consistency: [String] // New field for multiple selection consistency
    var odor: String // New field for odor selection
    var drainageType: String // New field for drainage type
    var isFluidSalineFlush: Bool? // New field for saline flush boolean
    var fluidSalineFlushAmount: Double? // New field for saline flush amount
    var fluidSalineFlushAmountUnit: String? // New field for saline flush amount unit
    var comments: String?
    var odorPresent: Bool?
    var painLevel: Int?
    var temperature: Double?
    var doctorNotified: Bool?
    var heartRate: Double?
    var bloodPressure: String?
    var respiratoryRate: Double?
    var oxygenSaturation: Double?
    var recordedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var beforeImage: [String]
    var afterImage: [String]
    var fluidCupImage: [String]
    var beforeImageSign: [String]?
    var afterImageSign: [String]?
    var fluidCupImageSign: [String]?
    var access: [String]?
    var accessData: [String]?
    var drainageId: String?
    var incidentId: String?
    var incident: Incident?
    var commentsArray: [DrainageComment]?
    var fieldConfig: [FieldConfig]?
    
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case patientId = "patientId"
        case patientName
        case patientData
        case amount
        case amountUnit
        case location
        case fluidType
        case color
        case colorOther
        case consistency
        case odor
        case drainageType
        case isFluidSalineFlush
        case fluidSalineFlushAmount
        case fluidSalineFlushAmountUnit
        case comments
        case odorPresent
        case painLevel
        case temperature
        case doctorNotified
        case heartRate
        case bloodPressure
        case respiratoryRate
        case oxygenSaturation
        case recordedAt
        case createdAt
        case updatedAt
        case beforeImage
        case afterImage
        case fluidCupImage
        case beforeImageSign
        case afterImageSign
        case fluidCupImageSign
        case access
        case accessData
        case drainageId
        case incidentId
        case incident
        case commentsArray
        case fieldConfig = "field"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        patientId = try container.decode(String.self, forKey: .patientId)
        patientName = try container.decode(String.self, forKey: .patientName)
        patientData = try container.decodeIfPresent(PatientData.self, forKey: .patientData)
        amount = try container.decode(Double.self, forKey: .amount)
        amountUnit = try container.decode(String.self, forKey: .amountUnit)
        location = try container.decode(String.self, forKey: .location)
        fluidType = try container.decode(String.self, forKey: .fluidType)
        color = try container.decode(String.self, forKey: .color)
        colorOther = try container.decodeIfPresent(String.self, forKey: .colorOther)
        consistency = try container.decodeIfPresent([String].self, forKey: .consistency) ?? []
        odor = try container.decodeIfPresent(String.self, forKey: .odor) ?? ""
        drainageType = try container.decodeIfPresent(String.self, forKey: .drainageType) ?? ""
        isFluidSalineFlush = try container.decodeIfPresent(Bool.self, forKey: .isFluidSalineFlush)
        fluidSalineFlushAmount = try container.decodeIfPresent(Double.self, forKey: .fluidSalineFlushAmount)
        fluidSalineFlushAmountUnit = try container.decodeIfPresent(String.self, forKey: .fluidSalineFlushAmountUnit)
        comments = try container.decode(String.self, forKey: .comments)
        odorPresent = try container.decodeIfPresent(Bool.self, forKey: .odorPresent)
        painLevel = try container.decode(Int.self, forKey: .painLevel)
        temperature = try container.decode(Double.self, forKey: .temperature)
        doctorNotified = try container.decode(Bool.self, forKey: .doctorNotified)
        heartRate = try container.decodeIfPresent(Double.self, forKey: .heartRate)
        bloodPressure = try container.decodeIfPresent(String.self, forKey: .bloodPressure)
        respiratoryRate = try container.decodeIfPresent(Double.self, forKey: .respiratoryRate)
        oxygenSaturation = try container.decodeIfPresent(Double.self, forKey: .oxygenSaturation)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        beforeImage = try container.decode([String].self, forKey: .beforeImage)
        afterImage = try container.decode([String].self, forKey: .afterImage)
        fluidCupImage = try container.decode([String].self, forKey: .fluidCupImage)
        beforeImageSign = try container.decodeIfPresent([String].self, forKey: .beforeImageSign)
        afterImageSign = try container.decodeIfPresent([String].self, forKey: .afterImageSign)
        fluidCupImageSign = try container.decodeIfPresent([String].self, forKey: .fluidCupImageSign)
        access = try container.decodeIfPresent([String].self, forKey: .access)
        accessData = try container.decodeIfPresent([String].self, forKey: .accessData)
        drainageId = try container.decodeIfPresent(String.self, forKey: .drainageId)
        incidentId = try container.decodeIfPresent(String.self, forKey: .incidentId)
        if let incidentObj = try? container.decode(Incident.self, forKey: .incident) {
               self.incident = incidentObj
               self.incidentId = incidentObj.id // if Incident has id
           } else if let incidentStr = try? container.decode(String.self, forKey: .incident) {
               self.incidentId = incidentStr
               self.incident = nil
           } else {
               self.incident = nil
               self.incidentId = nil
           }
        commentsArray = try container.decodeIfPresent([DrainageComment].self, forKey: .commentsArray)
        fieldConfig = try container.decodeIfPresent([FieldConfig].self, forKey: .fieldConfig)
    }
    
    init(id: String = "",
         userId: String = "",
         patientId: String,
         patientName: String,
         patientData: PatientData? = nil,
         amount: Double,
         amountUnit: String,
         location: String,
         fluidType: String,
         color: String,
         colorOther: String? = nil,
         consistency: [String] = [],
         odor: String = "",
         drainageType: String = "",
         isFluidSalineFlush: Bool? = nil,
         fluidSalineFlushAmount: Double? = nil,
         fluidSalineFlushAmountUnit: String? = nil,
         comments: String,
         odorPresent: Bool,
         painLevel: Int,
         temperature: Double,
         doctorNotified: Bool,
         heartRate: Double? = nil,
         bloodPressure: String? = nil,
         respiratoryRate: Double? = nil,
         oxygenSaturation: Double? = nil,
         recordedAt: Date,
         createdAt: Date,
         updatedAt: Date,
         beforeImage: [String] = [],
         afterImage: [String] = [],
         fluidCupImage: [String] = [],
         beforeImageSign: [String]? = nil,
         afterImageSign: [String]? = nil,
         fluidCupImageSign: [String]? = nil,
         access: [String] = [],
         accessData: [String] = [],
         drainageId: String? = nil,
         incidentId: String? = nil,
         incident: Incident? = nil,
         commentsArray: [DrainageComment]? = nil,
         fieldConfig: [FieldConfig]? = nil) {
        self.id = id
        self.userId = userId
        self.patientId = patientId
        self.patientName = patientName
        self.patientData = patientData
        self.amount = amount
        self.amountUnit = amountUnit
        self.location = location
        self.fluidType = fluidType
        self.color = color
        self.colorOther = colorOther
        self.consistency = consistency
        self.odor = odor
        self.drainageType = drainageType
        self.isFluidSalineFlush = isFluidSalineFlush
        self.fluidSalineFlushAmount = fluidSalineFlushAmount
        self.fluidSalineFlushAmountUnit = fluidSalineFlushAmountUnit
        self.comments = comments
        self.odorPresent = odorPresent
        self.painLevel = painLevel
        self.temperature = temperature
        self.doctorNotified = doctorNotified
        self.heartRate = heartRate
        self.bloodPressure = bloodPressure
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
        self.recordedAt = recordedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.beforeImage = beforeImage
        self.afterImage = afterImage
        self.fluidCupImage = fluidCupImage
        self.beforeImageSign = beforeImageSign
        self.afterImageSign = afterImageSign
        self.fluidCupImageSign = fluidCupImageSign
        self.access = access
        self.accessData = accessData
        self.drainageId = drainageId
        self.incidentId = incidentId
        self.incident = incident
        self.commentsArray = commentsArray
        self.fieldConfig = fieldConfig
    }
    
    static func == (lhs: DrainageEntry, rhs: DrainageEntry) -> Bool {
        return lhs.id == rhs.id &&
            lhs.userId == rhs.userId &&
            lhs.patientId == rhs.patientId &&
            lhs.patientName == rhs.patientName &&
            lhs.patientData == rhs.patientData &&
            lhs.amount == rhs.amount &&
            lhs.amountUnit == rhs.amountUnit &&
            lhs.location == rhs.location &&
            lhs.fluidType == rhs.fluidType &&
            lhs.color == rhs.color &&
            lhs.colorOther == rhs.colorOther &&
            lhs.consistency == rhs.consistency &&
            lhs.odor == rhs.odor &&
            lhs.drainageType == rhs.drainageType &&
            lhs.isFluidSalineFlush == rhs.isFluidSalineFlush &&
            lhs.fluidSalineFlushAmount == rhs.fluidSalineFlushAmount &&
            lhs.fluidSalineFlushAmountUnit == rhs.fluidSalineFlushAmountUnit &&
            lhs.comments == rhs.comments &&
            lhs.odorPresent == rhs.odorPresent &&
            lhs.painLevel == rhs.painLevel &&
            lhs.temperature == rhs.temperature &&
            lhs.doctorNotified == rhs.doctorNotified &&
            lhs.heartRate == rhs.heartRate &&
            lhs.bloodPressure == rhs.bloodPressure &&
            lhs.respiratoryRate == rhs.respiratoryRate &&
            lhs.oxygenSaturation == rhs.oxygenSaturation &&
            lhs.recordedAt == rhs.recordedAt &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt &&
            lhs.beforeImage == rhs.beforeImage &&
            lhs.afterImage == rhs.afterImage &&
            lhs.fluidCupImage == rhs.fluidCupImage &&
            lhs.beforeImageSign == rhs.beforeImageSign &&
            lhs.afterImageSign == rhs.afterImageSign &&
            lhs.fluidCupImageSign == rhs.fluidCupImageSign &&
            lhs.access == rhs.access &&
            lhs.accessData == rhs.accessData &&
            lhs.drainageId == rhs.drainageId &&
            lhs.incidentId == rhs.incidentId &&
            lhs.incident == rhs.incident &&
            lhs.commentsArray == rhs.commentsArray
    }
}

// MARK: - Drainage Sort Options
enum DrainageSortOption: String, CaseIterable, Identifiable {
    case dateDesc = "Date (Latest First)"
    case dateAsc = "Date (Oldest First)"
    case amountDesc = "Amount (High to Low)"
    case amountAsc = "Amount (Low to High)"
    case locationAsc = "Location (A-Z)"
    case locationDesc = "Location (Z-A)"
    case createdAtDesc = "Created (Latest First)"
    case createdAtAsc = "Created (Oldest First)"
    case painLevelDesc = "Pain Level (High to Low)"
    case painLevelAsc = "Pain Level (Low to High)"
    case temperatureDesc = "Temperature (High to Low)"
    case temperatureAsc = "Temperature (Low to High)"
    
    var id: String { rawValue }
    
    // API parameters for sorting
    var orderBy: String {
        switch self {
        case .dateDesc, .dateAsc:
            return "recordedAt"
        case .amountDesc, .amountAsc:
            return "amount"
        case .locationAsc, .locationDesc:
            return "location"
        case .createdAtDesc, .createdAtAsc:
            return "createdAt"
        case .painLevelDesc, .painLevelAsc:
            return "painLevel"
        case .temperatureDesc, .temperatureAsc:
            return "temperature"
        }
    }
    
    var order: String {
        switch self {
        case .dateDesc, .amountDesc, .locationDesc, .createdAtDesc, .painLevelDesc, .temperatureDesc:
            return "desc"
        case .dateAsc, .amountAsc, .locationAsc, .createdAtAsc, .painLevelAsc, .temperatureAsc:
            return "asc"
        }
    }
    
    var sortDescriptor: (DrainageEntry, DrainageEntry) -> Bool {
        switch self {
        case .dateDesc:
            return { $0.recordedAt > $1.recordedAt }
        case .dateAsc:
            return { $0.recordedAt < $1.recordedAt }
        case .amountDesc:
            return { $0.amount > $1.amount }
        case .amountAsc:
            return { $0.amount < $1.amount }
        case .locationAsc:
            return { $0.location < $1.location }
        case .locationDesc:
            return { $0.location > $1.location }
        case .createdAtDesc:
            return { $0.createdAt > $1.createdAt }
        case .createdAtAsc:
            return { $0.createdAt < $1.createdAt }
        case .painLevelDesc:
            return { ($0.painLevel ?? 0) > ($1.painLevel ?? 0) }
        case .painLevelAsc:
            return { ($0.painLevel ?? 0) < ($1.painLevel ?? 0) }
        case .temperatureDesc:
            return { ($0.temperature ?? 0) > ($1.temperature ?? 0) }
        case .temperatureAsc:
            return { ($0.temperature ?? 0) < ($1.temperature ?? 0) }
        }
    }
}

// MARK: - Fluid Types
extension DrainageEntry {
    static let fluidTypes = [
        "Blood",
        "Pus",
        "Lymph",
        "Serous",
        "Serosanguinous",
        "Other"
    ]
}

// MARK: - Color/Appearance Options
extension DrainageEntry {
    static let colorOptions = [
        "Clear",
        "Yellow",
        "Pink/Light Red",
        "Red/Bloody",
        "Green",
        "Brown",
        "Cloudy",
        "Other"
    ]
}

// MARK: - Consistency Options
extension DrainageEntry {
    static let consistencyOptions = [
        "Thin/Watery",
        "Thick",
        "Viscous/Sticky",
        "Contains debris",
        "Clots present",
        "Stones present",
        "Other"
    ]
}

// MARK: - Odor Options
extension DrainageEntry {
    static let odorOptions = [
        "None/Odorless",
        "Mild",
        "Strong",
        "Foul/Offensive",
        "Sweet",
        "Other"
    ]
}

// MARK: - Drainage Type Options
extension DrainageEntry {
    static let drainageTypeOptions = [
        "Jackson-Pratt (JP)",
        "Hemovac",
        "Penrose",
        "Blake",
        "Chest Tube",
        "Pigtail Catheter",
        "Percutaneous Drainage",
        "Foley Catheter",
        "Nephrostomy Tube",
        "Ureteral Stent",
        "Nasogastric (NG)",
        "PEG Tube",
        "T-Tube (Biliary)",
        "External Ventricular Drain",
        "Lumbar Drain",
        "VAC System",
        "Redivac",
        "Other"
    ]
}
