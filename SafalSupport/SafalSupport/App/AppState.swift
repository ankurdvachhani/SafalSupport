import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentTheme: Theme = .system
    @Published var selectedTab: Tab = .dashboard
    
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupSubscriptions()
        loadPersistedState()
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    func signOut() {
        TokenManager.shared.deleteToken()
        isAuthenticated = false
        // Reset app icon badge number to 0 on logout
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // Reset all shared view models
        resetSharedViewModels()
        
        // Clear dashboard preferences
        DoctorDashboardView.clearDashboardPreferences()
        
        // Reset navigation state
        NavigationManager.shared.goBackToRoot()
        NavigationManager.shared.dismiss()
    }
    
     private func resetSharedViewModels() {
        // Reset NotificationsViewModel
        let notificationsViewModel = NotificationsViewModel.shared
        notificationsViewModel.notifications.removeAll()
        notificationsViewModel.unreadCount = 0
        notificationsViewModel.moduleCounts.removeAll()
        notificationsViewModel.isLoading = false
        notificationsViewModel.error = nil
        
        print("🧹 [AppState] Reset all shared view models on logout")
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        // Add any state observation or Combine subscriptions here
        $currentTheme
            .dropFirst()
            .sink { [weak self] theme in
                self?.persistTheme(theme)
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedState() {
        // Load any persisted state here
        if let savedTheme = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = Theme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }
    
    private func checkAuthenticationStatus() {
        if TokenManager.shared.getToken() != nil {
            isAuthenticated = true
        } else {
            // Reset app icon badge number to 0 when no token is found
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    private func persistTheme(_ theme: Theme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
    }
}

// MARK: - Enums
extension AppState {
    enum Theme: String {
        case light
        case dark
        case system
    }
    
    enum Tab: String, Hashable {
        case Drainage
        case PatientList
        case dashboard
        case settings
        case IncidentList
        case report
        
        var title: String {
            switch self {
            case .PatientList: return "Patients"
            case .Drainage: return "Drainage"
            case .dashboard: return "Dashboard"
            case .IncidentList: return "IncidentList"
            case .settings: return "Settings"
                case .report: return "Report"
            }
        }
        
        var icon: String {
            switch self {
            case .Drainage: return "syringe"
            case .PatientList: return "person"
            case .dashboard: return "house"
            case .IncidentList:return "note.text.badge.plus"
            case .settings: return "gear"
            case .report: return "doc.text.viewfinder"
            }
        }
    }
} 
