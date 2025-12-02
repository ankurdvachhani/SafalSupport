import Foundation

@MainActor
final class NetworkErrorHandler {
    static func handle(error: Error) -> String {
        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
    
    static func handleAsync(error: Error, completion: @escaping (String) -> Void) {
        Task { @MainActor in
            let message = handle(error: error)
            completion(message)
        }
    }
} 
