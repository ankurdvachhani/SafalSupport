import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var qaManager: QuickActionsManager
    @StateObject private var navigationManager = NavigationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var notificationsViewModel = NotificationsViewModel.shared
    @StateObject private var updateViewModel = UpdateAlertViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var biometricService = BiometricAuthenticationService.shared
    @State private var isFirstAppear = true
    @State private var shouldRefreshList = false
    @State private var biometricAuthRequired = true
    @State private var biometricAuthCompleted = false
    
    var body: some View {
        ZStack {
            if !networkMonitor.isConnected {
                NoInternetView()
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(2)
            }
            
            ZStack {
                if appState.isAuthenticated {
                    // Check if biometric authentication is required and completed
                    // Only require biometric if it's available, enabled, and not completed
                    if biometricAuthRequired && !biometricAuthCompleted && 
                       biometricService.isBiometricAvailable && biometricService.isBiometricAuthenticationEnabled() {
                        BiometricAuthRequiredView(
                            biometricService: biometricService,
                            onBiometricSuccess: {
                                biometricAuthCompleted = true
                            },
                            onBiometricFailure: {
                                // If biometric fails, logout user
                                appState.signOut()
                                biometricAuthCompleted = false
                            }
                        )
                    } else {
                        mainView
                            .task {
                                await notificationsViewModel.fetchNotificationCount()
                                await FeatureLimitService.shared.fetchFeatureLimits()
                               // notificationsViewModel.startPollingNotifications()
                            }
                    }
                } else {
                    LoginView()
                }
            }
            .opacity(networkMonitor.isConnected ? 1 : 0.3)
        }
        .onChange(of: qaManager.quickAction) { newValue in
            print("Quick Action changed: \(String(describing: newValue))")
            handleQAData()
        }
        .onAppear {
            // Check for stored shortcut item only on first appear
            if isFirstAppear {
                checkStoredShortcutItem()
                isFirstAppear = false
            }
            
            // Reset biometric authentication requirement when app appears
            if appState.isAuthenticated {
                biometricAuthRequired = true
                biometricAuthCompleted = false
            }
        }
        .onChange(of: appState.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Reset biometric authentication when user logs in
                biometricAuthRequired = true
                biometricAuthCompleted = false
            } else {
                // Reset when user logs out
                biometricAuthRequired = true
                biometricAuthCompleted = false
            }
        }
        .onChange(of: biometricService.isBiometricAuthenticationEnabled()) { isEnabled in
            // If biometric is disabled, mark as completed to skip authentication
            if !isEnabled {
                biometricAuthCompleted = true
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .withNavigation()
        .withThemeColors()
        .sheet(isPresented: $updateViewModel.isPresented, content: {
            UpdateAlertView(
                updateStatus: updateViewModel.updateStatus,
                version: updateViewModel.version,
                onUpdate: {
                    updateViewModel.openAppStore()
                },
                onLater: {
                    updateViewModel.isPresented = false
                }
            )
            .interactiveDismissDisabled(updateViewModel.updateStatus == .force)
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.hidden)
        })
        .task {
            await updateViewModel.checkForUpdates()
        }
    }
    
    private func checkStoredShortcutItem() {
        // Check for stored shortcut item in UserDefaults
        if let storedShortcutType = UserDefaults.standard.string(forKey: "LaunchShortcutItemType") {
            print("Found stored shortcut item: \(storedShortcutType)")
            
            // Handle the stored shortcut item
            // add delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.handleQuickAction(storedShortcutType)
            }
          
            
            // Clear the stored shortcut item
            UserDefaults.standard.removeObject(forKey: "LaunchShortcutItemType")
            UserDefaults.standard.removeObject(forKey: "LaunchShortcutItemUserInfo")
            UserDefaults.standard.synchronize()
        }
    }
    private func handleQuickAction(_ actionType: String) {
        print("Handling quick action: \(actionType)")
        
        // Ensure this runs on the main thread and only when authenticated
        DispatchQueue.main.async {
            guard appState.isAuthenticated else {
                print("User not authenticated, cannot handle quick action")
                return
            }
            
            switch actionType {
            case "com.yourapp.createMeeting":
                appState.selectedTab = .Drainage
            case "com.yourapp.MeetingList":
                appState.selectedTab = .Drainage
                
            case "com.yourapp.report":
                appState.selectedTab = .Drainage
                
            case "com.yourapp.createEvent":
                appState.selectedTab = .Drainage
            case "com.yourapp.eventList":
                appState.selectedTab = .Drainage
                
                
            default:
                print("Unknown quick action: \(actionType)")
                appState.selectedTab = .Drainage
            }
        }
    }
    
    private func handleQAData() {
        guard appState.isAuthenticated else { return }
        
        switch qaManager.quickAction {
        case .createMeeting:
            appState.selectedTab = .Drainage
        case .meetingList:
            appState.selectedTab = .Drainage
        case .createEvent:
            appState.selectedTab = .Drainage
        case .eventList:
            appState.selectedTab = .Drainage
        case .report:
            appState.selectedTab = .Drainage
        case nil:
            print("No quick action")
        }
        
        // Reset the quick action
        qaManager.quickAction = nil
        // Clear the stored shortcut item
        UserDefaults.standard.removeObject(forKey: "LaunchShortcutItemType")
        UserDefaults.standard.removeObject(forKey: "LaunchShortcutItemUserInfo")
        UserDefaults.standard.synchronize()
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader()

            // Tab View
            TabView(selection: $appState.selectedTab) {
                
                Home()
                    .tag(AppState.Tab.dashboard)
                    .tabItem {
                        Image(systemName: "house")
//                        Image("dashboard") // ✅ your custom image
//                            .renderingMode(.template)
                        Text("Home")
                    }

                
//                if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
//                    PatientListView()
//                      .tag(AppState.Tab.PatientList)
//                      .tabItem {
//                          Image(systemName: "person")
//                          Text("Patients")
//                      }
//                }
                
//                IRDrainageView()
//                    .tag(AppState.Tab.Drainage)
//                    .tabItem {
//                      //  Image(systemName: "syringe")
//                        Image("tab_dranage_icon") // ✅ your custom image
//                            .renderingMode(.template)
//                        Text("Drainage")
//                    }
//                    .id(appState.selectedTab)

             
//                IncidentListView()
//                    .tag(AppState.Tab.IncidentList)
//                    .tabItem {
//                      //  Image(systemName: "note.text.badge.plus")
//                        Image("incident_icon")
//                            .renderingMode(.template) 
//                        Text("Incident")
//                    }
//                    .id(appState.selectedTab)
                
//                ReportView()
//                    .tag(AppState.Tab.report)
//                    .tabItem {
//                        Image("scroll-text")
//                            .renderingMode(.template)
//                        Text("Report")
//                    }
//                    .id(appState.selectedTab)
                
                
                SettingsView()
                    .tag(AppState.Tab.settings)
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
            .tint(Color.dynamicAccent)
        }
        .edgesIgnoringSafeArea(.top)
    }
}



