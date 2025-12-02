import Foundation

@MainActor
final class TermsAndPrivacyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var termsAndConditionsContent: String = ""
    @Published var privacyPolicyContent: String = ""
    @Published var termsAndConditionsId: String = ""
    @Published var privacyPolicyId: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let networkManager: NetworkManager
    private let application = APIConfig.applicationId
    
    // MARK: - Initialization
    init(networkManager: NetworkManager = NetworkManager()) {
        self.networkManager = networkManager
    }
    
    // MARK: - Public Methods
    func fetchTermsAndConditions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await networkManager.fetchPolicyData(
                type: "TermsAndConditions",
                application: application
            )
            
            termsAndConditionsContent = response.data.content ?? ""
            termsAndConditionsId = response.data.id ?? ""
            
        } catch let error as NetworkError {
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchPrivacyPolicy() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await networkManager.fetchPolicyData(
                type: "PrivacyPolicy",
                application: application
            )
            
            privacyPolicyContent = response.data.content ?? ""
            privacyPolicyId = response.data.id ?? ""
            
        } catch let error as NetworkError {
            errorMessage = NetworkErrorHandler.handle(error: error)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
} 
