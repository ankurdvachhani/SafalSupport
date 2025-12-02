import SwiftUI

/// Represents a navigation path in the app
struct NavigationPath: Identifiable, Hashable, Codable {
    let id: String
    let destination: NavigationDestination
    
    init(destination: NavigationDestination) {
        self.id = UUID().uuidString
        self.destination = destination
    }
    
    static func == (lhs: NavigationPath, rhs: NavigationPath) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents all possible navigation destinations in the app
enum NavigationDestination: Identifiable, Hashable, Codable {
    case drainageDetail(entry: DrainageEntry)
    case drainageDetailByDrainageId(drainageId: String)
    case addDrainage(entry: DrainageEntry? = nil)
    case addDrainageFromIncident(incident: Incident)
    case drainageListView(patientSlug: String? = nil, patientName: String? = nil, incidentId: String? = nil, incidentName: String? = nil, incidentDisplayId: String? = nil)
    case patientList
    case profile
    case settings
    case login
    case signUp(isOrganization: Bool)
    case forgotPassword
    case policyView(title: String, content: String, onAccept: () -> Void = {}, onReject: () -> Void = {})
    case changePassword
    case notificationview
    case notificationlistview(module: String)
    case dashboard
    case doctorDashboard
    case nurseDashboard
    case patientDashboard
    case doctorPatientDashboard(patient: PatientData)
    case barcodeScanner
    case educationalTips(tips: [EducationalTip])
    case incidentList(patientSlug: String? = nil, patientName: String? = nil)
    case incidentDetail(incident: Incident)
    case incidentDetailById(incidentId: String)
    case addIncident(incident: Incident? = nil, linkedFromIncident: Incident? = nil)
    case incidentReportList
    case drainageTypeNotificationsList(notifications: [DrainageTypeNotification])
    
