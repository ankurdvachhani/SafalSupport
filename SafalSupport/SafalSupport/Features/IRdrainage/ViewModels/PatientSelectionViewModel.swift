import Foundation
import SwiftUI

enum PatientSortOption: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case dateDesc = "Latest First"
    case dateAsc = "Oldest First"
    
    var id: String { rawValue }
    
    var sortDescriptor: (PatientData, PatientData) -> Bool {
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
class PatientSelectionViewModel: ObservableObject {
    @Published var patients: [PatientData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var searchText = ""
    
    private let networkManager = NetworkManager()
    private var currentPage = 1
    private let limit = 10
    private var hasMorePages = true
    private var isFetching = false
    private var totalPatients = 0
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    
    func loadMoreIfNeeded(currentPatient: PatientData?) async {
        guard let currentPatient = currentPatient,
              let lastItem = patients.last,
              currentPatient.id == lastItem.id,
              !isLoading,
              hasMorePages,
              !isFetching
        else { return }
        
        fetchTask?.cancel()
        fetchTask = Task {
            await fetchPatients()
        }
        await fetchTask?.value
    }
    
    func fetchPatients(resetPages: Bool = false) async {
        guard !isFetching else { return }
        
        if resetPages {
            currentPage = 1
            hasMorePages = true
            patients = []
            totalPatients = 0
        }
        
        guard hasMorePages else { return }
        
        isLoading = true
        isFetching = true
        errorMessage = nil
        
        do {
            let endpoint = Endpoint(
                path: APIConfig.Path.getUsers,
                queryItems: [
                    URLQueryItem(name: "page", value: "\(currentPage)"),
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "order", value: "desc"),
                    URLQueryItem(name: "orderBy", value: "firstName"),
                    URLQueryItem(name: "role", value: "Patient"),
                    URLQueryItem(name: "search", value: searchText.isEmpty ? nil : searchText)
                ]
            )
            
            let response: PatientListResponse = try await networkManager.fetch(endpoint)
            
            if !Task.isCancelled {
                if response.success {
                    totalPatients = response.pagination.total
                    hasMorePages = response.pagination.current < totalPatients
                    
                    if currentPage == 1 {
                        patients = response.data
                    } else {
                        let newPatients = response.data.filter { newPatient in
                            !patients.contains { $0.id == newPatient.id }
                        }
                        patients.append(contentsOf: newPatients)
                    }
                    
                    if !response.data.isEmpty {
                        currentPage += 1
                    }
                } else {
                    errorMessage = response.message
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
    
    func refreshPatients() async {
        refreshTask?.cancel()
        refreshTask = Task {
            currentPage = 1
            hasMorePages = true
            patients = []
            isLoading = true
            errorMessage = nil
            
            await fetchPatients()
            
            isLoading = false
            refreshTask = nil
        }
        await refreshTask?.value
    }
    
    func searchPatients() {
        searchTask?.cancel()
        searchTask = Task {
            currentPage = 1
            hasMorePages = true
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if !Task.isCancelled {
                await fetchPatients(resetPages: true)
            }
        }
    }
}