//
//  Untitled.swift
//  SafalCalendar
//
//  Created by Apple on 27/06/25.
//

import Foundation
import UIKit

@MainActor
class NotificationsViewModel: ObservableObject {
    static let shared = NotificationsViewModel()
    @Published var notifications: [NotificationItem] = []
    @Published var settings: ObservableNotificationSettings?
    @Published var isLoading = false
    @Published var error: String?
    @Published var unreadCount: Int = 0 {
        didSet {
            // Update application badge number whenever unreadCount changes
            UIApplication.shared.applicationIconBadgeNumber = unreadCount
        }
    }
    @Published var moduleCounts: [String: Int] = [:]

    private init() {
        // Private initializer for singleton
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        // Observe for new push notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewPushNotification),
            name: NSNotification.Name("NewPushNotification"),
            object: nil
        )
    }

    @objc private func handleNewPushNotification(_ notification: Notification) {
        // Increment unread count when new push notification arrives
        Task {
            await fetchNotificationCount()
        }
    }

    var unreadNotifications: [NotificationItem] {
        notifications.filter { !$0.isSeen }
    }

    func getUnreadCount(for module: String) -> Int {
        let apiModuleName = mapModuleToAPIName(module)
        return moduleCounts[apiModuleName] ?? 0
    }

    func getNotifications(for module: String, isSeen: Bool? = nil) -> [NotificationItem] {
        // Map the module parameter to the correct API module name
        let apiModuleName = mapModuleToAPIName(module)
        var filteredNotifications = notifications.filter { $0.module.lowercased() == apiModuleName.lowercased() }
        
        // Filter by isSeen if specified
        if let isSeen = isSeen {
            filteredNotifications = filteredNotifications.filter { $0.isSeen == isSeen }
        }
        
        return filteredNotifications
    }
    
    private func mapModuleToAPIName(_ module: String) -> String {
        switch module.lowercased() {
        case "general":
            return "general"
        case "drainagereminder":
            return "drainageReminder"
        case "drainagetriggerlow":
            return "drainageTriggerLow"
        case "drainagetriggermid":
            return "drainageTriggerMid"
        case "drainagetriggerhigh":
            return "drainageTriggerHigh"
        default:
            return module
        }
    }

    func fetchNotificationsByModule(_ module: String, isSeen: Bool? = nil) async {
        print("🔵 [API] Calling fetchNotificationsByModule for module: \(module)")
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let networkManager: NetworkManager = DIContainer.shared.resolve()
            let apiModuleName = mapModuleToAPIName(module)
            
            var queryParams = "module=\(apiModuleName)"
            if let isSeen = isSeen {
                queryParams += "&isSeen=\(isSeen)"
            }
            
            guard let url = URL(string: "\(APIConfig.baseURL)\(APIConfig.Path.notifications)?\(queryParams)") else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let response: NotificationResponse = try await networkManager.fetch(
                Endpoint(path: "\(APIConfig.Path.notifications)?\(queryParams)"),
                urlRequest: request
            )
            print("🟢 [API] fetchNotificationsByModule succeeded for module \(apiModuleName). Notifications count: \(response.data.count)")
            await MainActor.run {
                self.notifications = response.data
                self.isLoading = false
            }
        } catch {
            print("🔴 [API] fetchNotificationsByModule failed with error: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func fetchNotificationCount() async {
        print("🔵 [API] Calling fetchNotificationCount")
        do {
            let networkManager: NetworkManager = DIContainer.shared.resolve()
            guard let url = URL(string: APIConfig.baseURL + "/api/notification/count") else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let response: NotificationCountResponse = try await networkManager.fetch(
                Endpoint(path: "/api/notification/count"),
                urlRequest: request
            )
            print("🟢 [API] fetchNotificationCount succeeded with data: \(String(describing: response.data))")
            await MainActor.run {
                if let data = response.data {
                    self.moduleCounts = data.count
                    self.unreadCount = data.total
                    isLoading = false
                }
            }
        } catch {
            print("🔴 [API] fetchNotificationCount failed with error: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    func resetNotificationCount(for module: String) async {
        print("🔵 [API] Calling resetNotificationCount for module: \(module)")
        do {
            let networkManager: NetworkManager = DIContainer.shared.resolve()

            // Create request body with correct API module name
            let apiModuleName = mapModuleToAPIName(module)
            let requestBody = ["module": apiModuleName]
            let jsonData = try JSONEncoder().encode(requestBody)

            // Create request
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.resetNotificationCount) else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let _: EmptyResponse = try await networkManager.fetch(
                Endpoint(path: APIConfig.Path.resetNotificationCount),
                urlRequest: request
            )

            // After successful reset, fetch updated notifications
            await fetchNotificationCount()
        } catch {
            print("🔴 [API] resetNotificationCount failed with error: \(error)")
            self.error = error.localizedDescription
        }
    }

    func fetchNotificationsSettings() async {
        print("🔵 [API] Calling fetchNotificationsSettings")
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let networkManager: NetworkManager = DIContainer.shared.resolve()
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.notificationSettings) else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let response: NotificationSettingsResponse = try await networkManager.fetch(
                Endpoint(path: APIConfig.Path.notificationSettings),
                urlRequest: request
            )
            print("🟢 [API] fetchNotificationsSettings succeeded with data: \(String(describing: response.data))")
            await MainActor.run {
                if let data = response.data {
                    self.settings = ObservableNotificationSettings(data: data)
                }
                self.isLoading = false
            }
        } catch {
            print("🔴 [API] fetchNotificationsSettings failed with error: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func fetchNotifications(isLoadingview: Bool? = true) async {
        print("🔵 [API] Calling fetchNotifications")
        isLoading = isLoadingview ?? true
        error = nil

        do {
            let networkManager: NetworkManager = DIContainer.shared.resolve()
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.notifications) else {
                throw NetworkError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let response: NotificationResponse = try await networkManager.fetch(
                Endpoint(path: APIConfig.Path.notifications),
                urlRequest: request
            )
            print("🟢 [API] fetchNotifications succeeded. Notifications count: \(response.data.count)")
            await MainActor.run {
                self.notifications = response.data
                self.unreadCount = self.unreadNotifications.count
                self.isLoading = false
            }
        } catch {
            print("🔴 [API] fetchNotifications failed with error: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

//    func startPollingNotifications() {
//        // Poll for new notifications every 30 seconds
//        Task {
//            while true {
//                await fetchNotifications(isLoadingview: false)
//                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30 seconds
//            }
//        }
//    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func updateNotificationSettings() async {
        print("🔵 [API] Calling updateNotificationSettings with settings: \(settings)")
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let networkManager: NetworkManager = DIContainer.shared.resolve()
            guard let url = URL(string: APIConfig.baseURL + APIConfig.Path.notificationSettings) else {
                throw NetworkError.invalidURL
            }

            guard let settings = settings else { return }

            let general = [
                "email": settings.general.email,
                "pushMobile": settings.general.pushMobile,
                "sms": settings.general.sms,
                "notificationScreen": settings.general.notificationScreen,
            ]

            let drainageTriggerLow = [
                "email": settings.drainageTriggerLow.email,
                "pushMobile": settings.drainageTriggerLow.pushMobile,
                "sms": settings.drainageTriggerLow.sms,
                "notificationScreen": settings.drainageTriggerLow.notificationScreen,
            ]

            let drainageTriggerMid = [
                "email": settings.drainageTriggerMid.email,
                "pushMobile": settings.drainageTriggerMid.pushMobile,
                "sms": settings.drainageTriggerMid.sms,
                "notificationScreen": settings.drainageTriggerMid.notificationScreen,
            ]

            let drainageTriggerHigh = [
                "email": settings.drainageTriggerHigh.email,
                "pushMobile": settings.drainageTriggerHigh.pushMobile,
                "sms": settings.drainageTriggerHigh.sms,
                "notificationScreen": settings.drainageTriggerHigh.notificationScreen,
            ]

            let drainageReminder = [
                "email": settings.drainageReminder.email,
                "pushMobile": settings.drainageReminder.pushMobile,
                "sms": settings.drainageReminder.sms,
                "notificationScreen": settings.drainageReminder.notificationScreen,
            ]

            let requestBody: [String: Any] = [
                "general": general,
                "drainageTriggerLow": drainageTriggerLow,
                "drainageTriggerMid": drainageTriggerMid,
                "drainageTriggerHigh": drainageTriggerHigh,
                "drainageReminder": drainageReminder,
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(APIConfig.ContentType.json, forHTTPHeaderField: APIConfig.Header.contentType)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let response: EmptyResponse = try await networkManager.fetch(
                Endpoint(path: APIConfig.Path.notificationSettings),
                urlRequest: request
            )

            await MainActor.run {
                if response.success {
                    Task {
                        await fetchNotificationCount()
                    }
                }
            }
        } catch {
            print("🔴 [API] updateNotificationSettings failed with error: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

class ObservableNotificationSettings: ObservableObject {
    @Published var general: NotificationPreference
    @Published var drainageTriggerLow: NotificationPreference
    @Published var drainageTriggerMid: NotificationPreference
    @Published var drainageTriggerHigh: NotificationPreference
    @Published var drainageReminder: NotificationPreference

    init(data: NotificationSettingsData) {
        general = data.general
        drainageTriggerLow = data.drainageTriggerLow
        drainageTriggerMid = data.drainageTriggerMid
        drainageTriggerHigh = data.drainageTriggerHigh
        drainageReminder = data.drainageReminder
    }

    func toDataModel(withOriginal data: NotificationSettingsData) -> NotificationSettingsData {
        return NotificationSettingsData(
            id: data.id,
            userId: data.userId,
            general: general,
            drainageTriggerLow: drainageTriggerLow,
            drainageTriggerMid: drainageTriggerMid,
            drainageTriggerHigh: drainageTriggerHigh,
            drainageReminder: drainageReminder,
            createdAt: data.createdAt,
            updatedAt: data.updatedAt,
            v: data.v
        )
    }
}
