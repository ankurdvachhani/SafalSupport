import Foundation

// MARK: - Incident Report Model

struct IncidentReport: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let title: String
    let reportId: String
    let organizationId: String
    let refId: String
    let url: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case title
        case reportId
        case organizationId
        case refId
        case url
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        reportId = try container.decode(String.self, forKey: .reportId)
        organizationId = try container.decode(String.self, forKey: .organizationId)
        refId = try container.decode(String.self, forKey: .refId)
        url = try container.decode(String.self, forKey: .url)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    static func == (lhs: IncidentReport, rhs: IncidentReport) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Custom initializer for creating IncidentReport instances
    init(id: String, userId: String, title: String, reportId: String, organizationId: String, refId: String, url: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.title = title
        self.reportId = reportId
        self.organizationId = organizationId
        self.refId = refId
        self.url = url
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - API Response Models

struct IncidentReportListResponse: Codable {
    let success: Bool
    let data: [IncidentReport]
    let sort: IncidentSortInfo
    let pagination: IncidentPaginationInfo
    let errors: [String]
    let timestamp: String
    let message: String
}

struct IncidentSortInfo: Codable {
    let order: String
    let orderBy: String
}

struct IncidentPaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let current: Int
}

// MARK: - Incident Report Sort Options

enum IncidentReportSortOption: String, CaseIterable, Identifiable {
    case dateDesc = "Date (Latest First)"
    case dateAsc = "Date (Oldest First)"
    case titleAsc = "Title (A-Z)"
    case titleDesc = "Title (Z-A)"
    case reportIdAsc = "Report ID (A-Z)"
    case reportIdDesc = "Report ID (Z-A)"
    
    var id: String { rawValue }
    
    var sortDescriptor: (IncidentReport, IncidentReport) -> Bool {
        switch self {
        case .dateDesc:
            return { $0.createdAt > $1.createdAt }
        case .dateAsc:
            return { $0.createdAt < $1.createdAt }
        case .titleAsc:
            return { $0.title.lowercased() < $1.title.lowercased() }
        case .titleDesc:
            return { $0.title.lowercased() > $1.title.lowercased() }
        case .reportIdAsc:
            return { $0.reportId.lowercased() < $1.reportId.lowercased() }
        case .reportIdDesc:
            return { $0.reportId.lowercased() > $1.reportId.lowercased() }
        }
    }
    
    var vitalSignsSortDescriptor: (VitalSignsReport, VitalSignsReport) -> Bool {
        switch self {
        case .dateDesc:
            return { $0.createdAt > $1.createdAt }
        case .dateAsc:
            return { $0.createdAt < $1.createdAt }
        case .titleAsc:
            return { $0.title.lowercased() < $1.title.lowercased() }
        case .titleDesc:
            return { $0.title.lowercased() > $1.title.lowercased() }
        case .reportIdAsc:
            return { $0.reportId.lowercased() < $1.reportId.lowercased() }
        case .reportIdDesc:
            return { $0.reportId.lowercased() > $1.reportId.lowercased() }
        }
    }
    
    var apiOrderBy: String {
        switch self {
        case .dateDesc, .dateAsc:
            return "createdAt"
        case .titleAsc, .titleDesc:
            return "title"
        case .reportIdAsc, .reportIdDesc:
            return "reportId"
        }
    }
    
    var apiOrder: String {
        switch self {
        case .dateDesc, .titleDesc, .reportIdDesc:
            return "desc"
        case .dateAsc, .titleAsc, .reportIdAsc:
            return "asc"
        }
    }
}

// MARK: - Vital Signs Report Model

struct VitalSignsReport: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let title: String
    let reportId: String
    let organizationId: String
    let url: String
    let type: String
    let createdAt: Date
    let updatedAt: Date
    let urlSign:String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case title
        case reportId
        case organizationId
        case url
        case type
        case createdAt
        case updatedAt
        case urlSign
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        reportId = try container.decode(String.self, forKey: .reportId)
        organizationId = try container.decode(String.self, forKey: .organizationId)
        url = try container.decode(String.self, forKey: .url)
        type = try container.decode(String.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        urlSign = try container.decodeIfPresent(String.self, forKey: .urlSign)
    }
    
    static func == (lhs: VitalSignsReport, rhs: VitalSignsReport) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Custom initializer for creating VitalSignsReport instances
    init(id: String, userId: String, title: String, reportId: String, organizationId: String, url: String, type: String, createdAt: Date, updatedAt: Date, urlSign: String? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.reportId = reportId
        self.organizationId = organizationId
        self.url = url
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.urlSign = urlSign
    }
}

// MARK: - Vital Signs Report API Response Models

struct VitalSignsReportListResponse: Codable {
    let success: Bool
    let data: [VitalSignsReport]
    let sort: SortInfo
    let pagination: PaginationInfo
    let errors: [String]
    let timestamp: String
    let message: String
}

struct VitalSignsReportResponse: Codable {
    let success: Bool
    let data: VitalSignsReport
    let errors: [String]
    let timestamp: String
    let message: String
}

// MARK: - Vital Signs Report Generation Response

struct VitalSignsReportGenerationResponse: Codable {
    let success: Bool
    let data: VitalSignsReportGenerationData
    let errors: [String]
    let timestamp: String
    let message: String
}

struct VitalSignsReportGenerationData: Codable {
    let location: String
    let locationSign: String
}
