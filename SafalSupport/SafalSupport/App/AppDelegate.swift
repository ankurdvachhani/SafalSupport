import UIKit
import FirebaseCore
import FirebaseMessaging
import Foundation
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        setupDependencies()
       // setupPushNotifications(application)
        Logger.info("Application did finish launching")
        
        // Reset app icon badge number to 0 on app launch if user is not authenticated
        if TokenManager.shared.getToken() == nil {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        // Check for shortcut item during launch
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            print("Shortcut item found during app launch: \(shortcutItem.type)")
            // Store the shortcut item details for persistent handling
            storeShortcutItem(shortcutItem)
        }
        
        Logger.info("Application did finish launching")
        
        // Fetch app configuration
        Task {
        //    await ConfigurationService.shared.fetchConfiguration()
        }
        
        // Check for app updates
        Task {
         //   await UpdateAlertViewModel().checkForUpdates()
        }
        
        return true
    }
    
    
    // MARK: - UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Check for shortcut item during scene configuration
        if let shortcutItem = options.shortcutItem {
            print("Shortcut item found during scene configuration: \(shortcutItem.type)")
            
            // Store the shortcut item details for persistent handling
            storeShortcutItem(shortcutItem)
        }
        
        let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = CustomSceneDelegate.self
        
        return sceneConfiguration
    }
    
    private func storeShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        // Store shortcut item type and any additional info
        UserDefaults.standard.set(shortcutItem.type, forKey: "LaunchShortcutItemType")
        
        // Optionally store additional context if needed
        if let userInfo = shortcutItem.userInfo {
            UserDefaults.standard.set(userInfo, forKey: "LaunchShortcutItemUserInfo")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    private func setupDependencies() {
        // Register core dependencies
        let networkManager = NetworkManager()
        DIContainer.shared.register(networkManager)
        
        // Register any additional services here
        Logger.debug("Dependencies registered successfully")
    }
    
    private func setupPushNotifications(_ application: UIApplication) {
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Request authorization for notifications
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if granted {
                    Logger.debug("User granted notifications permission")
                    // Register for remote notifications after permission is granted
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                   
                } else if let error = error {
                    Logger.error("Failed to request notification authorization: \(error.localizedDescription)")
                }
            }
        )
        // Now that we have the APNS token, fetch the FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                Logger.error("Error fetching FCM token: \(error.localizedDescription)")
            } else if let token = token {
                Logger.debug("Successfully fetched FCM token: \(token)")
                print("FCM Token:", token)
            }
        }
    }
    
    // MARK: - MessagingDelegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Logger.debug("Called didReceiveRegistrationToken")
        guard let token = fcmToken else { return }
        Logger.debug("Firebase registration token: \(token)")
        
        // Store the token locally for later use
        UserDefaults.standard.set(token, forKey: "fcmToken")
        
        // Register token with our API
        Task {
            do {
                let networkManager: NetworkManager = DIContainer.shared.resolve()
                let response = try await networkManager.registerFCMToken(token)
                if response.success {
                    Logger.debug("Successfully registered FCM token with API")
                }
            } catch {
                Logger.error("Failed to register FCM token with API: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Log notification content
        Logger.debug("Received notification while app in foreground")
        
        // Extract image URL if present
        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let imageURL = fcmOptions["image"] as? String {
            Logger.debug("Notification contains image: \(imageURL)")
        }
        
        // Post notification to update badge count
        NotificationCenter.default.post(name: NSNotification.Name("NewPushNotification"), object: nil)
        
        // Show the notification with all available presentation options
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
 
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Log notification interaction
        Logger.debug("User interacted with notification")
        
        // Extract image URL if present
        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let imageURL = fcmOptions["image"] as? String {
            Logger.debug("Notification contains image: \(imageURL)")
        }
        
        // Post notification to update badge count
        NotificationCenter.default.post(name: NSNotification.Name("NewPushNotification"), object: nil)
        
        // Handle notification action
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            Logger.debug("User tapped notification")
            handleNotificationTap(userInfo: userInfo)
        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            Logger.debug("User dismissed notification")
        default:
            Logger.debug("Unknown action: \(response.actionIdentifier)")
        }
        
        completionHandler()
    }
    
    
    // MARK: - Remote Notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        
        // Now that we have the APNS token, fetch the FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                Logger.error("Error fetching FCM token: \(error.localizedDescription)")
            } else if let token = token {
                Logger.debug("Successfully fetched FCM token: \(token)")
                print("FCM Token:", token)
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
  

    
    // Handle remote notifications (push notifications)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Logger.debug("Received remote notification")
        
        // Extract image URL if present
        if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
           let imageURL = fcmOptions["image"] as? String {
            Logger.debug("Remote notification contains image: \(imageURL)")
        }
        
        // Handle the notification data
        handleNotificationData(userInfo: userInfo)
        
        NotificationCenter.default.post(name: NSNotification.Name("NewPushNotification"), object: nil)
        completionHandler(.newData)
    }
    
    // MARK: - Private Methods
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Extract any relevant data from userInfo
        if let type = userInfo["type"] as? String {
            switch type {
            case "event":
                if let eventId = userInfo["eventId"] as? String {
                    // Navigate to event detail
                    Logger.debug("Navigating to event: \(eventId)")
                }
            case "meeting":
                if let meetingId = userInfo["meetingId"] as? String {
                    // Navigate to meeting detail
                    Logger.debug("Navigating to meeting: \(meetingId)")
                }
            default:
                // Navigate to notifications list
                Logger.debug("Navigating to notifications list")
                DispatchQueue.main.async {
                    NavigationManager.shared.navigate(to: .notificationview)
                }
            }
        }
    }
    
    private func handleNotificationData(userInfo: [AnyHashable: Any]) {
        // Process notification data
        if let aps = userInfo["aps"] as? [String: Any] {
            if let badge = aps["badge"] as? Int {
                Logger.debug("Setting badge count to: \(badge)")
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = badge
                }
            }
        }
    }
 
}


class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("Shortcut item received in CustomSceneDelegate: \(shortcutItem.type)")
        
        // Store the shortcut item details for persistent handling
        UserDefaults.standard.set(shortcutItem.type, forKey: "LaunchShortcutItemType")
        
        // Optionally store additional context if needed
        if let userInfo = shortcutItem.userInfo {
            UserDefaults.standard.set(userInfo, forKey: "LaunchShortcutItemUserInfo")
        }
        QuickActionsManager.instance.handleQaItem(shortcutItem)
        UserDefaults.standard.synchronize()
        
        completionHandler(true)
    }
}
