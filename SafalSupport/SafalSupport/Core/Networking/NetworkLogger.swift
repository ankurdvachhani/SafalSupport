import Foundation

enum NetworkLogger {
    static func log(request: URLRequest) {
        print("\n - - - - - - - - - - REQUEST - - - - - - - - - - ")
        defer { print(" - - - - - - - - - -  END - - - - - - - - - - \n") }
        
        let urlAsString = request.url?.absoluteString ?? ""
        let urlComponents = URLComponents(string: urlAsString)
        
        let method = request.httpMethod != nil ? "\(request.httpMethod ?? "")" : ""
        let path = "\(urlComponents?.path ?? "")"
        let query = "\(urlComponents?.query ?? "")"
        let host = "\(urlComponents?.host ?? "")"
        
        var logOutput = """
        \(urlAsString)
        \(method) \(path)?\(query)
        HOST: \(host)
        """
        
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            logOutput += "\n\(key): \(value)"
        }
        
        if let body = request.httpBody {
            if let jsonObject = try? JSONSerialization.jsonObject(with: body, options: .mutableContainers),
               let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) {
                logOutput += "\n\nBody: \(String(decoding: jsonData, as: UTF8.self))"
            } else if let bodyString = String(data: body, encoding: .utf8) {
                logOutput += "\n\nBody: \(bodyString)"
            }
        }
        
        print(logOutput)
    }
    
    static func log(response: URLResponse?, data: Data?, error: Error?) {
        print("\n - - - - - - - - - - RESPONSE - - - - - - - - - - ")
        defer { print(" - - - - - - - - - -  END - - - - - - - - - - \n") }
        
        let urlString = response?.url?.absoluteString ?? ""
        let components = URLComponents(string: urlString)
        
        var logOutput = """
        URL: \(urlString)
        PATH: \(components?.path ?? "")
        """
        
        if let httpResponse = response as? HTTPURLResponse {
            logOutput += "\nSTATUS CODE: \(httpResponse.statusCode)"
            
            for (key, value) in httpResponse.allHeaderFields {
                logOutput += "\n\(key): \(value)"
            }
        }
        
        if let host = components?.host {
            logOutput += "\nHOST: \(host)"
        }
        
        if let error = error {
            logOutput += "\nERROR: \(error.localizedDescription)"
        }
        
        if let data = data {
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
               let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) {
                logOutput += "\n\nRESPONSE DATA: \(String(decoding: jsonData, as: UTF8.self))"
            } else if let dataString = String(data: data, encoding: .utf8) {
                logOutput += "\n\nRESPONSE DATA: \(dataString)"
            }
        }
        
        print(logOutput)
    }
} 