import Foundation
import SwiftUI



@MainActor
class IncidentStore: ObservableObject {
    @Published var incidents: [Incident] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let networkManager = NetworkManager()
    var currentPage = 1
    var limit = 10
    var hasMorePages = true
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var isFetching = false
    private var totalIncidents = 0
    private(set) var initialPatientSlug: String?
    private var currentSortOption: IncidentSortOption = .dateDesc
    private var currentFilter: IncidentFilter = IncidentFilter()
    
    func fetchIncidentDetail(id: String) async throws -> Incident {
        let endpoint = Endpoint(
            path: "/api/incident/\(id)",
            method: .get
        )
        let response: SingleIncidentResponse = try await networkManager.fetch(endpoint)
        return response.data
    }
    
    // MARK: - Init
    init(patientSlug: String? = nil) {
        self.initialPatientSlug = patientSlug
        print("🔍 IncidentStore init - patientSlug: \(patientSlug ?? "nil")")
        Task {
            await fetchIncidents(patientSlug: patientSlug)
        }
    }
    
    convenience init() {
        self.init(patientSlug: nil)
    }
    
    // MARK: - Public Methods
    func loadMoreIfNeeded(currentItem: Incident?) async {
        guard let currentItem = currentItem,
              let lastItem = incidents.last,
              currentItem.id == lastItem.id,
              !isLoading,
              hasMorePages,
              !isFetching
        else { return }
        
        print("📱 Triggering load more for page: \(currentPage)")
        print("📱 Current incidents count: \(incidents.count)")
        print("📱 Total incidents available: \(totalIncidents)")
        
        // Cancel any existing fetch task
        fetchTask?.cancel()
        
        // Create new fetch task
        fetchTask = Task {
            await fetchIncidents(patientSlug: nil, filter: currentFilter, sortOption: currentSortOption) // Use current filters
        }
        
        // Wait for the fetch task to complete
        await fetchTask?.value
    }
    
    func fetchIncidents(searchQuery: String = "", patientSlug: String? = nil, filter: IncidentFilter? = nil, resetPages: Bool = false, sortOption: IncidentSortOption = .dateDesc) async {
        print("🔍 IncidentStore.fetchIncidents - patientSlug: \(patientSlug ?? "nil"), searchQuery: \(searchQuery)")
        
        if resetPages {
            currentPage = 1
            hasMorePages = true
            incidents = []
            totalIncidents = 0
        }
        
        guard hasMorePages else {
            print("⚠️ No more pages available, skipping...")
            return
        }
        
        isLoading = true
        isFetching = true
        errorMessage = nil
        
        print("🔄 Starting fetch for page \(currentPage)")
        
        do {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "page", value: "\(currentPage)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "order", value: sortOption.apiOrder),
                URLQueryItem(name: "orderBy", value: sortOption.apiOrderBy),
                URLQueryItem(name: "search", value: searchQuery.isEmpty ? nil : searchQuery)
            ]

            // Append role-specific query item
            if let patientSlug = patientSlug {
                // If patientSlug is provided, filter by that specific patient
                print("🔍 Adding patientId query item: \(patientSlug)")
                queryItems.append(URLQueryItem(name: "patientId", value: patientSlug))
            } else if TokenManager.shared.loadCurrentUser()?.role != "Patient" && patientSlug == nil {
                print("🔍 Adding userId query item: \(TokenManager.shared.getUserId())")
             //   queryItems.append(URLQueryItem(name: "userId", value: TokenManager.shared.getUserId()))
            } else {
                let currentPatientSlug = TokenManager.shared.loadCurrentUser()?.userSlug
                print("🔍 Adding current patientId query item: \(currentPatientSlug ?? "nil")")
                queryItems.append(URLQueryItem(name: "patientId", value: currentPatientSlug))
            }
            
            // Add filter parameters if filter is provided
            if let filter = filter {
                // Multi-value filters (arrays)
                for (index, drainageType) in filter.drainageType.enumerated() {
                    queryItems.append(URLQueryItem(name: "drainageType[\(index)]", value: drainageType))
                }
                // Single value filter for status
                if let status = filter.status {
                    queryItems.append(URLQueryItem(name: "status", value: status))
                }
                // Single value filter for patientId
                if let patientId = filter.patientId {
                    queryItems.append(URLQueryItem(name: "patientId", value: patientId))
                }
                // Self created filter - add userId parameter
                if filter.isSelfCreated {
                    if let userId = TokenManager.shared.getUserId() {
                        queryItems.append(URLQueryItem(name: "userId", value: userId))
                    }
                }
            }

            // Create the endpoint
            let endpoint = Endpoint(
                path: "/api/incident",
                queryItems: queryItems
            )
            
            print("📡 API Request - Page: \(currentPage), Limit: \(limit), Search: \(searchQuery)")
            
            let response: IncidentResponse = try await networkManager.fetch(endpoint)
            
            if !Task.isCancelled {
                totalIncidents = response.pagination.total
                hasMorePages = response.pagination.current < totalIncidents
                
                print("📥 Received response - Total: \(response.pagination.total), Current page: \(currentPage)")
                
                if currentPage == 1 {
                    incidents = response.data
                } else {
                    // Filter out duplicates before appending
                    let newIncidents = response.data.filter { newIncident in
                        !incidents.contains { $0.id == newIncident.id }
                    }
                    incidents.append(contentsOf: newIncidents)
                }
                
                // Only increment page if we got data
                if !response.data.isEmpty {
                    currentPage += 1
                }
                
                print("📊 Pagination Status:")
                print("  - Current Page: \(currentPage)")
                print("  - Total Incidents: \(totalIncidents)")
                print("  - Loaded Incidents: \(incidents.count)")
                print("  - Has More Pages: \(hasMorePages)")
                print("  - New Data Count: \(response.data.count)")
            } else {
                print("⚠️ Task was cancelled during fetch")
            }
        } catch {
            if !Task.isCancelled {
                if let networkError = error as? NetworkError {
                    switch networkError {
                    case .cancelled:
                        print("⚠️ Network request was cancelled")
                    default:
                        errorMessage = error.localizedDescription
                        print("❌ Error: \(error.localizedDescription)")
                    }
                } else {
                    errorMessage = error.localizedDescription
                    print("❌ Error: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Task was cancelled during error handling")
            }
        }
        
        isLoading = false
        isFetching = false
        print("✅ Fetch completed for page \(currentPage - 1)")
    }
    
