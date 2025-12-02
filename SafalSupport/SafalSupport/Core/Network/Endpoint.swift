import Foundation

struct Endpoint {
    let path: String
    let method: APIConfig.HTTPMethod
    let headers: [String: String]
    var queryItems: [URLQueryItem]?
    
    var url: URL? {
        var components = URLComponents(string: APIConfig.baseURL)
        components?.path = path
        components?.queryItems = queryItems
        return components?.url
    }
    
    init(
        path: String,
        method: APIConfig.HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem]? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
    }
} 