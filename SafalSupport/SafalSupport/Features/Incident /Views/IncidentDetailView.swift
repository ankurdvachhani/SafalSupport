import SwiftUI
import CoreImage.CIFilterBuiltins
import PDFKit



struct IncidentDetailView: View {
    @EnvironmentObject private var incidentStore: IncidentStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var incident: Incident
    @State private var selectedIncidentForBarcode: Incident?
    @State private var selectedIncidentForReport: Incident?
    @State private var showingPDFViewer = false
    @State private var pdfURL: URL?
    @State private var incidentToClose: Incident?
    @State private var showingCloseAlert = false
    
    init(incident: Incident) {
        _incident = State(initialValue: incident)
    }
    
    init(incidentId: String) {
        // Create a placeholder incident with the ID
        let placeholderIncident = Incident(
            id: incidentId,
            userId: "",
            patientId: "",
            patientName: "",
            patientData: nil, // Placeholder doesn't include patient data
            name: "",
            drainageType: "",
            location: "",
            description: nil,
            startDate: Date(),
            endDate: Date(),
            catheterInsertionDate: nil,
            access: [],
            schedule: nil,
            notification: nil,
            fieldConfig: nil,
            createdAt: Date(),
            updatedAt: Date(),
            incidentId: nil,
            drainageCount: nil,
            status: "",
            linked: nil
        )
        _incident = State(initialValue: placeholderIncident)
    }
    
