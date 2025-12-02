//
//  NotificationModel.swift
//  SafalCalendar
//
//  Created by Apple on 03/07/25.
//

import Foundation


// Notification Models
struct NotificationResponse: Codable {
    let success: Bool
    let data: [NotificationItem]
}

struct NotificationItem: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let content: String
    let isSeen: Bool
    let module: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, title, content, isSeen, module, createdAt, updatedAt
    }
}

// MARK: - Root Response
struct NotificationSettingsResponse: Codable {
    let success: Bool
    let data: NotificationSettingsData?
    let message: String
}

// MARK: - Notification Settings Data
struct NotificationSettingsData: Codable {
    let id: String
    let userId: String
    let general: NotificationPreference
    let drainageTriggerLow: NotificationPreference
    let drainageTriggerMid: NotificationPreference
    let drainageTriggerHigh: NotificationPreference
    let drainageReminder: NotificationPreference
    let createdAt: String
    let updatedAt: String
    let v: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case general
        case drainageTriggerLow
        case drainageTriggerMid
        case drainageTriggerHigh
        case drainageReminder
        case createdAt
        case updatedAt
        case v = "__v"
    }
}

// MARK: - Notification Preferences per Module
struct NotificationPreference: Codable {
    var email: Bool
    var pushMobile: Bool
    var sms: Bool
    var notificationScreen: Bool
}

// MARK: - Notification Count Response
struct NotificationCountResponse: Codable {
    let success: Bool
    let data: NotificationCountData?
    let message: String
    let errors: [String]
    let timestamp: String
}

// MARK: - Notification Count Data
struct NotificationCountData: Codable {
    let total: Int
    let count: [String: Int]
}
