import Foundation
import SwiftUI

enum NurseSortOption: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case dateDesc = "Latest First"
    case dateAsc = "Oldest First"
    
    var id: String { rawValue }
    
    var sortDescriptor: (NurseData, NurseData) -> Bool {
        switch self {
        case .nameAsc:
            return { $0.firstName.lowercased() < $1.firstName.lowercased() }
        case .nameDesc:
            return { $0.firstName.lowercased() > $1.firstName.lowercased() }
        case .dateDesc:
            return { $0.id > $1.id }
        case .dateAsc:
            return { $0.id < $1.id }
        }
    }
}

@MainActor
class NurseSelectionViewModel: ObservableObject {
    @Published var nurses: [NurseData] = []
    @Published var doctors: [NurseData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var searchText = ""
    
    private let networkManager = NetworkManager()
    private var currentPage = 1
    private let limit = 10
    private var hasMorePages = true
    private var isFetching = false
    private var totalNurses = 0
    private var totalDoctors = 0
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    
    // Computed property to get all staff (nurses + doctors)
    var allStaff: [NurseData] {
        return nurses + doctors
    }
    
    func loadMoreIfNeeded(currentNurse: NurseData?) async {
        guard let currentNurse = currentNurse,
              !isLoading,
              hasMorePages,
              !isFetching
        else { return }
        
        // Check if we need to load more nurses
        let shouldLoadMoreNurses = nurses.contains { $0.id == currentNurse.id } && 
                                 currentNurse.id == nurses.last?.id
        
        // Check if we need to load more doctors
        let shouldLoadMoreDoctors = doctors.contains { $0.id == currentNurse.id } && 
                                  currentNurse.id == doctors.last?.id
        
        guard shouldLoadMoreNurses || shouldLoadMoreDoctors else { return }
        
        fetchTask?.cancel()
        fetchTask = Task {
            await fetchNurses()
        }
        await fetchTask?.value
    }
    
    func fetchNurses(resetPages: Bool = false) async {
        guard !isFetching else { return }
        
        if resetPages {
            currentPage = 1
            hasMorePages = true
            nurses = []
            doctors = []
            totalNurses = 0
            totalDoctors = 0
        }
        
        guard hasMorePages else { return }
        
        isLoading = true
        isFetching = true
        errorMessage = nil
        
        do {
            // Fetch Nurses
            let nurseEndpoint = Endpoint(
                path: APIConfig.Path.getUsers,
                queryItems: [
                    URLQueryItem(name: "page", value: "\(currentPage)"),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "order", value: "desc"),
                    URLQueryItem(name: "orderBy", value: "firstName"),
                    URLQueryItem(name: "role", value: "Nurse"),
                    URLQueryItem(name: "search", value: searchText.isEmpty ? nil : searchText)
                ]
            )
            
            let nurseResponse: NurseListResponse = try await networkManager.fetch(nurseEndpoint)
            
            // Fetch Doctors
            let doctorEndpoint = Endpoint(
                path: APIConfig.Path.getUsers,
                queryItems: [
                    URLQueryItem(name: "page", value: "\(currentPage)"),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "order", value: "desc"),
                    URLQueryItem(name: "orderBy", value: "firstName"),
                    URLQueryItem(name: "role", value: "Doctor"),
                    URLQueryItem(name: "search", value: searchText.isEmpty ? nil : searchText)
                ]
            )
            
            let doctorResponse: NurseListResponse = try await networkManager.fetch(doctorEndpoint)
            
            if !Task.isCancelled {
                // Get current user ID to filter out self
                let currentUserId = TokenManager.shared.getUserId()
                
                // Handle Nurse Response
                if nurseResponse.success {
                    totalNurses = nurseResponse.pagination.total
                    
                    if currentPage == 1 {
                        // Filter out current user from nurses
                        nurses = nurseResponse.data.filter { nurse in
                            nurse.id != currentUserId
                        }
                    } else {
                        let newNurses = nurseResponse.data.filter { newNurse in
                            !nurses.contains { $0.id == newNurse.id } && newNurse.id != currentUserId
                        }
                        nurses.append(contentsOf: newNurses)
                    }
                }
                
                // Handle Doctor Response
                if doctorResponse.success {
                    totalDoctors = doctorResponse.pagination.total
                    
                    if currentPage == 1 {
                        // Filter out current user from doctors
                        doctors = doctorResponse.data.filter { doctor in
                            doctor.id != currentUserId
                        }
                    } else {
                        let newDoctors = doctorResponse.data.filter { newDoctor in
                            !doctors.contains { $0.id == newDoctor.id } && newDoctor.id != currentUserId
                        }
                        doctors.append(contentsOf: newDoctors)
                    }
                }
                
                // Check if we have more pages (use the larger of the two totals)
                let totalItems = max(totalNurses, totalDoctors)
                hasMorePages = currentPage * limit < totalItems
                
                if !nurseResponse.data.isEmpty || !doctorResponse.data.isEmpty {
                    currentPage += 1
                }
                
                // Set error message if either request failed
                if !nurseResponse.success {
                    errorMessage = nurseResponse.message
                } else if !doctorResponse.success {
                    errorMessage = doctorResponse.message
                }
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoading = false
        isFetching = false
    }
    
    func refreshNurses() async {
        refreshTask?.cancel()
        refreshTask = Task {
            currentPage = 1
            hasMorePages = true
            nurses = []
            doctors = []
            isLoading = true
            errorMessage = nil
            
            await fetchNurses()
            
            isLoading = false
            refreshTask = nil
        }
        await refreshTask?.value
    }
    
    func searchNurses() {
        searchTask?.cancel()
        searchTask = Task {
            currentPage = 1
            hasMorePages = true
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if !Task.isCancelled {
                await fetchNurses(resetPages: true)
            }
        }
    }
}
