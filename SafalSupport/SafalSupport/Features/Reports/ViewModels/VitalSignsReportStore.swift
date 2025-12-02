import Foundation
import SwiftUI

@MainActor
final class VitalSignsReportStore: ObservableObject {
    @Published var reports: [VitalSignsReport] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let networkManager = NetworkManager()
    private var currentPage = 1
    private let limit = 10
    private var hasMorePages = true
    private var isFetching = false
    private var totalReports = 0
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    
    init() {
        Task {
            await fetchReports()
        }
    }
    
    // MARK: - Public Methods
    
    func fetchReports(searchQuery: String = "", resetPages: Bool = false, sortOption: IncidentReportSortOption = .dateDesc) async {
        print("🔍 VitalSignsReportStore.fetchReports - searchQuery: \(searchQuery)")
        
        if resetPages {
            currentPage = 1
            hasMorePages = true
            reports = []
            totalReports = 0
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
                URLQueryItem(name: "type", value: "vital-signs")
            ]
            
            if !searchQuery.isEmpty {
                queryItems.append(URLQueryItem(name: "search", value: searchQuery))
            }

            // Create the endpoint
            let endpoint = Endpoint(
                path: "/api/report",
                queryItems: queryItems
            )
            
            print("📡 API Request - Page: \(currentPage), Limit: \(limit), Search: \(searchQuery), Type: vital-signs")
            
            let response: VitalSignsReportListResponse = try await networkManager.fetch(endpoint)
            
            if !Task.isCancelled {
                totalReports = response.pagination.total
                hasMorePages = response.pagination.current < totalReports
                
                print("📥 Received response - Total: \(response.pagination.total), Current page: \(currentPage)")
                
                if currentPage == 1 {
                    reports = response.data
                } else {
                    // Filter out duplicates before appending
                    let newReports = response.data.filter { newReport in
                        !reports.contains { $0.id == newReport.id }
                    }
                    reports.append(contentsOf: newReports)
                }
                
                // Only increment page if we got data
                if !response.data.isEmpty {
                    currentPage += 1
                }
                
                print("📊 Pagination Status:")
                print("  - Current Page: \(currentPage)")
                print("  - Total Reports: \(totalReports)")
                print("  - Loaded Reports: \(reports.count)")
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
    
    func loadMoreIfNeeded(currentItem: VitalSignsReport?) async {
        guard let currentItem = currentItem,
              let lastItem = reports.last,
              currentItem.id == lastItem.id,
              !isLoading,
              hasMorePages,
              !isFetching
        else { return }
        
        fetchTask?.cancel()
        fetchTask = Task {
            await fetchReports()
        }
        await fetchTask?.value
    }
    
    func searchReports(query: String) {
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
                await fetchReports(searchQuery: query, resetPages: true)
            }
        }
    }
    
    func refreshReports() async {
        // Cancel any existing refresh task
        refreshTask?.cancel()
        
        // Create new refresh task
        refreshTask = Task {
            // Reset pagination and clear loading state
            currentPage = 1
            hasMorePages = true
            reports = []
            isLoading = true
            errorMessage = nil
            
            await fetchReports()
            
            isLoading = false
            refreshTask = nil
        }
        
        // Wait for the refresh task to complete
        await refreshTask?.value
    }
    
    func downloadReport(reportId: String) async throws -> URL {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current device time zone
            let timeZone = TimeZone.current.identifier
            
            let endpoint = Endpoint(
                path: "/api/report/\(reportId)",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "tz", value: timeZone)
                ]
            )
            
            print("📄 Downloading vital signs report: \(reportId) with timezone: \(timeZone)")
            
            let response: VitalSignsReportResponse = try await networkManager.fetch(endpoint)
            
            // Use urlSign if available, otherwise fall back to url
            let urlString = response.data.urlSign ?? response.data.url
            guard let url = URL(string: urlString) else {
                throw NetworkError.invalidURL
            }
            
            print("✅ Vital signs report URL obtained: \(urlString)")
            return url
            
        } catch {
            print("❌ Failed to download vital signs report: \(error.localizedDescription)")
            errorMessage = "Failed to download report: \(error.localizedDescription)"
            throw error
        }
    }
    
    func generateVitalSignsReport(userSlug: String?, incidentId: String?) async throws -> VitalSignsReportGenerationResponse {
        var queryItems: [URLQueryItem] = []
        
        if let userSlug = userSlug {
            queryItems.append(URLQueryItem(name: "patientId", value: userSlug))
        }
        
        if let incidentId = incidentId {
            queryItems.append(URLQueryItem(name: "incident", value: incidentId))
        }
        
        let endpoint = Endpoint(
            path: "/api/report/vital-signs",
            method: .get,
            queryItems: queryItems
        )
        
        let response: VitalSignsReportGenerationResponse = try await networkManager.fetch(endpoint)
        return response
    }
}