struct AppHeader: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var notificationsViewModel = NotificationsViewModel.shared
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Color(.systemBackground)
                .frame(height: UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows
                    .first?.safeAreaInsets.top ?? 0)

            HStack(spacing: 16) {
                // App Title
                Image("Manual")
                    .resizable()
                    .frame(width: 25, height: 25)
                
                Text("SafalSupport")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent)
                    .offset(x: -10)

                Spacer()
                
//                // User Profile Image with Notification Indicator
//                Button(action: {
//                    NavigationManager.shared.navigate(to: .profile)
//                }) {
//                    ZStack(alignment: .topTrailing) {
//                        // User Profile Image
//                        if let profilePictureUrl = viewModel.profile.profilePictureUrl,
//                           !profilePictureUrl.isEmpty {
//                            AsyncImage(url: URL(string: profilePictureUrl)) { phase in
//                                switch phase {
//                                case let .success(image):
//                                    image
//                                        .resizable()
//                                        .frame(width: 30, height: 30)
//                                        .clipShape(Circle())
//                                case .failure:
//                                    if let fullName = TokenManager.shared.getUserName() {
//                                        let nameParts = fullName.split(separator: " ")
//                                        let initials = nameParts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
//                                        
//                                        Text(initials.uppercased())
//                                            .font(.system(size: 15, weight: .bold))
//                                            .foregroundColor(.white)
//                                            .frame(width: 30, height: 30)
//                                            .background(Circle().fill(Color.dynamicAccent))
//                                    } else {
//                                        Image(systemName: "person.circle.fill")
//                                            .font(.system(size: 30))
//                                            .foregroundColor(Color.dynamicAccent)
//                                    }
//                                case .empty:
//                                    if let fullName = TokenManager.shared.getUserName() {
//                                        let nameParts = fullName.split(separator: " ")
//                                        let initials = nameParts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
//                                        
//                                        Text(initials.uppercased())
//                                            .font(.system(size: 15, weight: .bold))
//                                            .foregroundColor(.white)
//                                            .frame(width: 30, height: 30)
//                                            .background(Circle().fill(Color.dynamicAccent))
//                                    } else {
//                                        Image(systemName: "person.circle.fill")
//                                            .font(.system(size: 30))
//                                            .foregroundColor(Color.dynamicAccent)
//                                    }
//                                @unknown default:
//                                    if let fullName = TokenManager.shared.getUserName() {
//                                        let nameParts = fullName.split(separator: " ")
//                                        let initials = nameParts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
//                                        
//                                        Text(initials.uppercased())
//                                            .font(.system(size: 15, weight: .bold))
//                                            .foregroundColor(.white)
//                                            .frame(width: 30, height: 30)
//                                            .background(Circle().fill(Color.dynamicAccent))
//                                    } else {
//                                        Image(systemName: "person.circle.fill")
//                                            .font(.system(size: 30))
//                                            .foregroundColor(Color.dynamicAccent)
//                                    }
//                                }
//                            }
//                        } else {
//                            if let fullName = TokenManager.shared.getUserName() {
//                                let nameParts = fullName.split(separator: " ")
//                                let initials = nameParts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
//                                
//                                Text(initials.uppercased())
//                                    .font(.system(size: 15, weight: .bold))
//                                    .foregroundColor(.white)
//                                    .frame(width: 30, height: 30)
//                                    .background(Circle().fill(Color.dynamicAccent))
//                            } else {
//                                Image(systemName: "person.circle.fill")
//                                    .font(.system(size: 30))
//                                    .foregroundColor(Color.dynamicAccent)
//                            }
//                        }
//                    }
//                }
//                .buttonStyle(PlainButtonStyle())
//                
//               Button(action: {
//                   print("🔔 Notification button tapped")
//                   NavigationManager.shared.navigate(to: .notificationview, style: .push(withAccentColor: Color.dynamicAccent))
//               }) {
//                   ZStack(alignment: .topTrailing) {
//                       Image(systemName: "bell")
//                           .font(.system(size: 20, weight: .medium))
//                           .foregroundColor(Color.dynamicAccent)
//                       
//                       if notificationsViewModel.unreadCount > 0 {
//                           Text("\(notificationsViewModel.unreadCount)")
//                               .font(.system(size: 12, weight: .bold))
//                               .foregroundColor(.white)
//                               .padding(4)
//                               .background(Color.red)
//                               .clipShape(Circle())
//                               .offset(x: 10, y: -10)
//                       }
//                   }
//               }
//               
//               Button(action: {
//                   NavigationManager.shared.navigate(to: .barcodeScanner, style: .presentFullScreen())
//               }) {
//                   Image(systemName: "barcode.viewfinder")
//                       .font(.system(size: 20, weight: .medium))
//                       .foregroundColor(Color.dynamicAccent)
//               }
//                
//                Button(action: {
//                    NavigationManager.shared.navigate(to: .settings, style: .push(withAccentColor: nil))
//                }) {
//                    Image(systemName: "gear")
//                        .font(.system(size: 20, weight: .medium))
//                        .foregroundColor(Color.dynamicAccent)
//                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .task {
            await notificationsViewModel.fetchNotificationCount()
            await viewModel.fetchProfile()
        }
        .onAppear {
            print("🔔 AppHeader appeared - notification button should be working")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}



