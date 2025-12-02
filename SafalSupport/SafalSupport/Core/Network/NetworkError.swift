import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(Int)
    case noInternet
    case invalidResponse
    case apiError(String)
    case unknown(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Invalid credentials"
        case .serverError(let code):
            return "Server error: \(code)"
        case .noInternet:
            return "No internet connection"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        case .cancelled:
            return "cancelled"
        }
    }
} 