    // MARK: - Identifiable Conformance
    var id: String {
        switch self {
        case .profile:
            return "profile"
        case .settings:
            return "settings"
        case .login:
            return "login"
        case .signUp(let isOrganization):
            return "signUp-\(isOrganization ? "org" : "individual")"
        case .forgotPassword:
            return "forgotPassword"
        case .policyView(let title, _, _, _):
            return "policyView-\(title)"
        case .changePassword:
            return "changePassword"
        case .notificationview:
            return "Notifications"
        case .notificationlistview(let module):
            return "Notifications List-\(module)"
        case .drainageDetail(let entry):
            return "drainageDetail-\(entry.id)"
        case .drainageDetailByDrainageId(let drainageId):
            return "drainageDetailByDrainageId-\(drainageId)"
        case .addDrainage(let entry):
            return "addDrainage-\(entry?.id ?? "new")"
        case .addDrainageFromIncident(let incident):
            return "addDrainageFromIncident-\(incident.id)"
        case .drainageListView(let patientSlug, let patientName, let incidentId, let incidentName, let incidentDisplayId):
            return "drainageListView-\(patientSlug ?? "all")-\(incidentId ?? "none")-\(incidentName ?? "none")-\(incidentDisplayId ?? "none")"
        case .patientList:
            return "patientList"
        case .dashboard:
            return "dashboard"
        case .doctorDashboard:
            return "doctorDashboard"
        case .nurseDashboard:
            return "nurseDashboard"
        case .patientDashboard:
            return "patientDashboard"
        case .doctorPatientDashboard(let patient):
            return "doctorPatientDashboard-\(patient.userSlug)"
        case .barcodeScanner:
            return "barcodeScanner"
        case .educationalTips:
            return "educationalTips"
        case .incidentList(let patientSlug, let patientName):
            return "incidentList-\(patientSlug ?? "all")"
        case .incidentDetail(let incident):
            return "incidentDetail-\(incident.id)"
        case .incidentDetailById(let incidentId):
            return "incidentDetailById-\(incidentId)"
        case .addIncident(let incident, let linkedFromIncident):
            return "addIncident-\(incident?.id ?? "new")-\(linkedFromIncident?.id ?? "no-link")"
        case .incidentReportList:
            return "incidentReportList"
        case .drainageTypeNotificationsList(let notifications):
            return "drainageTypeNotificationsList-\(notifications.count)"
        }
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .profile:
            hasher.combine("profile")
        case .settings:
            hasher.combine("settings")
        case .login:
            hasher.combine("login")
        case .signUp(let isOrganization):
            hasher.combine("signUp")
            hasher.combine(isOrganization)
        case .forgotPassword:
            hasher.combine("forgotPassword")
        case .policyView(let title, let content, _, _):
            hasher.combine("policyView")
            hasher.combine(title)
            hasher.combine(content)
        case .changePassword:
            hasher.combine("changePassword")
        case .notificationview:
            hasher.combine("notificationview")
        case .notificationlistview(let module):
            hasher.combine("notificationlistview")
            hasher.combine(module)
        case .drainageListView:
            hasher.combine("drainageListView")
        case .drainageDetail(let entry):
            hasher.combine("drainageDetail")
            hasher.combine(entry.id)
        case .drainageDetailByDrainageId(let drainageId):
            hasher.combine("drainageDetailByDrainageId")
            hasher.combine(drainageId)
        case .addDrainage(let entry):
            hasher.combine("addDrainage")
            hasher.combine(entry?.id ?? "new")
        case .addDrainageFromIncident(let incident):
            hasher.combine("addDrainageFromIncident")
            hasher.combine(incident.id)
        case .drainageListView(let patientSlug, let patientName, let incidentId, let incidentName, let incidentDisplayId):
            hasher.combine("drainageListView")
            hasher.combine(patientSlug ?? "all")
            hasher.combine(incidentId ?? "none")
            hasher.combine(incidentName ?? "none")
            hasher.combine(incidentDisplayId ?? "none")
        case .patientList:
            hasher.combine("patientList")
        case .dashboard:
            hasher.combine("dashboard")
        case .doctorDashboard:
            hasher.combine("doctorDashboard")
        case .nurseDashboard:
            hasher.combine("nurseDashboard")
        case .patientDashboard:
            hasher.combine("patientDashboard")
        case .doctorPatientDashboard(let patient):
            hasher.combine("doctorPatientDashboard")
            hasher.combine(patient.userSlug)
        case .barcodeScanner:
            hasher.combine("barcodeScanner")
        case .educationalTips:
            hasher.combine("educationalTips")
        case .incidentList(let patientSlug, let patientName):
            hasher.combine("incidentList")
            hasher.combine(patientSlug ?? "all")
        case .incidentDetail(let incident):
            hasher.combine("incidentDetail")
            hasher.combine(incident.id)
        case .incidentDetailById(let incidentId):
            hasher.combine("incidentDetailById")
            hasher.combine(incidentId)
        case .addIncident(let incident, let linkedFromIncident):
            hasher.combine("addIncident")
            hasher.combine(incident?.id ?? "new")
            hasher.combine(linkedFromIncident?.id ?? "no-link")
        case .incidentReportList:
            hasher.combine("incidentReportList")
        case .drainageTypeNotificationsList(let notifications):
            hasher.combine("drainageTypeNotificationsList")
            hasher.combine(notifications.count)
        }
    }
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case type, id, isOrganization, title, content, initialDate, module, entry, patientSlug, patientName, patient, incident, incidentId, incidentName, incidentDisplayId, linkedFromIncident
    }
    
    private enum DestinationType: String, Codable {
        case  profile, settings
        case login, signUp, forgotPassword, policyView
        case changePassword
        case  notificationview, notificationlistview
        case drainageListView, drainageDetail, drainageDetailByDrainageId, addDrainage, addDrainageFromIncident
        case patientList
        case dashboard, doctorDashboard, nurseDashboard, patientDashboard, doctorPatientDashboard, barcodeScanner, educationalTips, incidentList, incidentDetail, incidentDetailById, addIncident, incidentReportList, drainageTypeNotificationsList
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .profile:
            try container.encode(DestinationType.profile, forKey: .type)
        case .settings:
            try container.encode(DestinationType.settings, forKey: .type)
        case .login:
            try container.encode(DestinationType.login, forKey: .type)
        case .signUp(let isOrganization):
            try container.encode(DestinationType.signUp, forKey: .type)
            try container.encode(isOrganization, forKey: .isOrganization)
        case .forgotPassword:
            try container.encode(DestinationType.forgotPassword, forKey: .type)
        case .policyView(let title, let content, _, _):
            try container.encode(title, forKey: .title)
            try container.encode(content, forKey: .content)
            try container.encode(DestinationType.policyView, forKey: .type)
        case .changePassword:
            try container.encode(DestinationType.changePassword, forKey: .type)
        case .notificationview:
            try container.encode(DestinationType.notificationview, forKey: .type)
        case .notificationlistview(let module):
            try container.encode(DestinationType.notificationlistview, forKey: .type)
            try container.encode(module, forKey: .module)
        case .drainageListView(let patientSlug, let patientName, let incidentId, let incidentName, let incidentDisplayId):
            try container.encode(DestinationType.drainageListView, forKey: .type)
            try container.encode(patientSlug, forKey: .patientSlug)
            try container.encode(patientName, forKey: .patientName)
            try container.encode(incidentId, forKey: .incidentId)
            try container.encode(incidentName, forKey: .incidentName)
            try container.encode(incidentDisplayId, forKey: .incidentDisplayId)
        case .drainageDetail(let entry):
            try container.encode(DestinationType.drainageDetail, forKey: .type)
            try container.encode(entry, forKey: .entry)
        case .drainageDetailByDrainageId(let drainageId):
            try container.encode(DestinationType.drainageDetailByDrainageId, forKey: .type)
            try container.encode(drainageId, forKey: .id)
        case .addDrainage(let entry):
            try container.encode(DestinationType.addDrainage, forKey: .type)
            try container.encode(entry, forKey: .entry)
        case .addDrainageFromIncident(let incident):
            try container.encode(DestinationType.addDrainageFromIncident, forKey: .type)
            try container.encode(incident, forKey: .incident)
        case .patientList:
            try container.encode(DestinationType.patientList, forKey: .type)
        case .dashboard:
            try container.encode(DestinationType.dashboard, forKey: .type)
        case .doctorDashboard:
            try container.encode(DestinationType.doctorDashboard, forKey: .type)
        case .nurseDashboard:
            try container.encode(DestinationType.nurseDashboard, forKey: .type)
        case .patientDashboard:
            try container.encode(DestinationType.patientDashboard, forKey: .type)
        case .doctorPatientDashboard(let patient):
            try container.encode(DestinationType.doctorPatientDashboard, forKey: .type)
            try container.encode(patient, forKey: .patient)
        case .barcodeScanner:
            try container.encode(DestinationType.barcodeScanner, forKey: .type)
        case .educationalTips(let tips):
            try container.encode(DestinationType.educationalTips, forKey: .type)
            // Note: EducationalTip array encoding would need to be handled separately
            // For now, we'll use a simple approach
        case .incidentList(let patientSlug, let patientName):
            try container.encode(DestinationType.incidentList, forKey: .type)
            try container.encode(patientSlug, forKey: .patientSlug)
            try container.encode(patientName, forKey: .patientName)
        case .incidentDetail(let incident):
            try container.encode(DestinationType.incidentDetail, forKey: .type)
            try container.encode(incident, forKey: .incident)
        case .incidentDetailById(let incidentId):
            try container.encode(DestinationType.incidentDetailById, forKey: .type)
            try container.encode(incidentId, forKey: .incidentId)
        case .addIncident(let incident, let linkedFromIncident):
            try container.encode(DestinationType.addIncident, forKey: .type)
            try container.encodeIfPresent(incident, forKey: .incident)
            try container.encodeIfPresent(linkedFromIncident, forKey: .linkedFromIncident)
        case .incidentReportList:
            try container.encode(DestinationType.incidentReportList, forKey: .type)
        case .drainageTypeNotificationsList(let notifications):
            try container.encode(DestinationType.drainageTypeNotificationsList, forKey: .type)
            // Note: We'll encode the count as a simple identifier since the full array might be too large
            try container.encode(notifications.count, forKey: .id)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DestinationType.self, forKey: .type)
        
        switch type {
        case .profile:
            self = .profile
        case .settings:
            self = .settings
        case .login:
            self = .login
        case .signUp:
            let isOrganization = try container.decode(Bool.self, forKey: .isOrganization)
            self = .signUp(isOrganization: isOrganization)
        case .forgotPassword:
            self = .forgotPassword
        case .policyView:
            let title = try container.decode(String.self, forKey: .title)
            let content = try container.decode(String.self, forKey: .content)
            self = .policyView(title: title, content: content)
        case .changePassword:
            self = .changePassword
        case .notificationview:
            self = .notificationview
        case .notificationlistview:
            let module = try container.decode(String.self, forKey: .module)
            self = .notificationlistview(module: module)
        case .drainageListView:
            let patientSlug = try? container.decode(String?.self, forKey: .patientSlug)
            let patientName = try? container.decode(String?.self, forKey: .patientName)
            let incidentId = try? container.decode(String?.self, forKey: .incidentId)
            let incidentName = try? container.decode(String?.self, forKey: .incidentName)
            let incidentDisplayId = try? container.decode(String?.self, forKey: .incidentDisplayId)
            self = .drainageListView(patientSlug: patientSlug, patientName: patientName, incidentId: incidentId, incidentName: incidentName, incidentDisplayId: incidentDisplayId)
        case .drainageDetail:
            let entry = try container.decode(DrainageEntry.self, forKey: .entry)
            self = .drainageDetail(entry: entry)
        case .drainageDetailByDrainageId:
            let drainageId = try container.decode(String.self, forKey: .id)
            self = .drainageDetailByDrainageId(drainageId: drainageId)
        case .addDrainage:
            let entry = try? container.decode(DrainageEntry?.self, forKey: .entry)
            self = .addDrainage(entry: entry)
        case .addDrainageFromIncident:
            let incident = try container.decode(Incident.self, forKey: .incident)
            self = .addDrainageFromIncident(incident: incident)
        case .patientList:
            self = .patientList
        case .dashboard:
            self = .dashboard
        case .doctorDashboard:
            self = .doctorDashboard
        case .nurseDashboard:
            self = .nurseDashboard
        case .patientDashboard:
            self = .patientDashboard
        case .doctorPatientDashboard:
            let patient = try container.decode(PatientData.self, forKey: .patient)
            self = .doctorPatientDashboard(patient: patient)
        case .barcodeScanner:
            self = .barcodeScanner
        case .educationalTips:
            // For now, return empty array - in a real app, you'd need to handle this properly
            self = .educationalTips(tips: [])
        case .incidentList:
            let patientSlug = try? container.decode(String?.self, forKey: .patientSlug)
            let patientName = try? container.decode(String?.self, forKey: .patientName)
            self = .incidentList(patientSlug: patientSlug, patientName: patientName)
        case .incidentDetail:
            let incident = try container.decode(Incident.self, forKey: .incident)
            self = .incidentDetail(incident: incident)
        case .incidentDetailById:
            let incidentId = try container.decode(String.self, forKey: .incidentId)
            self = .incidentDetailById(incidentId: incidentId)
        case .addIncident:
            let incident = try? container.decode(Incident?.self, forKey: .incident)
            let linkedFromIncident = try? container.decode(Incident?.self, forKey: .linkedFromIncident)
            self = .addIncident(incident: incident, linkedFromIncident: linkedFromIncident)
        case .incidentReportList:
            self = .incidentReportList
        case .drainageTypeNotificationsList:
            // For decoding, we'll create an empty array since we can't decode the full notifications
            // This is a limitation of Codable with complex data structures
            self = .drainageTypeNotificationsList(notifications: [])
        }
    }
    
    @MainActor @ViewBuilder
    func view() -> some View {
        switch self {
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        case .login:
            LoginView()
        case .signUp(let isOrganization):
            SignUpView()
        case .forgotPassword:
            ForgotPasswordView()
        case .policyView(let title, let content, let onAccept, let onReject):
            PolicyView(title: title, content: content, onAccept: onAccept, onReject: onReject)
        case .changePassword:
            ChangePasswordView()
        case .notificationview:
            NotificationsView()
        case .notificationlistview(let module):
            NotificationsListView(module: module)
        case .drainageListView(let patientSlug, let patientName, let incidentId, let incidentName, let incidentDisplayId):
            DrainageListView(patientSlug: patientSlug, patientName: patientName, incidentId: incidentId, incidentName: incidentName, incidentDisplayId: incidentDisplayId)
                .environmentObject(DrainageStore(patientSlug: patientSlug, incidentId: incidentId))
        case .drainageDetail(let entry):
            DrainageDetailView(entry: entry)
                .environmentObject(DrainageStore())
                .dismissKeyboardOnTap()
        case .drainageDetailByDrainageId(let drainageId):
            DrainageDetailByDrainageIdView(drainageId: drainageId)
                .environmentObject(DrainageStore())
                .dismissKeyboardOnTap()
        case .addDrainage(let entry):
            AddDrainageView(entry: entry)
                .environmentObject(DrainageStore())
        case .addDrainageFromIncident(let incident):
            AddDrainageView(incident: incident)
                .environmentObject(DrainageStore())
        case .patientList:
            PatientListView()
        case .dashboard:
            DashboardView()
        case .doctorDashboard:
            DoctorDashboardView(viewModel: DashboardViewModel())
        case .nurseDashboard:
            NurseDashboardView(viewModel: DashboardViewModel())
        case .patientDashboard:
            PatientDashboardView(viewModel: DashboardViewModel())
        case .doctorPatientDashboard(let patient):
            DoctorPatientDashboardView(viewModel: DashboardViewModel(patient: patient))
        case .barcodeScanner:
            BarcodeScannerView()
        case .educationalTips(let tips):
            EducationalTipsView(tips: tips)
        case .incidentList(let patientSlug, let patientName):
            IncidentListView(patientSlug: patientSlug, patientName: patientName)
        case .incidentDetail(let incident):
            IncidentDetailView(incident: incident)
                .environmentObject(IncidentStore())
        case .incidentDetailById(let incidentId):
            IncidentDetailView(incidentId: incidentId)
                .environmentObject(IncidentStore())
        case .addIncident(let incident, let linkedFromIncident):
            AddIncidentView(incidentToEdit: incident, linkedFromIncident: linkedFromIncident)
                .environmentObject(IncidentStore())
        case .incidentReportList:
            IncidentReportListView()
        case .drainageTypeNotificationsList(let notifications):
            DrainageTypeNotificationsListView(notifications: notifications)
        }
    }
}

