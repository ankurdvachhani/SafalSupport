import Foundation
import os.log

enum LogLevel: String {
    case debug = "💚 DEBUG"
    case info = "💙 INFO"
    case warning = "💛 WARNING"
    case error = "❤️ ERROR"
}

final class Logger {
    static let shared = Logger()
    private let logger: OSLog
    
    private init() {
        self.logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "SafalCalendar", category: "App")
    }
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
//        #if DEBUG
//        let fileName = (file as NSString).lastPathComponent
//        let logMessage = "[\(fileName):\(line)] [\(function)] \(message)"
//        
//        switch level {
//        case .debug:
//            os_log(.debug, log: logger, "%{public}@", logMessage)
//        case .info:
//            os_log(.info, log: logger, "%{public}@", logMessage)
//        case .warning:
//            os_log(.error, log: logger, "%{public}@", logMessage)
//        case .error:
//            os_log(.fault, log: logger, "%{public}@", logMessage)
//        }
//        #endif
        let logMessage = "[\(file):\(line)] [\(function)] \(message)"
        print(logMessage) // replace os_log for debug
    }
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .error, file: file, function: function, line: line)
    }
} 
