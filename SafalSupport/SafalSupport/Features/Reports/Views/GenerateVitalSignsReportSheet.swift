import SwiftUI

struct GenerateVitalSignsReportSheet: View {
    @Binding var isPresented: Bool
    let onReportGenerated: () -> Void
    
    @StateObject private var patientViewModel = PatientSelectionViewModel()
    @StateObject private var incidentViewModel = IncidentStore()
    @StateObject private var vitalSignsStore = VitalSignsReportStore()
    
    @State private var selectedPatient: PatientData?
    @State private var selectedIncident: Incident?
    @State private var selectedIncidentId: String = "All"
    @State private var isGenerating = false
    @State private var showingPatientList = false
    @State private var showingIncidentList = false
    @State private var selectedReportForPDF: VitalSignsReport?
    @State private var pdfURL: URL?
    
    let currentUser = TokenManager.shared.loadCurrentUser()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
             //   headerSection
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Title and Description
                        titleSection
                        
                      
                            // Patient Selection
                            patientSelectionSection
                        // Incident Selection
                        incidentSelectionSection
                        
                        // Generate Button
                        generateButton
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingPatientList) {
            PatientSelectionSheet(
                selectedPatient: $selectedPatient,
                isPresented: $showingPatientList
            )
        }
        .sheet(isPresented: $showingIncidentList) {
            IncidentSelectionSheet(
                selectedIncident: $selectedIncident,
                selectedIncidentId: $selectedIncidentId,
                isPresented: $showingIncidentList
            )
        }
        .overlay {
            if let report = selectedReportForPDF, let url = pdfURL {
                incidentCustomPDFOverlay(url: url, incidentName: report.title) {
                    selectedReportForPDF = nil
                    pdfURL = nil
                    // Close the sheet and refresh the report list
                    isPresented = false
                    onReportGenerated()
                }
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Are you sure you want to generate the report?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Once generated, you can re-download it from the Report → Vital Signs Report.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Patient Selection Section
    
    private var patientSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                Text("Please Select Patient and their incident")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
             
            }else{
                Text("Please Select their incident")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
                HStack(spacing: 12) {
                    if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                        // Patient Dropdown
                        Button {
                            if currentUser?.role != "Patient" {
                                showingPatientList = true
                            }
                        } label: {
                            HStack {
                                Text(selectedPatient?.fullName ?? "Select Patient")
                                    .foregroundColor(selectedPatient != nil ? .primary : .secondary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(currentUser?.role == "Patient")
                    }
                // Incident Dropdown
                Button {
                    showingIncidentList = true
                } label: {
                    HStack {
                        Text(selectedIncidentId == "All" ? "All" : selectedIncident?.name ?? "Select Incident")
                            .foregroundColor(selectedIncidentId != "All" ? .primary : .secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - Incident Selection Section
    
    private var incidentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedPatient != nil || currentUser?.role == "Patient" {
                Text("Selected Incident: \(selectedIncidentId == "All" ? "All Incidents" : selectedIncident?.name ?? "All Incidents")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button {
            Task {
                await generateReport()
            }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "doc.text.badge.plus")
                        .font(.title2)
                }
                
                Text(isGenerating ? "Generating Report..." : "Generate Report")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isGenerating ? Color.gray : Color.dynamicAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isGenerating)
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() {
        // Set default patient if current user is a patient
        if currentUser?.role == "Patient" {
            // For patient users, we don't show patient selection
            // They can only generate reports for themselves
        }
        
        // Set default incident to "All"
        selectedIncidentId = "All"
    }
    
    private func generateReport() async {
        isGenerating = true
        
        do {
            let userSlug = currentUser?.role == "Patient" ? currentUser?.userSlug : selectedPatient?.userSlug
            let incidentId = selectedIncidentId == "All" ? nil : selectedIncident?.id
            
            let response = try await vitalSignsStore.generateVitalSignsReport(
                userSlug: userSlug,
                incidentId: incidentId
            )
            
            if response.success {
                await MainActor.run {
                    // Create a temporary VitalSignsReport object for display
                    let tempReport = VitalSignsReport(
                        id: UUID().uuidString,
                        userId: currentUser?.id ?? "",
                        title: "Vital Signs Report - \(Date().formatted(date: .abbreviated, time: .shortened))",
                        reportId: "Generated",
                        organizationId: currentUser?.id ?? "",
                        url: response.data.location,
                        type: "vital-signs",
                        createdAt: Date(),
                        updatedAt: Date(),
                        urlSign: response.data.locationSign
                    )
                    
                    // Show the PDF overlay
                    selectedReportForPDF = tempReport
                    pdfURL = URL(string: response.data.locationSign ?? response.data.location)
                }
            } else {
                await MainActor.run {
                    vitalSignsStore.errorMessage = response.message
                }
            }
        } catch {
            await MainActor.run {
                vitalSignsStore.errorMessage = "Failed to generate report: \(error.localizedDescription)"
            }
        }
        
        isGenerating = false
    }
}

// MARK: - Patient Selection Sheet

struct PatientSelectionSheet: View {
    @Binding var selectedPatient: PatientData?
    @Binding var isPresented: Bool
    
    @StateObject private var patientViewModel = PatientSelectionViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search patients...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            patientViewModel.searchPatients()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                
                // Patient List
                List {
                    ForEach(filteredPatients) { patient in
                        Button {
                            selectedPatient = patient
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(patient.fullName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(patient.email ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPatient?.id == patient.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.dynamicAccent)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await patientViewModel.fetchPatients()
            }
        }
    }
    
    private var filteredPatients: [PatientData] {
        if searchText.isEmpty {
            return patientViewModel.patients
        } else {
            return patientViewModel.patients.filter { patient in
                patient.fullName.localizedCaseInsensitiveContains(searchText) ||
                (patient.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

// MARK: - Incident Selection Sheet

struct IncidentSelectionSheet: View {
    @Binding var selectedIncident: Incident?
    @Binding var selectedIncidentId: String
    @Binding var isPresented: Bool
    
    @StateObject private var incidentViewModel = IncidentStore()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search incidents...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            // Implement search if needed
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                
                // Incident List
                List {
                    // "All" option
                    Button {
                        selectedIncidentId = "All"
                        selectedIncident = nil
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("All")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("All incidents")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedIncidentId == "All" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.dynamicAccent)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ForEach(filteredIncidents) { incident in
                        Button {
                            selectedIncident = incident
                            selectedIncidentId = incident.id
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(incident.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(incident.patientName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedIncident?.id == incident.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.dynamicAccent)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Incident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await incidentViewModel.fetchIncidents()
            }
        }
    }
    
    private var filteredIncidents: [Incident] {
        if searchText.isEmpty {
            return incidentViewModel.incidents
        } else {
            return incidentViewModel.incidents.filter { incident in
                incident.name.localizedCaseInsensitiveContains(searchText) ||
                incident.patientName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

#Preview {
    GenerateVitalSignsReportSheet(
        isPresented: .constant(true),
        onReportGenerated: {}
    )
}
