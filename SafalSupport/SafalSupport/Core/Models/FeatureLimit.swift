import Foundation

// MARK: - Feature Limit Models
struct FeatureLimit: Codable, Identifiable {
    let id: String
    let featureName: String
    let featureType: String
    let limitPrefix: String
    let limitSuffix: String
    let status: Bool
    let limit: Int
    let isUnlimited: Bool
    let usage: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "featureId"
        case featureName
        case featureType
        case limitPrefix
        case limitSuffix
        case status
        case limit
        case isUnlimited
        case usage
    }
}

struct FeatureLimitResponse: Codable {
    let success: Bool
    let errors: [String]
    let timestamp: String
    let message: String
    let data: [FeatureLimit]
}

// MARK: - Feature Limit Service
@MainActor
class FeatureLimitService: ObservableObject {
    @Published var featureLimits: [FeatureLimit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager()
    
    static let shared = FeatureLimitService()
    
    private init() {}
    
    func fetchFeatureLimits() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let endpoint = Endpoint(
                path: "/api/payment/feature-log",
                method: .get
            )
            
            print("🔧 Fetching feature limits...")
            
            let response: FeatureLimitResponse = try await networkManager.fetch(endpoint)
            
            if response.success {
                featureLimits = response.data
                print("✅ Feature limits fetched successfully: \(response.data.count) limits")
            } else {
                errorMessage = "Failed to fetch feature limits"
                print("❌ Feature limits fetch failed")
            }
        } catch {
            errorMessage = "Failed to fetch feature limits: \(error.localizedDescription)"
            print("❌ Feature limits fetch error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Feature Limit Checks
    
    /// Check if drainage creation is allowed
    func canCreateDrainage() -> (allowed: Bool, message: String?) {
        guard let drainageLimit = featureLimits.first(where: { $0.id == "drainageco-r78py0" }) else {
            return (true, nil) // If no limit found, allow creation
        }
        
        if drainageLimit.isUnlimited {
            return (true, nil)
        }
        
        if drainageLimit.usage >= drainageLimit.limit {
            return (false, "You have reached the maximum limit of \(drainageLimit.limit) drainage records. Please upgrade your plan to create more records.")
        }
        
        return (true, nil)
    }
    
    /// Check if incident creation is allowed
    func canCreateIncident() -> (allowed: Bool, message: String?) {
        guard let incidentLimit = featureLimits.first(where: { $0.id == "incidentco-ifendl" }) else {
            return (true, nil) // If no limit found, allow creation
        }
        
        if incidentLimit.isUnlimited {
            return (true, nil)
        }
        
        if incidentLimit.usage >= incidentLimit.limit {
            return (false, "You have reached the maximum limit of \(incidentLimit.limit) incidents. Please upgrade your plan to create more incidents.")
        }
        
        return (true, nil)
    }
    
    /// Check if drainage image upload is allowed (total limit across all image types)
    func canUploadDrainageImage(imageType: DrainageImageType, currentCount: Int) -> (allowed: Bool, message: String?) {
        guard let imageLimit = featureLimits.first(where: { $0.id == "drainageim-j836l9" }) else {
            return (true, nil) // If no limit found, allow upload
        }
        
        if imageLimit.isUnlimited {
            return (true, nil)
        }
        
        if currentCount >= imageLimit.limit {
            return (false, "You have reached the maximum limit of \(imageLimit.limit) total images across all categories (Before, After, Fluid Cup). Please upgrade your plan to upload more images.")
        }
        
        return (true, nil)
    }
    
    /// Get the maximum allowed total images across all types
    func getMaxImagesForType(_ imageType: DrainageImageType) -> Int {
        guard let imageLimit = featureLimits.first(where: { $0.id == "drainageim-j836l9" }) else {
            return Int.max // If no limit found, allow unlimited
        }
        
        if imageLimit.isUnlimited {
            return Int.max
        }
        
        return imageLimit.limit
    }
}

// MARK: - Drainage Image Type Enum
enum DrainageImageType: String, CaseIterable {
    case before = "before"
    case after = "after"
    case fluidCup = "fluidCup"
    
    var displayName: String {
        switch self {
        case .before:
            return "Before"
        case .after:
            return "After"
        case .fluidCup:
            return "Fluid Cup"
        }
    }
}
