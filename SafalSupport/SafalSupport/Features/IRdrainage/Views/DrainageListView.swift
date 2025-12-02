import SwiftUI
import CoreImage.CIFilterBuiltins

extension Notification.Name {
    static let updateDrainageRecord = Notification.Name("updateDrainageRecord")
    static let RefreshDrainageList = Notification.Name("RefreshDrainageList")
}

// MARK: - View Type Enum
enum ViewType: String, CaseIterable {
    case list = "list"
    case card = "card"
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .card: return "rectangle.grid.2x2"
        }
    }
    
    var displayName: String {
        switch self {
        case .list: return "List"
        case .card: return "Cards"
        }
    }
}

// MARK: - Filter Model
struct DrainageFilter {
    var minAmount: Double?
    var maxAmount: Double?
    var minTemperature: Double?
    var maxTemperature: Double?
    var minPainLevel: Int?
    var maxPainLevel: Int?
    var minRecordedAt: Date?
    var maxRecordedAt: Date?
    var odor: [String] = []
    var fluidType: [String] = []
    var color: [String] = []
    var drainageType: [String] = []
    var consistency: [String] = []
    var patientId: String?
    var isSelfCreated: Bool = false
    
    var hasActiveFilters: Bool {
        return minAmount != nil || maxAmount != nil ||
               minTemperature != nil || maxTemperature != nil ||
               minPainLevel != nil || maxPainLevel != nil ||
               minRecordedAt != nil || maxRecordedAt != nil ||
               !odor.isEmpty || !fluidType.isEmpty || !color.isEmpty ||
               !drainageType.isEmpty || !consistency.isEmpty || patientId != nil || isSelfCreated
    }
    
    mutating func clearAll() {
        minAmount = nil
        maxAmount = nil
        minTemperature = nil
        maxTemperature = nil
        minPainLevel = nil
        maxPainLevel = nil
        minRecordedAt = nil
        maxRecordedAt = nil
        odor.removeAll()
        fluidType.removeAll()
        color.removeAll()
        drainageType.removeAll()
        consistency.removeAll()
        patientId = nil
        isSelfCreated = false
    }
}