class QuickActionsManager: ObservableObject {
    static let instance = QuickActionsManager()
    @Published var quickAction: shortQuickAction? = nil

    func handleQaItem(_ item: UIApplicationShortcutItem) {
        print("Shortcut tapped: \(item.type)")
        switch item.type {
        case "com.yourapp.createMeeting":
            quickAction = .createMeeting
        case "com.yourapp.MeetingList":
            quickAction = .meetingList
        case "com.yourapp.report":
            quickAction = .report
        case "com.yourapp.createEvent":
            quickAction = .createEvent
        case "com.yourapp.eventList":
            quickAction = .eventList
        default:
            quickAction = nil
        }
    }
}

enum shortQuickAction: Hashable {
    case createMeeting
    case meetingList
    case report
    case createEvent
    case eventList
}

// MARK: - Biometric Authentication Required View
struct BiometricAuthRequiredView: View {
    @ObservedObject var biometricService: BiometricAuthenticationService
    let onBiometricSuccess: () -> Void
    let onBiometricFailure: () -> Void
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Biometric Icon
                Image(systemName: biometricService.biometricType.iconName)
                    .font(.system(size: 80))
                    .foregroundColor(.dynamicAccent)
                    .frame(width: 120, height: 120)
                    .background(Color.dynamicAccent.opacity(0.1))
                    .clipShape(Circle())
                
                // Title and Description
                VStack(spacing: 16) {
                    Text("Biometric Authentication Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Please authenticate using \(biometricService.biometricType.displayName) to access the app")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Authentication Button
                Button(action: {
                    authenticateWithBiometrics()
                }) {
                    HStack(spacing: 12) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: biometricService.biometricType.iconName)
                                .font(.title3)
                        }
                        
                        Text(isAuthenticating ? "Authenticating..." : "Authenticate with \(biometricService.biometricType.displayName)")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.dynamicAccent)
                    .cornerRadius(16)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            // Automatically trigger biometric authentication when view appears
            authenticateWithBiometrics()
        }
        .alert("Authentication Failed", isPresented: $showError) {
            Button("Try Again") {
                authenticateWithBiometrics()
            }
            Button("Cancel", role: .cancel) {
                onBiometricFailure()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func authenticateWithBiometrics() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        
        Task {
            let success = await biometricService.authenticateWithBiometrics()
            
            await MainActor.run {
                isAuthenticating = false
                
                if success {
                    onBiometricSuccess()
                } else {
                    errorMessage = "Biometric authentication failed. Please try again."
                    showError = true
                }
            }
        }
    }
}