    private func fetchIncidentDetails() async {
        isLoading = true
        do {
            incident = try await incidentStore.fetchIncidentDetail(id: incident.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Barcode Section
                    barcodeSection
                    
                    // Header Section
                    headerSection
                    
                    // Basic Information
                    basicInfoSection
                    
                    // Dates Section
                    datesSection
                    
//                    // Access Section
//                    accessSection
                    
                    // Description Section
                    if let description = incident.description, !description.isEmpty {
                        descriptionSection
                    }
                    
                    // Schedule Section
                    if let schedules = incident.schedule, !schedules.isEmpty {
                        scheduleSection
                    }
                    
                    // Notification Section
                    if let notifications = incident.notification, !notifications.isEmpty {
                        notificationSection
                    }
                    
                    // Field Configuration Section
                    if let fieldConfigs = incident.fieldConfig, !fieldConfigs.isEmpty {
                        fieldConfigSection
                    }
                    
                    // Linked Incidents Section
                    if let linkedIncidents = incident.linked, !linkedIncidents.isEmpty {
                        linkedIncidentsSection
                    }
                    
                    // Metadata Section
                    metadataSection
                    
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Incident Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // View Records option
                        Button {
                            NavigationManager.shared.navigate(
                                to: .drainageListView(patientSlug: nil, patientName: nil, incidentId: incident.id),
                                style: .push()
                            )
                        } label: {
                            Label("View Records", systemImage: "list.bullet")
                        }

                        // Report option
                        if TokenManager.shared.loadCurrentUser()?.role != "Patient"{
                            Button {
                                Task {
                                    await downloadAndShowReport(for: incident)
                                }
                            } label: {
                                Label("Download Report", systemImage: "arrow.down.circle.fill")
                            }
                        }

                        // Create Record option - only show for Active incidents
                        if incident.status == "Active" {
                            Button {
                                NavigationManager.shared.navigate(
                                    to: .addDrainageFromIncident(incident: incident),
                                    style: .presentSheet()
                                )
                            } label: {
                                Label("Create Record", systemImage: "plus.circle")
                            }
                        }
                        
                        // Add Linked Incident option - only show for Closed incidents
                        if TokenManager.shared.loadCurrentUser()?.role != "Patient"{
                            if incident.status == "Closed" {
                                Button {
                                    NavigationManager.shared.navigate(
                                        to: .addIncident(linkedFromIncident: incident),
                                        style: .presentSheet()
                                    )
                                } label: {
                                    Label("Add Linked Incident", systemImage: "link.badge.plus")
                                }
                            }
                        }
                        // Close Incident option - only show for Active incidents
                        if TokenManager.shared.loadCurrentUser()?.role != "Patient"{
                            if incident.status == "Active" {
                                Button {
                                    incidentToClose = incident
                                    showingCloseAlert = true
                                } label: {
                                    Label("Close this incident", systemImage: "xmark.circle")
                                }
                            }
                        }
                        // Edit option - only for the owner and Active incidents
                        if TokenManager.shared.loadCurrentUser()?.role != "Patient" && incident.status == "Active" {
                            if incident.userId == TokenManager.shared.getUserId() {
                                Button {
                                    showingEditView = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                        }
                        
                        // Delete option (only for the owner and Active incidents)
                        if TokenManager.shared.loadCurrentUser()?.role != "Patient" && incident.status == "Active" {
                            if incident.userId == TokenManager.shared.getUserId() {
                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete Incident", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Incident", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteIncident()
                    }
                }
                Button("Cancel", role: .cancel) {}
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
            .sheet(isPresented: $showingEditView) {
                AddIncidentView(incidentToEdit: incident)
                    .environmentObject(incidentStore)
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
            .onAppear {
                // Add notification observer
                NotificationCenter.default.addObserver(
                    forName: .updateIncidentRecord,
                    object: nil,
                    queue: .main
                ) { _ in
                    Task {
                        await fetchIncidentDetails()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                    }
                }
            )
            .task {
                await fetchIncidentDetails()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                // Title + Record button in same row
                HStack {
                    Text(incident.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
//                    Button(action: {
//                        NavigationManager.shared.navigate(
//                            to: .drainageListView(patientSlug: nil, patientName: nil, incidentId: incident.id),
//                            style: .push()
//                        )
//                    }) {
//                        Text("Show Drainages")
//                            .font(.subheadline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(Color.blue)
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 6)
//                            .underline(true, color: Color.blue)
//                           
//                    }
                    if let incidentId = incident.incidentId {
                        Text(incidentId)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.dynamicAccent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.teal.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Basic Information Section
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Custom patient row with priority dot
                HStack {
                    // Priority color dot (only show if priority exists and is not none)
                    if let patientData = incident.patientData,
                       let priority = patientData.metadata.priority,
                       priority != .none {
                        Circle()
                            .fill(priority.swiftUIColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Image(systemName: "person.fill")
                        .foregroundColor(Color.dynamicAccent)
                        .font(.caption)
                        .frame(width: 20)
                    
                    Text("Patient")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(incident.patientName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 4)
                
                InfoRow(title: "Location", value: incident.location, icon: "figure.stand")
                InfoRow(title: "Drainage Type", value: incident.drainageType, icon: "drop.fill")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Dates Section
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                DateInfoRow(title: "Start Date", date: incident.startDate, icon: "play.fill", color: .green)
                DateInfoRow(title: "End Date", date: incident.endDate, icon: "stop.fill", color: .red)
                
                if let catheterInsertionDate = incident.catheterInsertionDate {
                    DateInfoRow(title: "Catheter Insertion Date", date: catheterInsertionDate, icon: "cross.fill", color: .orange)
                }
                
                // Duration
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 20)
                    
                    Text("Duration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(durationText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Access Section
    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Access")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Color.dynamicAccent)
                        .font(.caption)
                        .frame(width: 20)
                    
                    Text("Assigned Personnel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(incident.access.count) person(s)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.teal)
                        .clipShape(Capsule())
                }
                
                if incident.access.isEmpty {
                    Text("No personnel assigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("Access IDs: \(incident.access.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Description")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(incident.description ?? "")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(incident.schedule ?? [], id: \.id) { schedule in
                        SimpleScheduleCard(schedule: schedule)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Notification Section
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(incident.notification ?? [], id: \.id) { notification in
                        NotificationDetailCard(notification: notification)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Field Configuration Section
    private var fieldConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Field Configuration")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(incident.fieldConfig ?? [], id: \.id) { fieldConfig in
                        FieldConfigDetailCard(fieldConfig: fieldConfig)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Linked Incidents Section
    private var linkedIncidentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack{
                Text("\(incident.linked?.count ?? 0) Linked Incidents")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
           
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(incident.linked ?? [], id: \.id) { linkedIncident in
                        LinkedIncidentCard(linkedIncident: linkedIncident)
                            .frame(width: 320)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Record Information")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                DateInfoRow(title: "Created", date: incident.createdAt, icon: "plus.circle.fill", color: .green)
                DateInfoRow(title: "Last Updated", date: incident.updatedAt, icon: "pencil.circle.fill", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    

    
    // MARK: - Helper Properties
    private var durationText: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: incident.startDate, to: incident.endDate)
        
        var parts: [String] = []
        
        if let days = components.day, days > 0 {
            parts.append("\(days) day\(days == 1 ? "" : "s")")
        }
        
        if let hours = components.hour, hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        
        return parts.isEmpty ? "Less than 1 hour" : parts.joined(separator: ", ")
    }
    
    // MARK: - Methods
    private func deleteIncident() async {
        await incidentStore.deleteIncident(incident)
        if incidentStore.errorMessage == nil {
            dismiss()
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
    
    // MARK: - Barcode Section
    private var barcodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Incident ID Barcode")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let incidentId = incident.incidentId, !incidentId.isEmpty {
                VStack(spacing: 12) {
                    BarcodeView(data: incidentId)
                        .frame(height: 80)
                    
                    Text(incidentId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                Text("No incident ID available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Supporting Views
struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.dynamicAccent)
                .font(.caption)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct DateInfoRow: View {
    let title: String
    let date: Date
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Schedule Detail Card
struct ScheduleDetailCard: View {
    let schedule: Schedule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: schedule.recurring ? "repeat.circle.fill" : "clock.circle.fill")
                    .foregroundColor(schedule.recurring ? .blue : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.recurring ? "Recurring Schedule" : "One-time Schedule")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if schedule.recurring {
                        Text("\(schedule.interval.capitalized) • \(schedule.duration) times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(schedule.dateTimeArray.count) specific time(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Time Range
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Start Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(schedule.startDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(schedule.startDate, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("End Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(schedule.endDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(schedule.endDate, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Specific Times (for one-time schedules)
            if !schedule.recurring && !schedule.dateTimeArray.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Specific Times")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(schedule.dateTimeArray, id: \.self) { dateTime in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .frame(width: 16)
                            
                            Text(dateTime, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(dateTime, style: .time)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Notification Buffer
            Divider()
            
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.purple)
                    .font(.caption)
                    .frame(width: 16)
                
                Text("Notification Buffer")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(schedule.notificationBuffer) minutes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Notification Detail Card
struct NotificationDetailCard: View {
    let notification: NotificationRule
    
    private var notificationColor: Color {
        switch notification.notificationLevel {
        case "HIGH":
            return .red
        case "MID":
            return .orange
        case "LOW":
            return .blue
        default:
            return .gray
        }
    }
    
    private var notificationIcon: String {
        switch notification.fieldKey {
        case "amount":
            return "drop.fill"
        case "fluidSalineFlushAmount":
            return "drop.degreesign.fill"
        case "color":
            return "paintpalette.fill"
        case "painLevel":
            return "heart.fill"
        case "temperature":
            return "thermometer"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: notificationIcon)
                    .foregroundColor(notificationColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatFieldKey(notification.fieldKey ?? ""))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(notification.notificationLevel) Priority")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(notificationColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            
            Divider()
            
            // Condition and Value
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "function")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Condition")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatCondition(notification.condition ?? ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.green)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Value")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(notification.value.displayText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatFieldKey(_ key: String) -> String {
        switch key {
        case "amount":
            return "Amount"
        case "fluidSalineFlushAmount":
            return "Fluid Saline Flush Amount"
        case "color":
            return "Color"
        case "painLevel":
            return "Pain Level"
        case "temperature":
            return "Temperature"
        default:
            return key.capitalized
        }
    }
    
    private func formatCondition(_ condition: String) -> String {
        switch condition {
        case "gt":
            return "Greater Than (>)"
        case "gte":
            return "Greater Than or Equal (≥)"
        case "lt":
            return "Less Than (<)"
        case "lte":
            return "Less Than or Equal (≤)"
        case "includes":
            return "Includes"
        case "eq":
            return "Equals (=)"
        default:
            return condition.uppercased()
        }
    }
}

// MARK: - Field Config Detail Card
struct FieldConfigDetailCard: View {
    let fieldConfig: FieldConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatFieldKey(fieldConfig.fieldKey))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(getValueTypeString(fieldConfig.value))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Configuration
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.purple)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Field Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(fieldConfig.fieldKey)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Required")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(fieldConfig.isRequired ? "Yes" : "No")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Hidden")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(fieldConfig.isHidden ? "Yes" : "No")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Can Changeable ?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(fieldConfig.isDefault ? "No" : "Yes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.brown)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Value")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(fieldConfig.value.displayText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatFieldKey(_ key: String) -> String {
        switch key {
        case "amount": return "Amount"
        case "amountUnit": return "Amount Unit"
        case "location": return "Location"
        case "fluidType": return "Fluid Type"
        case "color": return "Color"
        case "colorOther": return "Color Other"
        case "consistency": return "Consistency"
        case "odor": return "Odor"
        case "drainageType": return "Drainage Type"
        case "isFluidSalineFlush": return "Fluid Saline Flush"
        case "fluidSalineFlushAmount": return "Fluid Saline Flush Amount"
        case "fluidSalineFlushAmountUnit": return "Fluid Saline Flush Amount Unit"
        case "comments": return "Comments"
        case "odorPresent": return "Odor Present"
        case "painLevel": return "Pain Level"
        case "temperature": return "Temperature"
        case "doctorNotified": return "Doctor Notified"
        case "beforeImage": return "Before Image"
        case "afterImage": return "After Image"
        case "fluidCupImage": return "Fluid Cup Image"
        default: return key.capitalized
        }
    }
    
    private func getValueTypeString(_ value: FieldConfigValue) -> String {
        switch value {
        case .string: return "String"
        case .int: return "Integer"
        case .double: return "Double"
        case .bool: return "Boolean"
        case .stringArray: return "String Array"
        }
    }
}

// MARK: - Simple Schedule Card
struct SimpleScheduleCard: View {
    let schedule: Schedule
    
    private var durationText: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: schedule.startDate, to: schedule.endDate)
        
        var parts: [String] = []
        
        if let days = components.day, days > 0 {
            parts.append("\(days) day\(days == 1 ? "" : "s")")
        }
        
        if let hours = components.hour, hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        
        return parts.isEmpty ? "Less than 1 hour" : parts.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with schedule type
            HStack {
                Image(systemName: schedule.recurring ? "repeat.circle.fill" : "clock.circle.fill")
                    .foregroundColor(schedule.recurring ? .blue : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    if schedule.recurring {
                        Text("\(schedule.interval.capitalized) • \(schedule.duration) times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Date Range
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Start Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(schedule.startDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("End Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(schedule.endDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            
            // Specific Dates from dateTimeArray
            if !schedule.dateTimeArray.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduled Times")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(Array(schedule.dateTimeArray.enumerated()), id: \.offset) { index, dateTime in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                         
                            // Show time if it's not the same as start/end time
                            let startTime = Calendar.current.component(.hour, from: schedule.startDate) * 60 + Calendar.current.component(.minute, from: schedule.startDate)
                            let endTime = Calendar.current.component(.hour, from: schedule.endDate) * 60 + Calendar.current.component(.minute, from: schedule.endDate)
                            let currentTime = Calendar.current.component(.hour, from: dateTime) * 60 + Calendar.current.component(.minute, from: dateTime)
                            
                            if currentTime != startTime && currentTime != endTime {
                                Text(dateTime, style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("")
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}




// MARK: - Linked Incident Card
struct LinkedIncidentCard: View {
    let linkedIncident: LinkedIncident
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with incident name and status
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(linkedIncident.incident?.name ?? "Unknown Incident")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let incidentId = linkedIncident.incident?.incidentId {
                        Text(incidentId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                if let status = linkedIncident.incident?.status {
                    Text(status)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status == "Active" ? Color.green : Color.red)
                        .clipShape(Capsule())
                }
            }
            
            Divider()
            
            // Patient Information
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Patient")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(linkedIncident.incident?.patientName ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "person.badge.key")
                        .foregroundColor(.purple)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Patient ID")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(linkedIncident.incident?.patientId ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Procedure Information
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.teal)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Drainage Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(linkedIncident.incident?.drainageType ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "figure.stand")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Location")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(linkedIncident.incident?.location ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description if available
            if let description = linkedIncident.incident?.description, !description.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.brown)
                            .font(.caption)
                            .frame(width: 16)
                        
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Divider()
            
            // Date Information
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Date Range")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        if let startDate = linkedIncident.incident?.startDate {
                            Text(startDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let endDate = linkedIncident.incident?.endDate {
                            Text(endDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "cross.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Catheter Insertion")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let catheterDate = linkedIncident.incident?.catheterInsertionDate {
                        Text(catheterDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not scheduled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Linked Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(linkedIncident.linkedDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Linked count if available
            if let linked = linkedIncident.incident?.linked, !linked.isEmpty {
                Divider()
                
                HStack {
                    Image(systemName: "link.badge.plus")
                        .foregroundColor(.purple)
                        .font(.caption)
                        .frame(width: 16)
                    
                    Text("Linked Incidents")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(linked.count) incident(s)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview
struct IncidentDetailView_Previews: PreviewProvider {
    static var previews: some View {
        IncidentDetailView(
            incident: Incident(
                id: "1",
                patientId: "patient1",
                patientName: "John Doe",
                patientData: nil, // Preview data doesn't include patient data
                name: "Test Incident",
                drainageType: "Jackson-Pratt (JP)",
                location: "Chest",
                description: "This is a test incident description that spans multiple lines to show how the text wraps in the detail view.",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                access: ["nurse1", "nurse2"],
                schedule: [
                    Schedule(
                        startDate: Date(),
                        endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                        interval: "day",
                        duration: 7,
                        recurring: true,
                        dateTimeArray: [],
                        notificationBuffer: 30
                    )
                ],
                notification: [
                    NotificationRule(
                        fieldKey: "amount",
                        condition: "gt",
                        value: .string("100"),
                        notificationLevel: "HIGH"
                    ),
                    NotificationRule(
                        fieldKey: "painLevel",
                        condition: "gte",
                        value: .string("7"),
                        notificationLevel: "MID"
                    )
                ],
                fieldConfig: [
                    FieldConfig(
                        fieldKey: "amount",
                        value: .int(100),
                        isDefault: true,
                        isHidden: false,
                        isRequired: true,
                        id: "fc1"
                    ),
                    FieldConfig(
                        fieldKey: "location",
                        value: .string("Chest"),
                        isDefault: true,
                        isHidden: false,
                        isRequired: true,
                        id: "fc2"
                    ),
                    FieldConfig(
                        fieldKey: "painLevel",
                        value: .int(5),
                        isDefault: false,
                        isHidden: false,
                        isRequired: false,
                        id: "fc3"
                    )
                ]
            )
        )
        .environmentObject(IncidentStore())
    }
}

