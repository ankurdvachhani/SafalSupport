//
//  NotificationModule.swift
//  SafalCalendar
//
//  Created by Apple on 27/06/25.
//

import Foundation
import SwiftUICore

enum NotificationModule: String, CaseIterable {
    case general = "general"
    case drainageReminder = "drainageReminder"
    case drainageTriggerLow = "drainageTriggerLow"
    case drainageTriggerMid = "drainageTriggerMid"
    case drainageTriggerHigh = "drainageTriggerHigh"
    
    var displayTitle: String {
        switch self {
        case .general:
            return "General"
        case .drainageReminder:
            return "Drainage Reminder"
        case .drainageTriggerLow:
            return "Drainage Alert"
        case .drainageTriggerMid:
            return "Drainage Alert"
        case .drainageTriggerHigh:
            return "Drainage Alert"
      
        }
    }
    
    var priorityLabel: String? {
        switch self {
        case .drainageTriggerLow:
            return "Low"
        case .drainageTriggerMid:
            return "Mid"
        case .drainageTriggerHigh:
            return "High"
        default:
            return nil
        }
    }
    
    var priorityColor: Color {
        switch self {
        case .drainageTriggerLow:
            return .yellow
        case .drainageTriggerMid:
            return .orange
        case .drainageTriggerHigh:
            return .red
        default:
            return .clear
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "bell"
        case .drainageTriggerLow:
            return "drop.fill"
        case .drainageTriggerMid:
            return "drop.fill"
        case .drainageTriggerHigh:
            return "drop.fill"
        case .drainageReminder:
            return "clock.fill"
        }
    }
    
    var subtitle: String {
        switch self {
        case .general:
            return "Receive general notifications about updates and important information."
        case .drainageReminder:
            return "You'll be notified if a patient misses their scheduled drainage."
        case .drainageTriggerHigh:
            return "High-priority alert for drainage monitoring."
        case .drainageTriggerMid:
            return "Medium-priority alert for drainage monitoring."
        case .drainageTriggerLow:
            return "Low-priority alert for drainage monitoring."
        }
    }
}

enum ReportModule: String, CaseIterable {
    case changeLog = "Activity Log"
    case IncidentReport = "Incident Report"
    case DranageReport = "Dranage Report"
    case VitalSignsReport = "Vital Signs Report"

    
    var icon: String {
        switch self {
        case .changeLog:
            return "text.document"
        case .IncidentReport:
            return "note.text.badge.plus"
        case .DranageReport:
            return "note.text.badge.plus"
        case .VitalSignsReport:
            return "heart.text.square"
        }
    }
    
    var subtitle: String {
        switch self {
        case .IncidentReport:
            return "View already generated report."
        case .changeLog:
            return "View your activity log."
        case .DranageReport:
            return "View already generated report."
        case .VitalSignsReport:
            return "View already generated report."
        }
    }
}