    func refreshIncidents(patientSlug: String? = nil, filter: IncidentFilter? = nil) async {
        // Cancel any existing refresh task
        refreshTask?.cancel()
        
        // Create new refresh task
        refreshTask = Task {
            // Reset pagination and clear loading state
            currentPage = 1
            hasMorePages = true
            incidents = []
            isLoading = true
            errorMessage = nil
            
            let filterToUse = filter ?? currentFilter
            await fetchIncidents(patientSlug: patientSlug, filter: filterToUse, sortOption: currentSortOption)
            
            isLoading = false
            refreshTask = nil
        }
        
        // Wait for the refresh task to complete
        await refreshTask?.value
    }
    
    func updateSortOption(_ sortOption: IncidentSortOption, filter: IncidentFilter? = nil) async {
        currentSortOption = sortOption
        await refreshIncidents(patientSlug: initialPatientSlug, filter: filter)
    }
    
    func updateFilter(_ filter: IncidentFilter) async {
        currentFilter = filter
        await refreshIncidents(patientSlug: initialPatientSlug, filter: filter)
    }
    
    func searchIncidents(query: String) {
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Create a new search task
        searchTask = Task {
            // Reset pagination
            currentPage = 1
            hasMorePages = true
            
            // Wait a bit to avoid too many API calls while typing
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Check if task was cancelled
            if !Task.isCancelled {
                await fetchIncidents(searchQuery: query, filter: currentFilter, resetPages: true, sortOption: currentSortOption)
            }
        }
    }
    
    func deleteIncident(_ incident: Incident) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let endpoint = Endpoint(
                path: "/api/incident/\(incident.id)",
                method: .delete
            )
            
            print("🗑️ Deleting incident: \(incident.id)")
            
            let _: EmptyResponse = try await networkManager.fetch(endpoint)
            
            // Remove from local array if it exists
            if let index = incidents.firstIndex(where: { $0.id == incident.id }) {
                incidents.remove(at: index)
            }
            print("✅ Incident deleted successfully")
            successMessage = "Incident deleted successfully"
            
            // Refresh feature limits after successful incident deletion
            await FeatureLimitService.shared.fetchFeatureLimits()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to delete incident: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func addIncident(_ incident: Incident) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Format dates to match API expectation
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Convert schedules to API format
            let apiSchedules = incident.schedule?.map { ScheduleRequest(from: $0) }
            
            // Convert linked incidents to API format with proper date formatting
            let apiLinkedIncidents = incident.linked?.map { linkedIncident in
                LinkedIncidentRequest(from: linkedIncident)
            }
            
            let request = IncidentRequest(
                patientId: incident.patientId,
                name: incident.name,
                patientName: incident.patientName,
                location: incident.location,
                drainageType: incident.drainageType,
                startDate: dateFormatter.string(from: incident.startDate),
                endDate: dateFormatter.string(from: incident.endDate),
                catheterInsertion: incident.catheterInsertionDate != nil ? dateFormatter.string(from: incident.catheterInsertionDate!) : nil,
                description: incident.description,
                access: incident.access,
                schedule: apiSchedules,
                notification: incident.notification,
                field: incident.fieldConfig,
                status: incident.status,
                linked: apiLinkedIncidents
            )

            // Create the URL request
            guard let url = URL(string: APIConfig.baseURL + "/api/incident") else {
                throw NetworkError.invalidURL
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: "Cookie")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            // Log the request
            NetworkLogger.log(request: urlRequest)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
                
