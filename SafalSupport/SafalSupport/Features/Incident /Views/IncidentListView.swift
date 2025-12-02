import CoreImage.CIFilterBuiltins
import PDFKit
import SwiftUI

extension Notification.Name {
    static let updateIncidentRecord = Notification.Name("updateIncidentRecord")
    static let RefreshIncidentList = Notification.Name("RefreshIncidentList")
    static let ApplyActiveIncidentFilter = Notification.Name("ApplyActiveIncidentFilter")
}

// MARK: - View Type Enum

enum IncidentViewType: String, CaseIterable {
    case list
    case card

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

// Static property to store pending filter
class IncidentFilterManager {
    static var pendingActiveFilter = false
}

struct IncidentListView: View {
    let patientSlug: String?
    let patientName: String?

    @StateObject private var incidentStore = IncidentStore()
    @StateObject private var featureLimitService = FeatureLimitService.shared
    @State private var searchText = ""
    @State private var selectedSortOption: IncidentSortOption = .dateDesc
    @State private var showingSortSheet = false
    @State private var showingFilterSheet = false
    @State private var showingDeleteAlert = false
    @State private var currentFilter = IncidentFilter()
    @State private var incidentToDelete: Incident?
    @State private var selectedIncidentForBarcode: Incident?
    @State private var selectedIncidentForReport: Incident?
    @State private var showingPDFViewer = false
    @State private var pdfURL: URL?
    @State private var incidentToClose: Incident?
    @State private var showingCloseAlert = false
    @State private var showingIncidentLimitAlert = false
    @State private var limitAlertMessage = ""
    @State private var showingDrainageLimitAlert = false
    @State private var drainageLimitAlertMessage = ""
    @State private var showingBarcodes = false

    // View type states
    @State private var viewType: IncidentViewType = {
        if let savedViewType = UserDefaults.standard.string(forKey: "IncidentViewType"),
           let viewType = IncidentViewType(rawValue: savedViewType) {
            return viewType
        }
        return .list
    }()

    init(patientSlug: String? = nil, patientName: String? = nil) {
        self.patientSlug = patientSlug
        self.patientName = patientName
    }