/// Represents different types of navigation presentations
enum NavigationStyle {
    case push(withAccentColor: Color? = nil)
    case present(style: UIModalPresentationStyle = .automatic, withAccentColor: Color? = nil)
    case presentFullScreen(withAccentColor: Color? = nil)
    case presentSheet(withAccentColor: Color? = nil)
}

/// Main navigation manager class
@MainActor
final class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var paths: [NavigationDestination] = []
    @Published var presentedSheet: NavigationDestination?
    @Published var presentedFullScreen: NavigationDestination?
    private var previousAccentColor: UIColor?
    
    private init() {}
    
    // MARK: - Navigation Methods
    
    /// Navigate to a destination
    func navigate(to destination: NavigationDestination, style: NavigationStyle = .push()) {
        let accentColor: UIColor?
        
        switch style {
        case .push(let color):
            paths.append(destination)
            accentColor = color?.uiColor
        case .present(let presentationStyle, let color):
            switch presentationStyle {
            case .pageSheet, .formSheet:
                presentedSheet = destination
            default:
                presentedFullScreen = destination
            }
            accentColor = color?.uiColor
        case .presentFullScreen(let color):
            presentedFullScreen = destination
            accentColor = color?.uiColor
        case .presentSheet(let color):
            presentedSheet = destination
            accentColor = color?.uiColor
        }
        
        if let color = accentColor {
            previousAccentColor = UIView.appearance(whenContainedInInstancesOf: [UINavigationController.self]).tintColor
            UIView.appearance(whenContainedInInstancesOf: [UINavigationController.self]).tintColor = color
        }
    }
    
    /// Go back one screen
    func goBack() {
        if !paths.isEmpty {
            paths.removeLast()
        }
    }
    
    /// Go back to root
    func goBackToRoot() {
        paths.removeAll()
    }
    
    /// Go back to a specific destination
    func goBackTo(_ destination: NavigationDestination) {
        if let index = paths.firstIndex(where: { $0 == destination }) {
            paths = Array(paths[0...index])
        }
    }
    
    /// Dismiss presented sheet or full-screen view
    func dismiss() {
        presentedSheet = nil
        presentedFullScreen = nil
        // Restore previous accent color
        if let previousColor = previousAccentColor {
            UIView.appearance(whenContainedInInstancesOf: [UINavigationController.self]).tintColor = previousColor
            previousAccentColor = nil
        }
    }
    
    /// Replace entire navigation stack with new destination
    func replace(with destination: NavigationDestination) {
        paths = [destination]
    }
    
    /// Pop to previous view controller
    func popToPrevious() {
        if paths.count > 1 {
            paths.removeLast()
        }
    }
    
    /// Check if a specific destination is in the navigation stack
    func contains(_ destination: NavigationDestination) -> Bool {
        paths.contains(destination)
    }
}

// MARK: - View Extensions
extension View {
    /// Add navigation handling to a view
    func withNavigation() -> some View {
        NavigationStack(path: Binding(
            get: { NavigationManager.shared.paths },
            set: { NavigationManager.shared.paths = $0 }
        )) {
            self
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destination.view()
                }
                .sheet(item: Binding(
                    get: { NavigationManager.shared.presentedSheet },
                    set: { NavigationManager.shared.presentedSheet = $0 }
                )) { destination in
                    destination.view()
                }
                .fullScreenCover(item: Binding(
                    get: { NavigationManager.shared.presentedFullScreen },
                    set: { NavigationManager.shared.presentedFullScreen = $0 }
                )) { destination in
                    destination.view()
                }
        }
    }
    
    /// Add a custom back button
    func customBackButton() -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    NavigationManager.shared.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.accent)
                }
            }
        }
    }
}

extension Color {
    var uiColor: UIColor {
        UIColor(self)
    }
} 