                // Decode the response
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let response = try decoder.decode(SingleIncidentResponse.self, from: data)
                incidents.insert(response.data, at: 0)
                successMessage = "\(response.data.incidentId ?? "") incident successfully added."
                
                Task{
                    // Post notification to refresh incident list
                    NotificationCenter.default.post(name: .RefreshIncidentList, object: nil)
                    
                    // Refresh feature limits after successful incident creation
                    await FeatureLimitService.shared.fetchFeatureLimits()
                }
              
               
            } else {
                throw NetworkError.apiError("Failed to add incident: \(httpResponse.statusCode)")
            }
            
        } catch let error as NetworkError {
            print("Network error occurred: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("Missing key '\(key.stringValue)' – \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("Type mismatch for type '\(type)' – \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("Value not found for type '\(type)' – \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error")
            }
            errorMessage = "Failed to decode server response"
        } catch {
            print("Unexpected error occurred: \(error.localizedDescription)")
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
    
    func updateIncident(_ incident: Incident) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Format dates to match API expectation
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Convert schedules to API format
            let apiSchedules = incident.schedule?.map { ScheduleRequest(from: $0) }
            
            // Convert linked incidents to API format with proper date formatting
            let apiLinkedIncidents = incident.linked?.map { linkedIncident in
                LinkedIncidentRequest(from: linkedIncident)
            }
            
            let request = IncidentRequest(
                patientId: incident.patientId,
                name: incident.name,
                patientName: incident.patientName,
                location: incident.location,
                drainageType: incident.drainageType,
                startDate: dateFormatter.string(from: incident.startDate),
                endDate: dateFormatter.string(from: incident.endDate),
                catheterInsertion: incident.catheterInsertionDate != nil ? dateFormatter.string(from: incident.catheterInsertionDate!) : nil,
                description: incident.description,
                access: incident.access,
                schedule: apiSchedules,
                notification:incident.notification,
                field: incident.fieldConfig,
                status: incident.status,
                linked: apiLinkedIncidents
            )

            // Create the URL request
            guard let url = URL(string: APIConfig.baseURL + "/api/incident/\(incident.id)") else {
                throw NetworkError.invalidURL
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "PUT"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("access_token=\(TokenManager.shared.getToken() ?? "")", forHTTPHeaderField: "Cookie")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            // Log the request
            NetworkLogger.log(request: urlRequest)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            // Log the response
            NetworkLogger.log(response: response, data: data, error: nil)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
                
                // Decode the response
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                let response = try decoder.decode(SingleIncidentResponse.self, from: data)
                if let index = incidents.firstIndex(where: { $0.id == incident.id }) {
                    incidents[index] = response.data
                }
                successMessage = "\(response.data.incidentId ?? "") incident successfully updated."
                
                // Post notifications to refresh incident list and update detail view
                NotificationCenter.default.post(name: .RefreshIncidentList, object: nil)
                NotificationCenter.default.post(name: .updateIncidentRecord, object: nil)
              
            } else {
                throw NetworkError.apiError("Failed to update incident: \(httpResponse.statusCode)")
            }
            
        } catch let error as NetworkError {
            print("Network error occurred: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("Missing key '\(key.stringValue)' – \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("Type mismatch for type '\(type)' – \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("Value not found for type '\(type)' – \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error")
            }
            errorMessage = "Failed to decode server response"
        } catch {
            print("Unexpected error occurred: \(error.localizedDescription)")
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
    
    // MARK: - Close Incident
    
    func closeIncident(_ incident: Incident) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let endpoint = Endpoint(
                path: "/api/incident/close/\(incident.id)",
                method: .put
            )
            
            print("🔒 Closing incident: \(incident.id)")
            
            let response: EmptyResponse = try await networkManager.fetch(endpoint)
            
            // Update the incident status locally
            if let index = incidents.firstIndex(where: { $0.id == incident.id }) {
                incidents[index].status = "Closed"
            }
            
            print("✅ Incident closed successfully")
            successMessage = "\(incident.incidentId ?? "") Incident closed successfully"
            
            // Post notification to refresh incident list
            NotificationCenter.default.post(name: .RefreshIncidentList, object: nil)
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Failed to close incident: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Report Download
    
    func downloadIncidentReport(incidentId: String) async throws -> URL {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current device time zone
            let timeZone = TimeZone.current.identifier
            
            let endpoint = Endpoint(
                path: "/api/report/incident/\(incidentId)",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "tz", value: timeZone)
                ]
            )
            
            print("📄 Downloading report for incident: \(incidentId) with timezone: \(timeZone)")
            
            let response: ReportResponse = try await networkManager.fetch(endpoint)
            
            guard let signedUrl = response.data.locationSign,
                  let url = URL(string: signedUrl) else {
                throw NetworkError.invalidURL
            }
            
            print("✅ Report URL obtained: \(signedUrl)")
            return url
            
        } catch {
            print("❌ Failed to download report: \(error.localizedDescription)")
            errorMessage = "Failed to download report: \(error.localizedDescription)"
            throw error
        }
    }
}