    var body: some View {
        mainContent
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toast(message: $incidentStore.errorMessage, type: .error)
            .toast(message: $incidentStore.successMessage, type: .success)
            .alert("Delete Incident", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let incident = incidentToDelete {
                        Task {
                            await incidentStore.deleteIncident(incident)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this incident? This action cannot be undone.")
            }
            .alert("Close Incident", isPresented: $showingCloseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Close", role: .destructive) {
                    if let incident = incidentToClose {
                        Task {
                            await incidentStore.closeIncident(incident)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to close this incident?\n\nOnce closed, this incident cannot be reopened. You may still create a linked incident afterward.")
            }
            .alert("Incident Limit Reached", isPresented: $showingIncidentLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(limitAlertMessage)
            }
            .alert("Drainage Limit Reached", isPresented: $showingDrainageLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(drainageLimitAlertMessage)
            }
            .sheet(item: $selectedIncidentForBarcode) { incident in
                IncidentBarcodeDisplayView(incidentId: incident.incidentId ?? "")
            }
            .overlay {
                if let incident = selectedIncidentForReport, let url = pdfURL {
                    CustomPDFOverlay(url: url, incidentName: incident.name) {
                        selectedIncidentForReport = nil
                        pdfURL = nil
                    }
                }
            }
            .sheet(isPresented: $showingSortSheet) {
                IncidentSortSheet(
                    selectedSortOption: $selectedSortOption,
                    isPresented: $showingSortSheet,
                    onSortChanged: { newSortOption in
                        Task {
                            await incidentStore.updateSortOption(newSortOption, filter: currentFilter)
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingFilterSheet) {
                IncidentFilterSheet(
                    filter: $currentFilter,
                    onApply: {
                        Task {
                            await incidentStore.updateFilter(currentFilter)
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: searchText) { newValue in
                incidentStore.searchIncidents(query: newValue)
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            searchAndSortSection
            contentBody
        }
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        ZStack {
            if incidentStore.isLoading && incidentStore.incidents.isEmpty {
                incidentShimmerList
            } else if !searchText.isEmpty && filteredIncidents.isEmpty {
                IncidentNoSearchResultsView(searchText: searchText) {
                    searchText = ""
                    incidentStore.searchIncidents(query: "")
                }
            } else if incidentStore.incidents.isEmpty && currentFilter.hasActiveFilters {
                IncidentNoFilterResultsView(currentFilter: currentFilter) {
                    // Clear filters action
                    currentFilter.clearAll()
                    Task {
                        await incidentStore.updateFilter(currentFilter)
                    }
                }
            } else if incidentStore.incidents.isEmpty {
                emptyStateView
            } else {
                if viewType == .list {
                    incidentsList
                } else {
                    incidentsCardView
                }
            }
        }
        .onAppear {
            // Add notification observer for refresh
            NotificationCenter.default.addObserver(
                forName: .RefreshIncidentList,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await incidentStore.refreshIncidents(patientSlug: incidentStore.initialPatientSlug)
                }
            }
        }
    }

    // MARK: - Search and Sort Section

    private var searchAndSortSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search incidents...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            incidentStore.searchIncidents(query: searchText)
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            incidentStore.searchIncidents(query: "")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Sort Button
                Button {
                    showingSortSheet = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color.dynamicAccent)
                    }
                }

                // Filter Button
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

                // Create button
                if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                    Button {
                        let incidentLimitCheck = featureLimitService.canCreateIncident()
                        if !incidentLimitCheck.allowed {
                            limitAlertMessage = incidentLimitCheck.message ?? "Incident limit reached"
                            showingIncidentLimitAlert = true
                        } else {
                            NavigationManager.shared.navigate(to: .addIncident(), style: .presentSheet())
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

            // View type toggle
            HStack {
                Text("View:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("View Type", selection: $viewType) {
                    ForEach(IncidentViewType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 200)
                .onChange(of: viewType) { newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "IncidentViewType")
                }
            }

            // Sort indicator
            if selectedSortOption != .dateDesc {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(Color.dynamicAccent)
                        .font(.caption2)

                    Text("Sorted by: \(selectedSortOption.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Reset") {
                        selectedSortOption = .dateDesc
                        Task {
                            await incidentStore.updateSortOption(.dateDesc, filter: currentFilter)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Color.dynamicAccent)
                }
            }
        }
        .padding()
    }

    // MARK: - Filtered Incidents

    private var filteredIncidents: [Incident] {
        var filtered = incidentStore.incidents

        // Apply sort
        filtered = filtered.sorted(by: selectedSortOption.sortDescriptor)

        return filtered
    }

    // MARK: - Incidents List

    private var incidentsList: some View {
        List {
            ForEach(filteredIncidents) { incident in
                VStack(spacing: 0) {
                    IncidentRowView(incident: incident) {
                        NavigationManager.shared.navigate(to: .incidentDetail(incident: incident))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NavigationManager.shared.navigate(to: .incidentDetail(incident: incident))
                    }
                    .task {
                        await incidentStore.loadMoreIfNeeded(currentItem: incident)
                    }

                    // Show barcode if toggle is on and incident has barcode
                    if showingBarcodes, let incidentId = incident.incidentId, !incidentId.isEmpty {
                        VStack(spacing: 8) {
                            Divider()
                                .padding(.horizontal)

                            BarcodeView(data: incidentId)
                                .frame(height: 60)
                                .padding(.horizontal)

                            Text(incidentId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .padding(.bottom, 8)
                        }
                        .background(Color(.systemGray6).opacity(0.5))
                    }
                }
                .swipeActions(edge: .trailing) {
                    // View Records button
                    Button {
                        NavigationManager.shared.navigate(
                            to: .drainageListView(patientSlug: nil, patientName: nil, incidentId: incident.id, incidentName: incident.name, incidentDisplayId: incident.incidentId),
                            style: .push()
                        )
                    } label: {
                        Label("View Records", systemImage: "list.bullet")
                    }
                    .tint(.green)

                    // Report button
                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        Button {
                            Task {
                                await downloadAndShowReport(for: incident)
                            }
                        } label: {
                            Label("Report", systemImage: "arrow.down.circle.fill")
                        }
                        .tint(.orange)
                    }
                    // Create Record button - only show for Active incidents
                    if incident.status == "Active" {
                        Button {
                            // Check drainage limit on long press
                            let drainageLimitCheck = featureLimitService.canCreateDrainage()
                            if !drainageLimitCheck.allowed {
                                drainageLimitAlertMessage = drainageLimitCheck.message ?? "Drainage limit reached"
                                showingDrainageLimitAlert = true
                            } else {
                                // If limit allows, proceed with navigation
                                NavigationManager.shared.navigate(
                                    to: .addDrainageFromIncident(incident: incident),
                                    style: .presentSheet()
                                )
                            }
                        } label: {
                            Label("Create Record", systemImage: "plus.circle")
                        }
                        .tint(.blue)
                    }

                    // Add Linked Incident button - only show for Closed incidents
                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        if incident.status == "Closed" {
                            Button {
                                let incidentLimitCheck = featureLimitService.canCreateIncident()
                                if !incidentLimitCheck.allowed {
                                    limitAlertMessage = incidentLimitCheck.message ?? "Incident limit reached"
                                    showingIncidentLimitAlert = true
                                } else {
                                    NavigationManager.shared.navigate(
                                        to: .addIncident(linkedFromIncident: incident),
                                        style: .presentSheet()
                                    )
                                }

                            } label: {
                                Label("Add Linked Incident", systemImage: "link.badge.plus")
                            }
                            .tint(.purple)
                        }
                    }

                    // Delete button (only for the owner and Active incidents)
                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" && incident.status == "Active" {
                        if incident.userId == TokenManager.shared.getUserId() {
                            Button(role: .destructive) {
                                incidentToDelete = incident
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .contextMenu {
                    // View Records option
                    Button {
                        NavigationManager.shared.navigate(
                            to: .drainageListView(patientSlug: nil, patientName: nil, incidentId: incident.id, incidentName: incident.name, incidentDisplayId: incident.incidentId),
                            style: .push()
                        )
                    } label: {
                        Label("View Records", systemImage: "list.bullet")
                    }

                  //  if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        // Report option
                        Button {
                            Task {
                                await downloadAndShowReport(for: incident)
                            }
                        } label: {
                            Label("Download Report", systemImage: "arrow.down.circle.fill")
                        }
                  //  }
                    // Create Record option - only show for Active incidents
                    if incident.status == "Active" {
                        Button {
                            // Check drainage limit on long press
                            let drainageLimitCheck = featureLimitService.canCreateDrainage()
                            if !drainageLimitCheck.allowed {
                                drainageLimitAlertMessage = drainageLimitCheck.message ?? "Drainage limit reached"
                                showingDrainageLimitAlert = true
                            } else {
                                // If limit allows, proceed with navigation
                                NavigationManager.shared.navigate(
                                    to: .addDrainageFromIncident(incident: incident),
                                    style: .presentSheet()
                                )
                            }
                        } label: {
                            Label("Create Record", systemImage: "plus.circle")
                        }
                    }

                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        // Add Linked Incident option - only show for Closed incidents
                        if incident.status == "Closed" {
                            Button {
                                let incidentLimitCheck = featureLimitService.canCreateIncident()
                                if !incidentLimitCheck.allowed {
                                    limitAlertMessage = incidentLimitCheck.message ?? "Incident limit reached"
                                    showingIncidentLimitAlert = true
                                } else {
                                    NavigationManager.shared.navigate(
                                        to: .addIncident(linkedFromIncident: incident),
                                        style: .presentSheet()
                                    )
                                }

                            } label: {
                                Label("Add Linked Incident", systemImage: "link.badge.plus")
                            }
                        }
                    }
                    // Barcode option
                    if let incidentId = incident.incidentId, !incidentId.isEmpty {
                        Button {
                            selectedIncidentForBarcode = incident
                        } label: {
                            Label("Incident ID Code", systemImage: "barcode")
                        }
                    }

                    // Close Incident option - only show for Active incidents
                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        if incident.status == "Active" {
                            Button {
                                incidentToClose = incident
                                showingCloseAlert = true
                            } label: {
                                Label("Close this incident", systemImage: "xmark.circle")
                            }
                        }
                    }

                    // Delete option (only for the owner and Active incidents)
                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" && incident.status == "Active" {
                        if incident.userId == TokenManager.shared.getUserId() {
                            Button(role: .destructive) {
                                incidentToDelete = incident
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Incident", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if incidentStore.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more incidents...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .listStyle(.plain)
        .refreshable {
            try? await Task.sleep(nanoseconds: 500000000) // Add a small delay
            await incidentStore.refreshIncidents(patientSlug: patientSlug)
        }
        .onAppear {
            // Check for pending Active filter
            if IncidentFilterManager.pendingActiveFilter {
                IncidentFilterManager.pendingActiveFilter = false
                currentFilter.status = "Active"
                Task {
                    await incidentStore.updateFilter(currentFilter)
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
    }

    private var incidentsCardView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                ForEach(filteredIncidents) { incident in
                    IncidentCardView(incident: incident, showingBarcodes: showingBarcodes)
                        .onTapGesture {
                            NavigationManager.shared.navigate(to: .incidentDetail(incident: incident))
                        }
                        .task {
                            await incidentStore.loadMoreIfNeeded(currentItem: incident)
                        }
                        .contextMenu {
                            // View Records option
                            Button {
                                NavigationManager.shared.navigate(
                                    to: .drainageListView(patientSlug: nil, patientName: nil, incidentId: incident.id, incidentName: incident.name, incidentDisplayId: incident.incidentId),
                                    style: .push()
                                )
                            } label: {
                                Label("View Records", systemImage: "list.bullet")
                            }

                          //  if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                                // Report option
                                Button {
                                    Task {
                                        await downloadAndShowReport(for: incident)
                                    }
                                } label: {
                                    Label("Download Report", systemImage: "arrow.down.circle.fill")
                                }
                        //    }
                            // Create Record option - only show for Active incidents
                            if incident.status == "Active" {
                                Button {
                                    // Check drainage limit on long press
                                    let drainageLimitCheck = featureLimitService.canCreateDrainage()
                                    if !drainageLimitCheck.allowed {
                                        drainageLimitAlertMessage = drainageLimitCheck.message ?? "Drainage limit reached"
                                        showingDrainageLimitAlert = true
                                    } else {
                                        // If limit allows, proceed with navigation
                                        NavigationManager.shared.navigate(
                                            to: .addDrainageFromIncident(incident: incident),
                                            style: .presentSheet()
                                        )
                                    }
                                } label: {
                                    Label("Create Record", systemImage: "plus.circle")
                                }
                            }

                            if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                                // Add Linked Incident option - only show for Closed incidents
                                if incident.status == "Closed" {
                                    Button {
                                        let incidentLimitCheck = featureLimitService.canCreateIncident()
                                        if !incidentLimitCheck.allowed {
                                            limitAlertMessage = incidentLimitCheck.message ?? "Incident limit reached"
                                            showingIncidentLimitAlert = true
                                        } else {
                                            NavigationManager.shared.navigate(
                                                to: .addIncident(linkedFromIncident: incident),
                                                style: .presentSheet()
                                            )
                                        }

                                    } label: {
                                        Label("Add Linked Incident", systemImage: "link.badge.plus")
                                    }
                                }
                            }
                            // Barcode option
                            if let incidentId = incident.incidentId, !incidentId.isEmpty {
                                Button {
                                    selectedIncidentForBarcode = incident
                                } label: {
                                    Label("Incident ID Code", systemImage: "barcode")
                                }
                            }

                            // Close Incident option - only show for Active incidents
                            if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                                if incident.status == "Active" {
                                    Button {
                                        incidentToClose = incident
                                        showingCloseAlert = true
                                    } label: {
                                        Label("Close this incident", systemImage: "xmark.circle")
                                    }
                                }
                            }

                            // Delete option (only for the owner and Active incidents)
                            if TokenManager.shared.loadCurrentUser()?.role != "Patient" && incident.status == "Active" {
                                if incident.userId == TokenManager.shared.getUserId() {
                                    Button(role: .destructive) {
                                        incidentToDelete = incident
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete Incident", systemImage: "trash")
                                    }
                                }
                            }
                        }
                }
            }
            .padding()
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 500000000) // Add a small delay
            await incidentStore.refreshIncidents(patientSlug: patientSlug)
        }
    }

    // MARK: - Shimmer List

    private var incidentShimmerList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0 ..< 5) { _ in
                    IncidentShimmerRow()
                }
            }
            .padding()
        }
        .disabled(true)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            //  Image(systemName: "note.text.badge.plus")
            Image("incident_icon_high") // ✅ your custom image
                .renderingMode(.template)
                .resizable()
                .frame(width: 80, height: 80)
                .font(.system(size: 80))
                .foregroundColor(Color.dynamicAccent.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Incidents Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                    Text(searchText.isEmpty ? "Start by creating your first incident record" : "No incidents match your search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                Button {
                    let incidentLimitCheck = featureLimitService.canCreateIncident()
                    if !incidentLimitCheck.allowed {
                        limitAlertMessage = incidentLimitCheck.message ?? "Incident limit reached"
                        showingIncidentLimitAlert = true
                    } else {
                        NavigationManager.shared.navigate(to: .addIncident(), style: .presentSheet())
                    }
                    
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Incident")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let patientName = patientName {
            return "\(patientName)'s Incidents"
        } else {
            return "Incidents"
        }
    }

    // MARK: - Report Download

    private func downloadAndShowReport(for incident: Incident) async {
        do {
            let url = try await incidentStore.downloadIncidentReport(incidentId: incident.id)
            await MainActor.run {
                self.pdfURL = url
                self.selectedIncidentForReport = incident
            }
        } catch {
            await MainActor.run {
                incidentStore.errorMessage = "Failed to download report: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Incident Row View

struct IncidentRowView: View {
    let incident: Incident
    let onTap: () -> Void

    private var shouldShowPatientName: Bool {
        TokenManager.shared.loadCurrentUser()?.role != "Patient"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(incident.name)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            if let incidentId = incident.incidentId {
                                Text(incidentId)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.dynamicAccent)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack {
                            if shouldShowPatientName, !incident.patientName.isEmpty {
                                // Priority color dot (only show if priority exists and is not none)
                                if let patientData = incident.patientData,
                                   let priority = patientData.metadata.priority,
                                   priority != .none {
                                    Circle()
                                        .fill(priority.swiftUIColor)
                                        .frame(width: 6, height: 6)
                                }

                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(incident.patientName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()

                            Image(systemName: "figure.stand")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(incident.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        HStack {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(incident.drainageType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Text(incident.createdAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            if let count = incident.drainageCount {
                                Text("Drainage (\(count))")
                                    .font(.caption)
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Status indicator
                            Text(incident.status)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(incident.status == "Active" ? Color.green : Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

struct IncidentShimmerRow: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon shimmer
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .shimmerEffect()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        IncidentShimmerBox(width: 150, height: 20)
                        Spacer()
                        IncidentShimmerBox(width: 80, height: 16)
                    }

                    HStack {
                        IncidentShimmerBox(width: 100, height: 16)
                        Spacer()
                        IncidentShimmerBox(width: 60, height: 16)
                    }

                    HStack {
                        IncidentShimmerBox(width: 120, height: 14)
                        Spacer()
                        IncidentShimmerBox(width: 70, height: 14)
                    }
                }

                IncidentShimmerBox(width: 12, height: 12)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct IncidentShimmerBox: View {
    let width: CGFloat
    let height: CGFloat
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmerEffect()
    }
}

extension View {
    func shimmerEffect() -> some View {
        ShimmerEffectView(content: self)
    }
}

struct ShimmerEffectView<Content: View>: View {
    let content: Content
    @State private var isAnimating = false

    var body: some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.clear, .white.opacity(0.6), .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .offset(x: isAnimating ? 300 : -300)
                    .animation(
                        .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .onAppear {
                        isAnimating = true
                    }
            )
            .clipped()
    }
}

struct IncidentNoSearchResultsView: View {
    let searchText: String
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(Color.dynamicAccent.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("No incidents found for '\(searchText)'")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Text("Try different keywords or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    onClearSearch()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear Search")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.dynamicAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.dynamicAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Incident Barcode Display View

struct IncidentBarcodeDisplayView: View {
    let incidentId: String
    @Environment(\.dismiss) private var dismiss
    @State private var isBarcodeGenerated = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Incident ID Barcode")
                    .font(.title2)
                    .fontWeight(.semibold)

                if !incidentId.isEmpty {
                    VStack(spacing: 16) {
                        BarcodeView(data: incidentId)
                            .frame(height: 120)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onAppear {
                                isBarcodeGenerated = true
                            }

                        Text(incidentId)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)

                        Text("Scan this barcode to access incident details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No incident ID available")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("This incident doesn't have a barcode ID")
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
            print("IncidentBarcodeDisplayView appeared with incidentId: \(incidentId)")
        }
    }
}

// MARK: - Incident Sort Sheet

struct IncidentSortSheet: View {
    @Binding var selectedSortOption: IncidentSortOption
    @Binding var isPresented: Bool
    let onSortChanged: (IncidentSortOption) -> Void

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
                    ForEach(IncidentSortOption.allCases) { option in
                        Button(action: {
                            selectedSortOption = option
                            onSortChanged(option)
                            isPresented = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.dynamicAccent)
                                    .padding(.vertical, 14)
                                Spacer()
                                if option == selectedSortOption {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.dynamicAccent)
                                }
                            }
                            .padding(.horizontal)
                        }
                        Divider()
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

// MARK: - Custom PDF Overlay

struct CustomPDFOverlay: View {
    let url: URL
    let incidentName: String
    let onDismiss: () -> Void

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pdfData: Data?

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // PDF content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .font(.headline)

                    Spacer()

                    Text("\(incidentName) Report")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Menu {
                        Button {
                            sharePDF()
                        } label: {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.9))

                // PDF content area
                ZStack {
                    if isLoading {
                        VStack {
                            ProgressView("Loading PDF...")
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Downloading report for \(incidentName)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.top, 8)
                        }
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)

                            Text("Error Loading PDF")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)

                            Button("Try Again") {
                                loadPDF()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if let pdfData = pdfData {
                        PDFKitView(data: pdfData)
                            .background(Color.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
        .onAppear {
            loadPDF()
        }
    }

    private func loadPDF() {
        isLoading = true
        errorMessage = nil
        pdfData = nil

        // Download PDF data
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Failed to load PDF: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode != 200 {
                    errorMessage = "Server error: \(httpResponse.statusCode)"
                } else if let data = data, !data.isEmpty {
                    pdfData = data
                } else {
                    errorMessage = "No data received"
                }
            }
        }.resume()
    }

    private func sharePDF() {
        if let pdfData = pdfData {
            let activityVC = UIActivityViewController(
                activityItems: [pdfData],
                applicationActivities: nil
            )

            // Present from the current view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                // Find the topmost presented view controller
                var topController = rootViewController
                while let presentedController = topController.presentedViewController {
                    topController = presentedController
                }

                // Configure for iPad
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }

                topController.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - PDFKit View

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// MARK: - Incident Filter Sheet

struct IncidentFilterSheet: View {
    @Binding var filter: IncidentFilter
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var tempFilter: IncidentFilter
    @State private var showDrainageTypeDropdown = false
    @State private var showStatusDropdown = false
    @State private var showPatientDropdown = false
    @StateObject private var patientViewModel = PatientSelectionViewModel()

    init(filter: Binding<IncidentFilter>, onApply: @escaping () -> Void) {
        _filter = filter
        self.onApply = onApply
        _tempFilter = State(initialValue: filter.wrappedValue)
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

                                    Text("Show only incidents I created")
                                        .foregroundColor(.primary)
                                        .padding(.leading, 8)
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

                // Drainage Type Filter
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

                // Status Filter
                Section(header: Text("Status")) {
                    Button(action: {
                        showStatusDropdown.toggle()
                    }) {
                        HStack {
                            Text(tempFilter.status ?? "Select Status")
                                .foregroundColor(tempFilter.status == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: showStatusDropdown ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }

                    if showStatusDropdown {
                        ForEach(["Active", "Closed"], id: \.self) { status in
                            HStack {
                                Button(action: {
                                    if tempFilter.status == status {
                                        tempFilter.status = nil
                                    } else {
                                        tempFilter.status = status
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: tempFilter.status == status ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(tempFilter.status == status ? .accentColor : .gray)
                                        Text(status)
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
            .navigationTitle("Filter Incidents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        tempFilter.clearAll()
                        filter = tempFilter
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filter = tempFilter
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Incident No Filter Results View

struct IncidentNoFilterResultsView: View {
    let currentFilter: IncidentFilter
    let onClearFilters: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicAccent)

            Text("No Matching Incidents")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No incidents match your current filter criteria")
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
                    if !currentFilter.drainageType.isEmpty {
                        Text("• Drainage Types: \(currentFilter.drainageType.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let status = currentFilter.status {
                        Text("• Status: \(status)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let patientId = currentFilter.patientId {
                        Text("• Patient ID: \(patientId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if currentFilter.isSelfCreated {
                        Text("• Show only incidents I created")
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

// MARK: - Preview

// MARK: - Incident Card View

struct IncidentCardView: View {
    let incident: Incident
    let showingBarcodes: Bool
    @State private var selectedIncidentForBarcode: Incident?

    private var shouldShowPatientName: Bool {
        TokenManager.shared.loadCurrentUser()?.role != "Patient"
    }

    private var statusColor: Color {
        switch incident.status {
        case "Active":
            return .green
        case "Closed":
            return .red
        default:
            return .gray
        }
    }
    let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Spacer()
                    if let incidentId = incident.incidentId, !incidentId.isEmpty {
                        Text("\(incidentId)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                // Show barcode if toggle is on and incident has barcode
                if showingBarcodes,
                   let incidentId = incident.incidentId,
                   !incidentId.isEmpty {
                    Button(action: {
                        selectedIncidentForBarcode = incident
                    }) {
                        VStack(spacing: 8) {
                            BarcodeView(data: incidentId)
                                .frame(height: 60)
                                .padding(.horizontal)
                        }
                        .background(Color(.systemGray6).opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
               

                // Main content
                VStack(alignment: .leading, spacing: 8) {
                    // Incident name and drainage type
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(incident.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    // Header with patient info and priority
                    if shouldShowPatientName, !incident.patientName.isEmpty {
                        HStack {
                            // Priority color dot
                            if let patientData = incident.patientData,
                               let priority = patientData.metadata.priority,
                               priority != .none {
                                Circle()
                                    .fill(priority.swiftUIColor)
                                    .frame(width: 8, height: 8)
                            }

                            Text(incident.patientName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                    Text(incident.location)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text(incident.drainageType)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.gray.opacity(0.2))
                        .clipShape(Capsule())

                    Button(action: {
                        NavigationManager.shared.navigate(
                            to: .drainageListView(patientSlug: nil, patientName: nil, incidentId: incident.id, incidentName: incident.name, incidentDisplayId: incident.incidentId),
                            style: .push()
                        )
                    }) {
                        if let count = incident.drainageCount {
                            HStack(spacing: 6) {
                                Image("drainage_icon")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                
                                Text("Drainage (\(count))")
                                    .font(.caption2)
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                   
                    // Footer with time and status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            // assuming startDate and endDate are always available
                            Text("\(formatter.string(from: incident.startDate)) to \(formatter.string(from: incident.endDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding()

            Divider()
                .offset(y: 11.5)
            // Bottom status section
            HStack {
                Text(incident.status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                // Status color indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(statusColor.opacity(0.1))
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(item: $selectedIncidentForBarcode) { incident in
            IncidentBarcodeDisplayView(incidentId: incident.incidentId ?? "")
        }
    }
}

struct IncidentListView_Previews: PreviewProvider {
    static var previews: some View {
        IncidentListView()
    }
}