struct DrainageListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject var store: DrainageStore
    @StateObject private var configService = ConfigurationService.shared
    @StateObject private var featureLimitService = FeatureLimitService.shared
    @State private var showingAddDrainage = false
    @State private var searchText = ""
    @State private var selectedSortOption: DrainageSortOption = .dateDesc
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: DrainageEntry?
    @State private var showingDeleteTimeLimitAlert = false
    @State private var showingSortSheet = false
    @State private var selectedEntryForBarcode: DrainageEntry?
    @State private var showingBarcodes = false
    @State private var showingDrainageLimitAlert = false
    @State private var limitAlertMessage = ""
    @State private var selectedEntryForReport: DrainageEntry?
    @State private var showingPDFViewer = false
    @State private var pdfURL: URL?
    @State private var showingReportConfirmation = false
    @State private var includeConversations = true
    
    // Filter states
    @State private var showingFilterSheet = false
    @State private var currentFilter = DrainageFilter()
    
    // View type states
    @State private var viewType: ViewType = {
        if let savedViewType = UserDefaults.standard.string(forKey: "DrainageViewType"),
           let viewType = ViewType(rawValue: savedViewType) {
            return viewType
        }
        return .list
    }()
    
    // Patient filter properties
    let patientSlug: String?
    let patientName: String?
    let incidentId: String?
    let incidentName: String?
    let incidentDisplayId: String?
    
    init(patientSlug: String? = nil, patientName: String? = nil, incidentId: String? = nil, incidentName: String? = nil, incidentDisplayId: String? = nil) {
        self.patientSlug = patientSlug
        self.patientName = patientName
        self.incidentId = incidentId
        self.incidentName = incidentName
        self.incidentDisplayId = incidentDisplayId
        print("🔍 DrainageListView init - patientSlug: \(patientSlug ?? "nil"), patientName: \(patientName ?? "nil"), incidentId: \(incidentId ?? "nil"), incidentName: \(incidentName ?? "nil"), incidentDisplayId: \(incidentDisplayId ?? "nil")")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar and buttons row
            if patientSlug == nil && incidentId == nil{
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        searchBar
                        
                        // Sort button
                        Button {
                            showingSortSheet = true
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up.arrow.down.circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent)
                            }
                        }
                        
                        // Filter button
                        Button {
                            showingFilterSheet = true
                        } label: {
                            ZStack {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent)
                                
                                // Red dot indicator for active filters
                                if currentFilter.hasActiveFilters {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        // Barcode toggle button
                        Button {
                            showingBarcodes.toggle()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: showingBarcodes ? "barcode" : "barcode")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(showingBarcodes ? .black : Color.dynamicAccent)
                            }
                            .frame(width: 44, height: 44)
                            .background(showingBarcodes ? Color.clear : Color.clear)
                            .cornerRadius(8)
                        }
                        
                        // Create button - only show if incident is disble in configuration
                        if !configService.isIncidentEnabled {
                            Button {
                                // Check drainage count limit before opening AddDrainageView
                                let drainageLimitCheck = featureLimitService.canCreateDrainage()
                                if !drainageLimitCheck.allowed {
                                    limitAlertMessage = drainageLimitCheck.message ?? "Drainage limit reached"
                                    showingDrainageLimitAlert = true
                                } else {
                                    NavigationManager.shared.navigate(to: .addDrainage(), style: .presentSheet())
                                }
                            } label: {
                                Circle()
                                    .fill(Color.dynamicAccent)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                    .shadow(color: Color.dynamicAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                    }
                }
                .padding()
            }
                
            
            
            // View type toggle
            HStack {
                Text("View:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("View Type", selection: $viewType) {
                    ForEach(ViewType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 200)
                .onChange(of: viewType) { newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "DrainageViewType")
                }
            } .padding()
            
            if incidentId != nil {
                VStack(spacing: 8) {
                    if let incidentDisplayId = incidentDisplayId, !incidentDisplayId.isEmpty {
                        HStack {
                            Text("Incident ID:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(incidentDisplayId)
                                .font(.subheadline)
                                .foregroundColor(.black)
                            Spacer()
                        }
                    }
                    
                    if let incidentName = incidentName, !incidentName.isEmpty {
                        HStack {
                            Text("Incident Name:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(incidentName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Content
            ZStack {
                if store.isLoading && store.entries.isEmpty {
                    drainageShimmerList
                } else if !searchText.isEmpty && filteredEntries.isEmpty {
                    DrainageNoSearchResultsView(searchText: searchText)
                } else if store.entries.isEmpty && currentFilter.hasActiveFilters {
                    DrainageNoFilterResultsView(currentFilter: currentFilter) {
                        // Clear filters action
                        currentFilter.clearAll()
                        Task {
                            await store.refreshEntries(patientSlug: store.initialPatientSlug, incidentId: store.initialIncidentId, filter: currentFilter)
                        }
                    }
                } else if store.entries.isEmpty {
                    if let patientName = patientName, !patientName.isEmpty {
                        EmptyPatientDrainageView(patientName: patientName)
                    } else {
                        EmptyDrainageView()
                    }
                } else {
                    if viewType == .list {
                        drainageList
                    } else {
                       // drainageList
                        drainageCardView
                    }
                }
            }
            .navigationTitle(navigationTitle)
        }
        .onAppear {
            // Add notification observer
            NotificationCenter.default.addObserver(
                forName: .RefreshDrainageList,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await store.refreshEntries(patientSlug: store.initialPatientSlug, incidentId: store.initialIncidentId, filter: currentFilter)
                }
            }
            
            // Check for pending date filter from PatientDashboardView
            checkPendingDateFilter()
            
            // DrainageStore is already initialized with the correct patient filter
            print("🔍 onAppear - patientSlug: \(patientSlug ?? "nil"), patientName: \(patientName ?? "nil"), incidentId: \(incidentId ?? "nil")")
            // No need to fetch again as DrainageStore.init() already handles this
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
        .sheet(isPresented: $showingAddDrainage) {
            NavigationView {
                let drainageLimitCheck = featureLimitService.canCreateDrainage()
                if !drainageLimitCheck.allowed {
                } else {
                    AddDrainageView()
                }
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showingSortSheet) {
            DrainageSortSheet(
                selectedSortOption: $selectedSortOption,
                isPresented: $showingSortSheet,
                onSortChanged: { newSortOption in
                    Task {
                        await store.updateSortOption(newSortOption, filter: currentFilter)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFilterSheet) {
            DrainageFilterSheet(
                filter: $currentFilter,
                onApply: {
                    Task {
                        await store.refreshEntries(patientSlug: store.initialPatientSlug, incidentId: store.initialIncidentId, filter: currentFilter)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: searchText) { newValue in
            store.searchEntries(query: newValue, filter: currentFilter)
        }
        .toast(message: $store.errorMessage, type: .error)
        .toast(message: $store.successMessage, type: .success)
        .onChange(of: store.errorMessage) { errorMessage in
            if let message = errorMessage, 
               message.lowercased().contains("session expired") || 
               message.lowercased().contains("please login again") {
                print("🚨 Session expired detected in DrainageListView: \(message)")
                handleLogout()
            }
        }
        .alert("Delete Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    Task {
                        await store.deleteEntry(entry)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this drainage entry? This action cannot be undone.")
        }
        .alert("Deletion Time Limit", isPresented: $showingDeleteTimeLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let entry = entryToDelete {
                if let timeLimit = configService.drainageDeleteTimeLimit, timeLimit > 0 {
                    let timeLimitText = "\(timeLimit) minutes"
                    if let remainingTime = getRemainingDeletionTime(entry) {
                        Text("This drainage entry can only be deleted within \(timeLimitText) of creation. \(remainingTime)")
                    } else {
                        Text("This drainage entry can only be deleted within \(timeLimitText) of creation. The deletion time has expired.")
                    }
                } else {
                    Text("This drainage entry cannot be deleted due to time restrictions.")
                }
            }
        }
        .alert("Drainage Limit Reached", isPresented: $showingDrainageLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(limitAlertMessage)
        }
        .sheet(isPresented: $showingReportConfirmation) {
            ReportConfirmationView(
                isPresented: $showingReportConfirmation,
                includeConversations: $includeConversations,
                onConfirm: {
                    if let entry = selectedEntryForReport {
                        Task {
                            await confirmDownloadReport(for: entry)
                        }
                    }
                }
            )
            .presentationDetents([.medium]) // medium = half, large = full
            .presentationDragIndicator(.visible)    // shows the grab bar at the top
            .presentationCornerRadius(20)           // optional: rounded corners
        }
        .sheet(item: $selectedEntryForBarcode) { entry in
            BarcodeDisplayView(drainageId: entry.drainageId ?? "")
        }
        .overlay {
            if let entry = selectedEntryForReport, let url = pdfURL {
                CustomPDFOverlay(url: url, incidentName: entry.drainageId ?? "Drainage Report") {
                    selectedEntryForReport = nil
                    pdfURL = nil
                }
            }
        }
    }
    
    private func handleLogout() {
        Task {
            if let token = UserDefaults.standard.string(forKey: "fcmToken") {
                do {
                    let networkManager: NetworkManager = DIContainer.shared.resolve()
                    let response = try await networkManager.deleteFCMToken(token)
                    if response.success {
                        Logger.debug("Successfully deleted FCM token")
                    }
                } catch {
                    Logger.error("Failed to delete FCM token: \(error.localizedDescription)")
                }
            }
            // Remove the stored token
            UserDefaults.standard.removeObject(forKey: "fcmToken")

            // Sign out and reset tab
            NavigationManager.shared.goBackToRoot()
            appState.selectedTab = .dashboard
            appState.signOut()
        }
    }
    
    /// Check if a drainage entry can be deleted based on the time limit configuration
    private func canDeleteEntry(_ entry: DrainageEntry) -> Bool {
        guard let timeLimitMinutes = configService.drainageDeleteTimeLimit, timeLimitMinutes > 0 else {
            // If no time limit is configured or set to 0, allow deletion
            return true
        }
        
        let currentTime = Date()
        let entryTime = entry.createdAt  // Use createdAt instead of recordedAt
        let timeDifference = currentTime.timeIntervalSince(entryTime)
        let timeLimitSeconds = Double(timeLimitMinutes * 60)
        
        return timeDifference <= timeLimitSeconds
    }
    
    /// Get the remaining time for deletion in a human-readable format
    private func getRemainingDeletionTime(_ entry: DrainageEntry) -> String? {
        guard let timeLimitMinutes = configService.drainageDeleteTimeLimit, timeLimitMinutes > 0 else {
            return nil
        }
        
        let currentTime = Date()
        let entryTime = entry.createdAt  // Use createdAt instead of recordedAt
        let timeDifference = currentTime.timeIntervalSince(entryTime)
        let timeLimitSeconds = Double(timeLimitMinutes * 60)
        let remainingSeconds = timeLimitSeconds - timeDifference
        
        if remainingSeconds <= 0 {
            return "Deletion time expired"
        }
        
        let remainingMinutes = Int(remainingSeconds / 60)
        let remainingSecondsOnly = Int(remainingSeconds.truncatingRemainder(dividingBy: 60))
        
        if remainingMinutes > 0 {
            return "\(remainingMinutes)m \(remainingSecondsOnly)s remaining"
        } else {
            return "\(remainingSecondsOnly)s remaining"
        }
    }
    
    private func checkPendingDateFilter() {
        // Check if there's a pending date filter from PatientDashboardView
        if UserDefaults.standard.bool(forKey: "pendingDateFilter") {
            if let minDate = UserDefaults.standard.object(forKey: "pendingMinRecordedAt") as? Date,
               let maxDate = UserDefaults.standard.object(forKey: "pendingMaxRecordedAt") as? Date {
                
                // Apply the date filter
                currentFilter.minRecordedAt = minDate
                currentFilter.maxRecordedAt = maxDate
                
                // Clear the pending filter flags
                UserDefaults.standard.removeObject(forKey: "pendingDateFilter")
                UserDefaults.standard.removeObject(forKey: "pendingMinRecordedAt")
                UserDefaults.standard.removeObject(forKey: "pendingMaxRecordedAt")
                
                // Refresh entries with the new filter
                Task {
                    await store.refreshEntries(patientSlug: store.initialPatientSlug, incidentId: store.initialIncidentId, filter: currentFilter)
                }
            }
        }
    }
    
    // MARK: - Report Download
    
    private func downloadAndShowReport(for entry: DrainageEntry) {
        selectedEntryForReport = entry
        includeConversations = true // Reset to default true
        showingReportConfirmation = true
    }
    
    private func confirmDownloadReport(for entry: DrainageEntry) async {
        do {
            let url = try await store.downloadDrainageReport(drainageId: entry.id, conversations: includeConversations)
            await MainActor.run {
                self.pdfURL = url
                self.selectedEntryForReport = entry
                self.showingReportConfirmation = false
            }
        } catch {
            await MainActor.run {
                store.errorMessage = "Failed to download report: \(error.localizedDescription)"
                self.showingReportConfirmation = false
            }
        }
    }
    
    private var drainageList: some View {
        List {
            ForEach(filteredEntries) { entry in
                VStack(spacing: 0) {
                    PesentDrainageRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            NavigationManager.shared.navigate(to: .drainageDetail(entry: entry))
                        }
                        .task {
                            await store.loadMoreIfNeeded(currentItem: entry, filter: currentFilter)
                        }
                    
                    // Show barcode if toggle is on and entry has barcode
                    if showingBarcodes, let drainageId = entry.drainageId, !drainageId.isEmpty {
                        VStack(spacing: 8) {
                            Divider()
                                .padding(.horizontal)
                            
                            BarcodeView(data: drainageId)
                                .frame(height: 60)
                                .padding(.horizontal)
                            
                            Text(drainageId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(.bottom, 8)
                        }
                        .background(Color(.systemGray6).opacity(0.5))
                    }
                }
                .swipeActions(edge: .trailing) {
                    // Report button
                 //   if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        Button {
                            Task {
                                await downloadAndShowReport(for: entry)
                            }
                        } label: {
                            Label("Report", systemImage: "arrow.down.circle.fill")
                        }
                        .tint(.orange)
                //    }
                    
                    // Barcode button
                    if let drainageId = entry.drainageId, !drainageId.isEmpty {
                        Button {
                            selectedEntryForBarcode = entry
                        } label: {
                            Label("DrainageID Code", systemImage: "barcode")
                        }
                        .tint(.blue)
                    }
                    
                    if entry.userId == TokenManager.shared.getUserId() {
                        if canDeleteEntry(entry) {
                            Button(role: .destructive) {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        } else {
                            Button {
                                entryToDelete = entry
                                showingDeleteTimeLimitAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.gray)
                        }
                    }
                  
                }
                .contextMenu {
                    // Report option
                 //   if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        Button {
                            Task {
                                await downloadAndShowReport(for: entry)
                            }
                        } label: {
                            Label("Download Report", systemImage: "arrow.down.circle.fill")
                        }
                  //  }
                    
                    // Barcode option
                    if let drainageId = entry.drainageId, !drainageId.isEmpty {
                        Button {
                            selectedEntryForBarcode = entry
                        } label: {
                            Label("DrainageID Code", systemImage: "barcode")
                        }
                    }
                    
                    if entry.userId == TokenManager.shared.getUserId() {
                        if canDeleteEntry(entry) {
                            Button(role: .destructive) {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Entry", systemImage: "trash")
                            }
                        } else {
                            Button {
                                entryToDelete = entry
                                showingDeleteTimeLimitAlert = true
                            } label: {
                                Label("Delete Entry", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000) // Add a small delay
            await store.refreshEntries(patientSlug: store.initialPatientSlug, incidentId: store.initialIncidentId, filter: currentFilter)
        }
    }
    
    private var drainageCardView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredEntries) { entry in
                    DrainageCardView(entry: entry, showingBarcodes: showingBarcodes)
                        .onTapGesture {
                            NavigationManager.shared.navigate(to: .drainageDetail(entry: entry))
                        }
                        .task {
                            await store.loadMoreIfNeeded(currentItem: entry, filter: currentFilter)
                        }
                        .contextMenu {
                            // Report option
                          //  if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                                Button {
                                    Task {
                                        await downloadAndShowReport(for: entry)
                                    }
                                } label: {
                                    Label("Download Report", systemImage: "arrow.down.circle.fill")
                                }
                          //  }
                            
                            // Barcode option
                            if let drainageId = entry.drainageId, !drainageId.isEmpty {
                                Button {
                                    selectedEntryForBarcode = entry
                                } label: {
                                    Label("DrainageID Code", systemImage: "barcode")
                                }
                            }
                            
                            if entry.userId == TokenManager.shared.getUserId() {
                                if canDeleteEntry(entry) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete Entry", systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        entryToDelete = entry
                                        showingDeleteTimeLimitAlert = true
                                    } label: {
                                        Label("Delete Entry", systemImage: "trash")
                                    }
                                }
                            }
                        }
                }
            }
            .padding()
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000) // Add a small delay
            await store.refreshEntries(patientSlug: store.initialPatientSlug, incidentId: store.initialIncidentId, filter: currentFilter)
        }
    }
    
    private var drainageShimmerList: some View {
        List {
            ForEach(0..<5) { _ in
                DrainageShimmerRow()
            }
        }
        .listStyle(.plain)
        .disabled(true)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            TextField("Search Drainage...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var filteredEntries: [DrainageEntry] {
        // Server-side sorting is now handled by the API
        return store.entries
    }
    
    private var navigationTitle: String {
        if let incidentId = incidentId, !incidentId.isEmpty {
            return "Drainage Records (\(filteredEntries.count))"
        } else if let patientName = patientName, !patientName.isEmpty {
            return "\(patientName)'s Drainage Records"
        } else {
            return "Drainage Records"
        }
    }
}

// MARK: - Supporting Views
struct DrainageShimmerRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DrainageShimmerBox(width: 150, height: 20)
                Spacer()
                DrainageShimmerBox(width: 80, height: 20)
            }
            
            HStack {
                DrainageShimmerBox(width: 100, height: 16)
                Spacer()
                DrainageShimmerBox(width: 120, height: 16)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DrainageShimmerBox: View {
    let width: CGFloat
    let height: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: height/4)
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGray5),
                    Color(.systemGray6),
                    Color(.systemGray5)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: width, height: height)
            .mask(
                RoundedRectangle(cornerRadius: height/4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.clear, .white, .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .offset(x: isAnimating ? width : -width)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

struct EmptyDrainageView: View {
    var body: some View {
        VStack(spacing: 20) {
           Image("drainage_icon")
                .renderingMode(.template)
                .resizable()
                .frame(width: 80, height: 80)
                .font(.system(size: 80))
                .foregroundColor(Color.dynamicAccent.opacity(0.6))
            
            Text("No Drainage Entries")
                .font(.title2)
                .fontWeight(.semibold)
            if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                Text("Create your first drainage entry by tapping the + button above")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyPatientDrainageView: View {
    let patientName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicAccent)
            
            Text("No Records Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No drainage entries found for \(patientName)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("This patient may not have any drainage records yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DrainageNoSearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.dynamicAccent)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No drainage entries found for '\(searchText)'")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Try different keywords or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DrainageNoFilterResultsView: View {
    let currentFilter: DrainageFilter
    let onClearFilters: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicAccent)
            
            Text("No Matching Records")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No drainage entries match your current filter criteria")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Show active filters summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Filters:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let minAmount = currentFilter.minAmount {
                        Text("• Min Amount: \(Int(minAmount)) ml")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let maxAmount = currentFilter.maxAmount {
                        Text("• Max Amount: \(Int(maxAmount)) ml")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let minTemp = currentFilter.minTemperature {
                        Text("• Min Temperature: \(minTemp, specifier: "%.1f")°F")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let maxTemp = currentFilter.maxTemperature {
                        Text("• Max Temperature: \(maxTemp, specifier: "%.1f")°F")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let minPain = currentFilter.minPainLevel {
                        Text("• Min Pain Level: \(minPain)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let maxPain = currentFilter.maxPainLevel {
                        Text("• Max Pain Level: \(maxPain)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !currentFilter.color.isEmpty {
                        Text("• Colors: \(currentFilter.color.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !currentFilter.fluidType.isEmpty {
                        Text("• Fluid Types: \(currentFilter.fluidType.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !currentFilter.drainageType.isEmpty {
                        Text("• Drainage Types: \(currentFilter.drainageType.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !currentFilter.consistency.isEmpty {
                        Text("• Consistency: \(currentFilter.consistency.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !currentFilter.odor.isEmpty {
                        Text("• Odor: \(currentFilter.odor.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let patientId = currentFilter.patientId {
                        Text("• Patient ID: \(patientId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if currentFilter.isSelfCreated {
                        Text("• Show only drainage records I created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            VStack(spacing: 12) {
                Text("Try adjusting your filters or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button {
                    onClearFilters()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear All Filters")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent)
                    .cornerRadius(25)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct DrainageSortSheet: View {
    @Binding var selectedSortOption: DrainageSortOption
    @Binding var isPresented: Bool
    let onSortChanged: (DrainageSortOption) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            Text("Sort & Order")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 12)
                .padding(.bottom, 10)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Date/Time Sorting
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Date & Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        ForEach([DrainageSortOption.dateDesc, .dateAsc, .createdAtDesc, .createdAtAsc]) { option in
                            SortOptionRow(option: option, isSelected: option == selectedSortOption) {
                                selectedSortOption = option
                                onSortChanged(option)
                                isPresented = false
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Amount Sorting
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Fluid Amount")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        ForEach([DrainageSortOption.amountDesc, .amountAsc]) { option in
                            SortOptionRow(option: option, isSelected: option == selectedSortOption) {
                                selectedSortOption = option
                                onSortChanged(option)
                                isPresented = false
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Location Sorting
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Location")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        ForEach([DrainageSortOption.locationAsc, .locationDesc]) { option in
                            SortOptionRow(option: option, isSelected: option == selectedSortOption) {
                                selectedSortOption = option
                                onSortChanged(option)
                                isPresented = false
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Health Metrics Sorting
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Health Metrics")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        
                        ForEach([DrainageSortOption.painLevelDesc, .painLevelAsc, .temperatureDesc, .temperatureAsc]) { option in
                            SortOptionRow(option: option, isSelected: option == selectedSortOption) {
                                selectedSortOption = option
                                onSortChanged(option)
                                isPresented = false
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                // Reset button
                Button(action: {
                    selectedSortOption = .dateDesc
                    onSortChanged(.dateDesc)
                    isPresented = false
                }) {
                    Text("Reset")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 2)
                        )
                }
                
                // Cancel button
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Text("Cancel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(Color.dynamicAccent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.dynamicAccent, lineWidth: 2)
                        )
                }
            }
            .padding()
        }
        .background(Color.dynamicBackground)
        .cornerRadius(20)
    }
}

struct PesentDrainageRow: View {
    let entry: DrainageEntry
    
    private var netFluidAmount: Double {
        let totalAmount = entry.amount
        let salineFlushAmount = entry.fluidSalineFlushAmount ?? 0
        return totalAmount - salineFlushAmount
    }
    
    private var shouldShowPatientName: Bool {
        TokenManager.shared.loadCurrentUser()?.role != "Patient"
    }
    
    private var cellBackgroundColor: Color {
        let painLevel = entry.painLevel ?? 0
        switch painLevel {
        case 0...2: return .gray.opacity(0.1)
        case 3...5: return .yellow.opacity(0.1)
        case 6...8: return .orange.opacity(0.1)
        default: return .red.opacity(0.1)
        }
    }
    
    private var hasVitalSigns: Bool {
        (entry.temperature ?? 0) > 0 ||
        entry.heartRate != nil ||
        (entry.bloodPressure != nil && !entry.bloodPressure!.isEmpty) ||
        entry.respiratoryRate != nil ||
        entry.oxygenSaturation != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Patient Info Row (only show if role is not Patient)
            if shouldShowPatientName, let patientName = entry.patientName, !patientName.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    // Priority color dot (only show if priority exists and is not none)
                    if let patientData = entry.patientData,
                       let priority = patientData.metadata.priority,
                       priority != .none {
                        Circle()
                            .fill(priority.swiftUIColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.dynamicAccent)
                    
                    Text(patientName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            
            // Location and Drainage Type Row
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(entry.location)
                    .font(.headline)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Image(systemName: "drop.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
                
                Text(entry.drainageType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        
                        // Total Fluid Amount
                        Text("\(Int(entry.amount)) \(entry.amountUnit)")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    
                    // Net Fluid Amount (if saline flush is present)
                   
                    if entry.isFluidSalineFlush == true && entry.fluidSalineFlushAmount != nil && entry.fluidSalineFlushAmount! > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.degreesign")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text("Net: \(Int(netFluidAmount)) \(entry.amountUnit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Details Row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "barcode")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(entry.drainageId ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Comment count
                    if let commentsArray = entry.commentsArray, !commentsArray.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "message.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            
                            Text("\(commentsArray.count)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Vital Signs Section
            if hasVitalSigns {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Vital Signs")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let temperature = entry.temperature,temperature > 0  {
                                VitalSignChip(
                                    label: "Temp",
                                    value: "\(Int(temperature))°F",
                                    color: .blue
                                )
                            }
                            
                            if let heartRate = entry.heartRate {
                                VitalSignChip(
                                    label: "HR",
                                    value: "\(Int(heartRate)) bpm",
                                    color: .red
                                )
                            }
                            
                            if let bloodPressure = entry.bloodPressure, !bloodPressure.isEmpty {
                                VitalSignChip(
                                    label: "BP",
                                    value: bloodPressure,
                                    color: .green
                                )
                            }
                            
                            if let respiratoryRate = entry.respiratoryRate {
                                VitalSignChip(
                                    label: "RR",
                                    value: "\(Int(respiratoryRate))",
                                    color: .orange
                                )
                            }
                            
                            if let oxygenSaturation = entry.oxygenSaturation {
                                VitalSignChip(
                                    label: "SpO2",
                                    value: "\(Int(oxygenSaturation))%",
                                    color: .purple
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            
            // Pain Level - Full Width
            PainLevelView(level: entry.painLevel ?? 0)
        }
        .cornerRadius(12)
        .padding(.vertical, 4)
    }
}

struct PainLevelView: View {
    let level: Int
    
    private var painColor: Color {
        switch level {
        case 0...2: return .gray
        case 3...5: return .yellow
        case 6...8: return .orange
        default: return .red
        }
    }
    
    private var backgroundColor: Color {
        switch level {
        case 0...2: return .gray.opacity(0.2)
        case 3...5: return .yellow.opacity(0.2)
        case 6...8: return .orange.opacity(0.2)
        default: return .red.opacity(0.2)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(painColor)
            
            Text("\(level)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(painColor)
                .frame(width: 20, alignment: .center)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .frame(width: 40, height: 6)
                    .foregroundColor(Color.gray.opacity(0.3))
                
                Capsule()
                    .frame(width: CGFloat(min(level, 10)) * 4, height: 6)
                    .foregroundColor(painColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - Barcode Display View
struct BarcodeDisplayView: View {
    let drainageId: String
    @Environment(\.dismiss) private var dismiss
    @State private var isBarcodeGenerated = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Drainage ID Barcode")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if !drainageId.isEmpty {
                    VStack(spacing: 16) {
                        BarcodeView(data: drainageId)
                            .frame(height: 120)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onAppear {
                                isBarcodeGenerated = true
                            }
                        
                        Text(drainageId)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                        
                        Text("Scan this barcode to access drainage details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No drainage ID available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This drainage entry doesn't have a barcode ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("BarcodeDisplayView appeared with drainageId: \(drainageId)")
        }
    }
}

// MARK: - Drainage Filter Sheet
struct DrainageFilterSheet: View {
    @Binding var filter: DrainageFilter
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempFilter: DrainageFilter
    @State private var minAmountText = "0"
    @State private var maxAmountText = ""
    @State private var minTemperatureText = "0"
    @State private var maxTemperatureText = ""
    @State private var minPainLevelText = "0"
    @State private var maxPainLevelText = ""
    
    // Dropdown states
    @State private var showFluidTypeDropdown = false
    @State private var showColorDropdown = false
    @State private var showDrainageTypeDropdown = false
    @State private var showConsistencyDropdown = false
    @State private var showOdorDropdown = false
    @State private var showPatientDropdown = false
    @StateObject private var patientViewModel = PatientSelectionViewModel()
    
    init(filter: Binding<DrainageFilter>, onApply: @escaping () -> Void) {
        self._filter = filter
        self.onApply = onApply
        self._tempFilter = State(initialValue: filter.wrappedValue)
        
        // Initialize text fields
        if let minAmount = filter.wrappedValue.minAmount {
            self._minAmountText = State(initialValue: String(format: "%.0f", minAmount))
        }
        if let maxAmount = filter.wrappedValue.maxAmount {
            self._maxAmountText = State(initialValue: String(format: "%.0f", maxAmount))
        }
        if let minTemp = filter.wrappedValue.minTemperature {
            self._minTemperatureText = State(initialValue: String(format: "%.1f", minTemp))
        }
        if let maxTemp = filter.wrappedValue.maxTemperature {
            self._maxTemperatureText = State(initialValue: String(format: "%.1f", maxTemp))
        }
        if let minPain = filter.wrappedValue.minPainLevel {
            self._minPainLevelText = State(initialValue: String(minPain))
        }
        if let maxPain = filter.wrappedValue.maxPainLevel {
            self._maxPainLevelText = State(initialValue: String(maxPain))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Patient Filter - Only show for non-Patient users
                if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                    
                    // Self Created Filter
                    Section(header: Text("Created By")) {
                        HStack {
                            Button(action: {
                                tempFilter.isSelfCreated.toggle()
                            }) {
                                HStack {
                                    Image(systemName: tempFilter.isSelfCreated ? "checkmark.square.fill" : "square")
                                        .foregroundColor(tempFilter.isSelfCreated ? .accentColor : .gray)
                                   
                                    Text("Show only drainage records I created")
                                        .foregroundColor(.primary)
                                        .padding(.leading,8)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                    }
                    
                    Section(header: Text("Patient")) {
                        Button(action: {
                            showPatientDropdown.toggle()
                            if showPatientDropdown && patientViewModel.patients.isEmpty {
                                Task {
                                    await patientViewModel.fetchPatients()
                                }
                            }
                        }) {
                            HStack {
                                if let patientId = tempFilter.patientId,
                                   let selectedPatient = patientViewModel.patients.first(where: { $0.userSlug == patientId }) {
                                    Text(selectedPatient.firstName)
                                        .foregroundColor(.primary)
                                } else {
                                    Text("Select Patient")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: showPatientDropdown ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if showPatientDropdown {
                            if patientViewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading patients...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading)
                            } else {
                                ForEach(patientViewModel.patients) { patient in
                                    HStack {
                                        Button(action: {
                                            if tempFilter.patientId == patient.userSlug {
                                                tempFilter.patientId = nil
                                            } else {
                                                tempFilter.patientId = patient.userSlug
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: tempFilter.patientId == patient.userSlug ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(tempFilter.patientId == patient.userSlug ? .accentColor : .gray)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(patient.firstName)
                                                        .foregroundColor(.primary)
                                                    Text(patient.email ?? "")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        Spacer()
                                    }
                                    .padding(.leading)
                                    .task {
                                        await patientViewModel.loadMoreIfNeeded(currentPatient: patient)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Amount Range
                Section(header: Text("Fluid Amount (ml)")) {
                    HStack {
                        TextField("Min", text: $minAmountText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("-")
                            .foregroundColor(.secondary)
                        
                        TextField("Max", text: $maxAmountText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Temperature Range
                Section(header: Text("Temperature (°F)")) {
                    HStack {
                        TextField("Min", text: $minTemperatureText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("-")
                            .foregroundColor(.secondary)
                        
                        TextField("Max", text: $maxTemperatureText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Pain Level Range
                Section(header: Text("Pain Level (0-10)")) {
                    HStack {
                        TextField("Min", text: $minPainLevelText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("-")
                            .foregroundColor(.secondary)
                        
                        TextField("Max", text: $maxPainLevelText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                
                // Date Range
                Section(header: Text("Date Range")) {
                    HStack {
                        Text("From")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let minDate = tempFilter.minRecordedAt {
                            DatePicker("", selection: Binding(
                                get: { minDate },
                                set: { tempFilter.minRecordedAt = $0 }
                            ), displayedComponents: [.date])
                            .labelsHidden()
                        } else {
                            Button("Select Date") {
                                tempFilter.minRecordedAt = Date()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if tempFilter.minRecordedAt != nil {
                            Button("Clear") {
                                tempFilter.minRecordedAt = nil
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text("To")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let maxDate = tempFilter.maxRecordedAt {
                            DatePicker("", selection: Binding(
                                get: { maxDate },
                                set: { tempFilter.maxRecordedAt = $0 }
                            ), displayedComponents: [.date])
                            .labelsHidden()
                        } else {
                            Button("Select Date") {
                                tempFilter.maxRecordedAt = Date()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if tempFilter.maxRecordedAt != nil {
                            Button("Clear") {
                                tempFilter.maxRecordedAt = nil
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                }
                
                // Multi-select Filters with Dropdowns
                
                Section(header: Text("Color")) {
                    Button(action: {
                        showColorDropdown.toggle()
                    }) {
                        HStack {
                            Text(tempFilter.color.isEmpty ? "Select Colors" : "\(tempFilter.color.count) selected")
                                .foregroundColor(tempFilter.color.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: showColorDropdown ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showColorDropdown {
                        ForEach(DrainageEntry.colorOptions.filter { $0 != "Other" }, id: \.self) { color in
                            HStack {
                                Button(action: {
                                    if tempFilter.color.contains(color) {
                                        tempFilter.color.removeAll { $0 == color }
                                    } else {
                                        tempFilter.color.append(color)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: tempFilter.color.contains(color) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(tempFilter.color.contains(color) ? .accentColor : .gray)
                                        Text(color)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                }
                
                
                Section(header: Text("Odor")) {
                    Button(action: {
                        showOdorDropdown.toggle()
                    }) {
                        HStack {
                            Text(tempFilter.odor.isEmpty ? "Select Odors" : "\(tempFilter.odor.count) selected")
                                .foregroundColor(tempFilter.odor.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: showOdorDropdown ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showOdorDropdown {
                        ForEach(DrainageEntry.odorOptions.filter { $0 != "Other" }, id: \.self) { odor in
                            HStack {
                                Button(action: {
                                    if tempFilter.odor.contains(odor) {
                                        tempFilter.odor.removeAll { $0 == odor }
                                    } else {
                                        tempFilter.odor.append(odor)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: tempFilter.odor.contains(odor) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(tempFilter.odor.contains(odor) ? .accentColor : .gray)
                                        Text(odor)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                }
                
                Section(header: Text("Fluid Type")) {
                    Button(action: {
                        showFluidTypeDropdown.toggle()
                    }) {
                        HStack {
                            Text(tempFilter.fluidType.isEmpty ? "Select Fluid Types" : "\(tempFilter.fluidType.count) selected")
                                .foregroundColor(tempFilter.fluidType.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: showFluidTypeDropdown ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showFluidTypeDropdown {
                        ForEach(DrainageEntry.fluidTypes.filter { $0 != "Other" }, id: \.self) { type in
                            HStack {
                                Button(action: {
                                    if tempFilter.fluidType.contains(type) {
                                        tempFilter.fluidType.removeAll { $0 == type }
                                    } else {
                                        tempFilter.fluidType.append(type)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: tempFilter.fluidType.contains(type) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(tempFilter.fluidType.contains(type) ? .accentColor : .gray)
                                        Text(type)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                }
                
            
                
                Section(header: Text("Drainage Type")) {
                    Button(action: {
                        showDrainageTypeDropdown.toggle()
                    }) {
                        HStack {
                            Text(tempFilter.drainageType.isEmpty ? "Select Drainage Types" : "\(tempFilter.drainageType.count) selected")
                                .foregroundColor(tempFilter.drainageType.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: showDrainageTypeDropdown ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showDrainageTypeDropdown {
                        ForEach(DrainageEntry.drainageTypeOptions.filter { $0 != "Other" }, id: \.self) { type in
                            HStack {
                                Button(action: {
                                    if tempFilter.drainageType.contains(type) {
                                        tempFilter.drainageType.removeAll { $0 == type }
                                    } else {
                                        tempFilter.drainageType.append(type)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: tempFilter.drainageType.contains(type) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(tempFilter.drainageType.contains(type) ? .accentColor : .gray)
                                        Text(type)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                }
                
                Section(header: Text("Consistency")) {
                    Button(action: {
                        showConsistencyDropdown.toggle()
                    }) {
                        HStack {
                            Text(tempFilter.consistency.isEmpty ? "Select Consistencies" : "\(tempFilter.consistency.count) selected")
                                .foregroundColor(tempFilter.consistency.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: showConsistencyDropdown ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if showConsistencyDropdown {
                        ForEach(DrainageEntry.consistencyOptions.filter { $0 != "Other" }, id: \.self) { consistency in
                            HStack {
                                Button(action: {
                                    if tempFilter.consistency.contains(consistency) {
                                        tempFilter.consistency.removeAll { $0 == consistency }
                                    } else {
                                        tempFilter.consistency.append(consistency)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: tempFilter.consistency.contains(consistency) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(tempFilter.consistency.contains(consistency) ? .accentColor : .gray)
                                        Text(consistency)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                }
                
            }
            .navigationTitle("Filter Drainage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        tempFilter.clearAll()
                        minAmountText = ""
                        maxAmountText = ""
                        minTemperatureText = ""
                        maxTemperatureText = ""
                        minPainLevelText = ""
                        maxPainLevelText = ""
                        applyFilters()
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private func applyFilters() {
        // Apply text field values to tempFilter
        if !minAmountText.isEmpty, let value = Double(minAmountText) {
            tempFilter.minAmount = value
        } else {
            tempFilter.minAmount = nil
        }
        
        if !maxAmountText.isEmpty, let value = Double(maxAmountText) {
            tempFilter.maxAmount = value
        } else {
            tempFilter.maxAmount = nil
        }
        
        if !minTemperatureText.isEmpty, let value = Double(minTemperatureText) {
            tempFilter.minTemperature = value
        } else {
            tempFilter.minTemperature = nil
        }
        
        if !maxTemperatureText.isEmpty, let value = Double(maxTemperatureText) {
            tempFilter.maxTemperature = value
        } else {
            tempFilter.maxTemperature = nil
        }
        
        if !minPainLevelText.isEmpty, let value = Int(minPainLevelText) {
            tempFilter.minPainLevel = max(0, min(10, value))
        } else {
            tempFilter.minPainLevel = nil
        }
        
        if !maxPainLevelText.isEmpty, let value = Int(maxPainLevelText) {
            tempFilter.maxPainLevel = max(0, min(10, value))
        } else {
            tempFilter.maxPainLevel = nil
        }
        
        // Update the actual filter
        filter = tempFilter
    }
}

// MARK: - Sort Option Row Component
struct SortOptionRow: View {
    let option: DrainageSortOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.rawValue)
                    .foregroundColor(.dynamicAccent)
                    .padding(.vertical, 14)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.dynamicAccent)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal)
            .background(isSelected ? Color.dynamicAccent.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        Divider()
    }
}

// MARK: - Drainage Card View
struct DrainageCardView: View {
    let entry: DrainageEntry
    let showingBarcodes: Bool
    @State private var showingAttachmentDropdown = false
    @State private var showingImageGallery = false
    @State private var selectedEntryForBarcode: DrainageEntry?
    
    private var netFluidAmount: Double {
        let totalAmount = entry.amount
        let salineFlushAmount = entry.fluidSalineFlushAmount ?? 0
        return totalAmount - salineFlushAmount
    }
    
    private var shouldShowPatientName: Bool {
        TokenManager.shared.loadCurrentUser()?.role != "Patient"
    }
    
    private var cardBorderColor: Color {
        let color = entry.color
        switch color {
        case "Clear":
            return Color(hex: "#FFFFFF") // White
        case "Yellow":
            return Color(hex: "#FFD700") // Bright Yellow
        case "Pink/Light Red":
            return Color(hex: "#FF69B4") // Hot Pink
        case "Red/Bloody":
            return Color(hex: "#DC143C") // Crimson Red
        case "Green":
            return Color(hex: "#32CD32") // Lime Green
        case "Brown":
            return Color(hex: "#8B4513") // Saddle Brown
        case "Cloudy":
            return Color(hex: "#B0BEC5") // Light Gray-Blue
        case "Other":
            return Color(hex: "#9E9E9E") // Neutral Gray
        default:
            return Color(hex: "#9E9E9E") // Fallback Gray
        }
    }
    
    
    private var painColor: Color {
        switch entry.painLevel  ?? 0{
        case 0...2: return .gray.opacity(0.5)
        case 3...5: return .yellow.opacity(0.5)
        case 6...8: return .orange.opacity(0.5)
        default: return .red.opacity(0.5)
        }
    }
    
    private var totalAttachmentCount: Int {
        let beforeCount = entry.beforeImageSign?.count ?? 0
        let afterCount = entry.afterImageSign?.count ?? 0
        let fluidCupCount = entry.fluidCupImageSign?.count ?? 0
        return beforeCount + afterCount + fluidCupCount
    }
    
    private var beforeImageCount: Int {
        entry.beforeImageSign?.count ?? 0
    }
    
    private var afterImageCount: Int {
        entry.afterImageSign?.count ?? 0
    }
    
    private var fluidCupImageCount: Int {
        entry.fluidCupImageSign?.count ?? 0
    }
    
    private var hasVitalSigns: Bool {
        (entry.temperature ?? 0) > 0 ||
        entry.heartRate != nil ||
        (entry.bloodPressure != nil && !entry.bloodPressure!.isEmpty) ||
        entry.respiratoryRate != nil ||
        entry.oxygenSaturation != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center){
                    Spacer()
                    if let drainageId = entry.drainageId, !drainageId.isEmpty {
                        Text("\(drainageId)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                // Show barcode if toggle is on and entry has barcode
                if showingBarcodes,
                   let drainageId = entry.drainageId,
                   !drainageId.isEmpty {
                    Button(action: {
                        selectedEntryForBarcode = entry
                    }) {
                        VStack(spacing: 8) {
                            BarcodeView(data: drainageId)
                                .frame(height: 60)
                                .padding(.horizontal)
                        }
                        .background(Color(.systemGray6).opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                // Header with patient info and priority
                if shouldShowPatientName, let patientName = entry.patientName, !patientName.isEmpty {
                    HStack {
                        // Priority color dot
                        if let patientData = entry.patientData,
                           let priority = patientData.metadata.priority,
                           priority != .none {
                            Circle()
                                .fill(priority.swiftUIColor)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(patientName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                
                // Main content
                VStack(alignment: .leading, spacing: 8) {
                    // Amount and location
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(entry.amount)) \(entry.amountUnit)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if entry.isFluidSalineFlush == true && entry.fluidSalineFlushAmount != nil && entry.fluidSalineFlushAmount! > 0 {
                                Text("Net: \(Int(netFluidAmount)) \(entry.amountUnit)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.location)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text(entry.drainageType)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Fluid type and color
                    HStack {
//                        Text(entry.fluidType)
//                            .font(.caption)
//                            .foregroundColor(.black)
//                            .padding(.horizontal, 8)
//                            .padding(.vertical, 4)
//                            .background(cardBorderColor.opacity(0.1))
//                            .clipShape(Capsule())
                        
                    
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(entry.consistency.indices, id: \.self) { index in
                                    Text(entry.consistency[index])
                                        .font(.caption)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(cardBorderColor.opacity(0.1))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(cardBorderColor, lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        Spacer()
                    }
                    
                    // Vital Signs Section
                    if hasVitalSigns {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vital Signs")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    if let temperature = entry.temperature,temperature > 0 {
                                        VitalSignChip(
                                            label: "Temp",
                                            value: "\(Int(temperature))°F",
                                            color: .blue
                                        )
                                    }
                                    
                                    if let heartRate = entry.heartRate {
                                        VitalSignChip(
                                            label: "HR",
                                            value: "\(Int(heartRate)) bpm",
                                            color: .red
                                        )
                                    }
                                    
                                    if let bloodPressure = entry.bloodPressure, !bloodPressure.isEmpty {
                                        VitalSignChip(
                                            label: "BP",
                                            value: bloodPressure,
                                            color: .green
                                        )
                                    }
                                    
                                    if let respiratoryRate = entry.respiratoryRate {
                                        VitalSignChip(
                                            label: "RR",
                                            value: "\(Int(respiratoryRate))",
                                            color: .orange
                                        )
                                    }
                                    
                                    if let oxygenSaturation = entry.oxygenSaturation {
                                        VitalSignChip(
                                            label: "SpO2",
                                            value: "\(Int(oxygenSaturation))%",
                                            color: .purple
                                        )
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    
                    // Footer with time and ID
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            // Comment count
                            if let commentsArray = entry.commentsArray, !commentsArray.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "message.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(commentsArray.count)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Attachment counter
                            if totalAttachmentCount > 0 {
                                Button(action: {
                                    showingAttachmentDropdown.toggle()
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "paperclip")
                                            .font(.caption2)
                                            .foregroundColor(Color.dynamicAccent)
                                        
                                        Text("\(totalAttachmentCount)")
                                            .font(.caption2)
                                            .foregroundColor(Color.dynamicAccent)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                }
            }
            .padding()
            
          
            
            Divider()
                .offset(y: 11.5)
            // Bottom color section
            HStack {
                Text(entry.color)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Pain level and temperature indicators
                HStack(spacing: 8) {
                    if let painLevel = entry.painLevel {
                        Text("\(Int(painLevel))")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(painColor)
                            .cornerRadius(4)
                    }
//                    if let temperature = entry.temperature {
//                        Text("\(Int(temperature))°F")
//                            .font(.caption2)
//                            .fontWeight(.medium)
//                            .foregroundColor(.primary)
//                            .padding(.horizontal, 6)
//                            .padding(.vertical, 2)
//                            .background(Color.white)
//                            .cornerRadius(4)
//                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(cardBorderColor.opacity(0.1))
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            // Attachment dropdown
            VStack {
                if showingAttachmentDropdown {
                    AttachmentDropdownView(
                        beforeCount: beforeImageCount,
                        afterCount: afterImageCount,
                        fluidCupCount: fluidCupImageCount,
                        onViewAll: {
                            showingAttachmentDropdown = false
                            showingImageGallery = true
                        },
                        onClose: {
                            showingAttachmentDropdown = false
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
                }
            },
            alignment: .bottomTrailing
        )
        .sheet(isPresented: $showingImageGallery) {
            AttachmentGalleryView(entry: entry)
        }
        .sheet(item: $selectedEntryForBarcode) { entry in
            BarcodeDisplayView(drainageId: entry.drainageId ?? "")
        }
    }
}

// MARK: - Attachment Dropdown View
struct AttachmentDropdownView: View {
    let beforeCount: Int
    let afterCount: Int
    let fluidCupCount: Int
    let onViewAll: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attachments")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if beforeCount > 0 {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Before Images: \(beforeCount)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
                
                if afterCount > 0 {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("After Images: \(afterCount)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
                
                if fluidCupCount > 0 {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Fluid Cup Images: \(fluidCupCount)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Button(action: onViewAll) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.caption2)
                    Text("View All Images")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .frame(width: 200)
    }
}

// MARK: - Image Filter Type
enum ImageFilterType: String, CaseIterable {
   // case all = "All"
    case before = "Before Images"
    case after = "After Images"
    case fluidCup = "Fluid Cup Images"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Attachment Gallery View
struct AttachmentGalleryView: View {
    let entry: DrainageEntry
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex = 0
    @State private var showingDownloadAlert = false
    @State private var isDownloading = false
    @State private var selectedFilter: ImageFilterType = .before
    @State private var showingSuccessAlert = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var showingZoomControls = false
    
    private var allImages: [(type: String, urls: [String])] {
        var images: [(type: String, urls: [String])] = []
        
        if let beforeImages = entry.beforeImageSign, !beforeImages.isEmpty {
            images.append((type: "Before Images", urls: beforeImages))
        }
        
        if let afterImages = entry.afterImageSign, !afterImages.isEmpty {
            images.append((type: "After Images", urls: afterImages))
        }
        
        if let fluidCupImages = entry.fluidCupImageSign, !fluidCupImages.isEmpty {
            images.append((type: "Fluid Cup Images", urls: fluidCupImages))
        }
        
        return images
    }
    
    private var filteredImages: [(type: String, urls: [String])] {
        switch selectedFilter {
//        case .all:
//            return allImages
        case .before:
            return allImages.filter { $0.type == "Before Images" }
        case .after:
            return allImages.filter { $0.type == "After Images" }
        case .fluidCup:
            return allImages.filter { $0.type == "Fluid Cup Images" }
        }
    }
    
    private var totalImageCount: Int {
        filteredImages.reduce(0) { $0 + $1.urls.count }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Picker
                if !allImages.isEmpty {
                    Picker("Image Type", selection: $selectedFilter) {
                        ForEach(ImageFilterType.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                }
                
                if allImages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Images Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This drainage entry doesn't have any attached images")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredImages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Images in Selected Category")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("No images found for \(selectedFilter.displayName)")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Image gallery with zoom
                    ZStack {
                        TabView(selection: $selectedImageIndex) {
                            ForEach(Array(filteredImages.enumerated()), id: \.offset) { sectionIndex, section in
                                ForEach(Array(section.urls.enumerated()), id: \.offset) { imageIndex, url in
                                    AttachZoom(
                                        imageURL: url,
                                        zoomScale: $zoomScale,
                                        lastZoomScale: $lastZoomScale,
                                        showingZoomControls: $showingZoomControls
                                    )
                                    .tag(sectionIndex * 1000 + imageIndex)
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                        .onTapGesture {
                            showingZoomControls.toggle()
                        }
                        
                        // Zoom controls overlay
                        if showingZoomControls {
                            VStack {
                                Spacer()
                                
                                HStack(spacing: 20) {
                                    // Zoom out button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            zoomScale = max(0.5, zoomScale - 0.5)
                                            lastZoomScale = zoomScale
                                        }
                                    }) {
                                        Image(systemName: "minus.magnifyingglass")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel("Zoom Out Image")
                                    
                                    // Reset zoom button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            zoomScale = 1.0
                                            lastZoomScale = 1.0
                                        }
                                    }) {
                                        Image(systemName: "1.magnifyingglass")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel("Reset Zoom")
                                    
                                    // Zoom in button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            zoomScale = min(3.0, zoomScale + 0.5)
                                            lastZoomScale = zoomScale
                                        }
                                    }) {
                                        Image(systemName: "plus.magnifyingglass")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel("Zoom In Image")
                                }
                                .padding(.bottom, 100)
                            }
                        }
                    }
                    
                    // Image info
                    VStack(spacing: 8) {
                        HStack {
                            Text("Image \(selectedImageIndex + 1) of \(totalImageCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let currentSection = getCurrentSection() {
                                Text(currentSection.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Download all button
                        Button(action: {
                            showingDownloadAlert = true
                        }) {
                            HStack {
                                if isDownloading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(isDownloading ? "Downloading..." : "Download All Images")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(25)
                        }
                        .disabled(isDownloading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }
            }
            .navigationTitle("Drainage Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Download Images", isPresented: $showingDownloadAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Download All", role: .none) {
                downloadAllImages()
            }
        } message: {
            Text("This will download all \(totalImageCount) images to your Photos library.")
        }
        .alert("Download Complete", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All \(totalImageCount) images have been successfully saved to your Photos library.")
        }
        .onChange(of: selectedFilter) { _ in
            selectedImageIndex = 0
        }
    }
    
    private func getCurrentSection() -> (type: String, urls: [String])? {
        var currentIndex = 0
        for section in filteredImages {
            if selectedImageIndex < currentIndex + section.urls.count {
                return section
            }
            currentIndex += section.urls.count
        }
        return nil
    }
    
    private func downloadAllImages() {
        isDownloading = true
        
        Task {
            do {
                for section in filteredImages {
                    for urlString in section.urls {
                        guard let url = URL(string: urlString) else { continue }
                        
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        }
                        
                        // Small delay to prevent overwhelming the system
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    }
                }
                
                await MainActor.run {
                    isDownloading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
                print("Error downloading images: \(error)")
            }
        }
    }
}

// MARK: - Attach Zoom View
struct AttachZoom: View {
    let imageURL: String
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    @Binding var showingZoomControls: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(dragOffset)
                    .gesture(
                        SimultaneousGesture(
                            // Pinch to zoom gesture
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastZoomScale
                                    lastZoomScale = value
                                    zoomScale = min(max(zoomScale * delta, 0.5), 3.0)
                                }
                                .onEnded { _ in
                                    lastZoomScale = 1.0
                                },
                            
                            // Drag gesture
                            DragGesture()
                                .onChanged { value in
                                    if zoomScale > 1.0 {
                                        dragOffset = CGSize(
                                            width: lastDragOffset.width + value.translation.width,
                                            height: lastDragOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if zoomScale > 1.0 {
                                        // Constrain drag to image bounds
                                        let maxOffsetX = (geometry.size.width * (zoomScale - 1)) / 2
                                        let maxOffsetY = (geometry.size.height * (zoomScale - 1)) / 2
                                        
                                        dragOffset = CGSize(
                                            width: min(max(dragOffset.width, -maxOffsetX), maxOffsetX),
                                            height: min(max(dragOffset.height, -maxOffsetY), maxOffsetY)
                                        )
                                        
                                        lastDragOffset = dragOffset
                                    } else {
                                        dragOffset = .zero
                                        lastDragOffset = .zero
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if zoomScale > 1.0 {
                                zoomScale = 1.0
                                dragOffset = .zero
                                lastDragOffset = .zero
                            } else {
                                zoomScale = 2.0
                            }
                        }
                    }
            } placeholder: {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            }
        }
        .onChange(of: zoomScale) { newValue in
            if newValue <= 1.0 {
                dragOffset = .zero
                lastDragOffset = .zero
            }
        }
    }
}

// MARK: - Vital Sign Chip Component
struct VitalSignChip: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
       // .background(color.opacity(0.1))
        .background(.gray.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
              //  .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Report Confirmation View
struct ReportConfirmationView: View {
    @Binding var isPresented: Bool
    @Binding var includeConversations: Bool
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Are you sure you want to generate the report?")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            
            // Description
            Text("Once generated, you can re-download it from the Report -> Drainage Report.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Toggle section
            HStack {
                Text("Also includes conversations?")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $includeConversations)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 12) {
                // No button
                Button(action: {
                    isPresented = false
                }) {
                    Text("No")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                // Yes button
                Button(action: {
                    onConfirm()
                }) {
                    Text("Yes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.dynamicAccent)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}


#Preview {
    DrainageListView(incidentId: "test-mongodb-id", incidentName: "Test Incident", incidentDisplayId: "INC-001")
        .environmentObject(DrainageStore())
}
