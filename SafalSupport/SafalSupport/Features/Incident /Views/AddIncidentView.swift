import SwiftUI

struct AddIncidentView: View {
    let incidentToEdit: Incident?
    let linkedFromIncident: Incident? // For linked incidents

    @EnvironmentObject private var incidentStore: IncidentStore
    @StateObject private var patientViewModel = PatientSelectionViewModel()
    @StateObject private var nurseViewModel = NurseSelectionViewModel()
    @StateObject private var featureLimitService = FeatureLimitService.shared
    @StateObject private var configurationService = DrainageConfigurationService.shared
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var selectedPatient: PatientData?
    @State private var incidentName = ""
    @State private var selectedDrainageType = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var catheterInsertionDate = Date()
    @State private var selectedNurses: Set<NurseData> = []
    @State private var description = ""

    // Schedule fields
    @State private var schedules: [Schedule] = [
        Schedule(
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            interval: "day",
            duration: 3,
            recurring: true,
            dateTimeArray: [
                Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date(),
                Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) ?? Date(),
                Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
            ],
            notificationBuffer: 60
        )
    ]
    @State private var isScheduleExpanded = false
    @State private var editingScheduleIndex: Int?
    @State private var editingSchedule: Schedule?

    // Notification fields
    @State private var notifications: [NotificationRule] = [
        NotificationRule(
            fieldKey: "temperature",
            condition: "gt",
            value: .int(100),
            notificationLevel: "HIGH"
        ),
        NotificationRule(
            fieldKey: "painLevel",
            condition: "gte",
            value: .int(8),
            notificationLevel: "HIGH"
        ),
        NotificationRule(
            fieldKey: "amount",
            condition: "gt",
            value: .int(80),
            notificationLevel: "HIGH"
        )
    ]
    @State private var isNotificationExpanded = false
    @State private var editingNotificationIndex: Int?
    @State private var editingNotification: NotificationRule?

    // Field Configuration fields
    @State private var fieldConfigs: [FieldConfig] = []
    @State private var isFieldConfigExpanded = false
    @State private var editingFieldConfigIndex: Int?
    @State private var editingFieldConfig: FieldConfig?

    // UI State
    @State private var showingPatientPicker = false
    @State private var showingNursePicker = false
    @State private var isLoading = false
    @State private var isIncidentDetailsExpanded = true
    @State private var isOptionalDetailsExpanded = false
    @State private var showingIncidentLimitAlert = false
    @State private var limitAlertMessage = ""

    init(incidentToEdit: Incident? = nil, linkedFromIncident: Incident? = nil) {
        self.incidentToEdit = incidentToEdit
        self.linkedFromIncident = linkedFromIncident
    }

    var body: some View {
        NavigationView {
            Form {
                // Linked Incident Header Section
                if let linkedIncident = linkedFromIncident {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                Text("Linked from Incident")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(linkedIncident.status)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(linkedIncident.status == "Active" ? Color.green : Color.red)
                                    .clipShape(Capsule())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Incident Name:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(linkedIncident.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Text("Patient:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(linkedIncident.patientName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Text("Patient ID:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(linkedIncident.patientId)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Text("Drainage Type:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(linkedIncident.drainageType)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Text("Location:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(linkedIncident.location)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                
                                HStack {
                                    Text("Linked Count:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(linkedIncident.linked?.count ?? 0) incidents")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                if TokenManager.shared.loadCurrentUser()?.role != "Patient" {
                    Section(header: Text("Patient")) {
                        HStack {
                            VStack(alignment: .leading) {
                                if selectedPatient == nil {
                                    Text("Select Patient")
                                        .foregroundColor(.gray)
                                } else {
                                    Text(selectedPatient?.fullName ?? "")
                                        .foregroundColor(.primary)
                                    Text(selectedPatient?.userSlug ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            Button(action: {
                                showingPatientPicker = true
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingPatientPicker = true
                        }
                    }
                }

                Section(header: Text("Genrals Details")) {
                    // Header row - always visible
                    HStack {
                        VStack(alignment: .leading) {
                            if !isIncidentDetailsExpanded {
                                if !incidentName.isEmpty && !location.isEmpty {
                                    Text("\(incidentName) • \(location)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("Tap to add incident details")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isIncidentDetailsExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isIncidentDetailsExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isIncidentDetailsExpanded.toggle()
                        }
                    }

                    // Expandable content
                    if isIncidentDetailsExpanded {
                        TextField("Incident Name", text: $incidentName)

                        Picker("Drainage Type", selection: $selectedDrainageType) {
                            ForEach(DrainageEntry.drainageTypeOptions, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .onChange(of: selectedDrainageType) { newType in
                            loadDynamicConfiguration(for: newType)
                        }

                        TextField("Location", text: $location)

                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])

                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date])

                        HStack {
                            VStack(alignment: .leading) {
                                if selectedNurses.isEmpty {
                                    Text("Select Nurse Access")
                                        .foregroundColor(.gray)
                                } else {
                                    Text("\(selectedNurses.count) nurse(s) selected")
                                        .foregroundColor(.primary)

                                    // Selected nurses list
                                    ForEach(Array(selectedNurses), id: \.id) { nurse in
                                        HStack {
                                            Text(nurse.fullName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Spacer()

                                            Button {
                                                selectedNurses.remove(nurse)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }

                            Spacer()

                            Button(action: {
                                showingNursePicker = true
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingNursePicker = true
                        }

                        DatePicker("Catheter Insertion Date (Optional)", selection: $catheterInsertionDate, displayedComponents: [.date])

                        TextField("Description (Optional)", text: $description, axis: .vertical)
                            .lineLimit(3 ... 6)
                    }
                }

                Section(header: Text("Schedule")) {
                    // Header row - always visible
                    HStack {
                        VStack(alignment: .leading) {
                            if !isScheduleExpanded {
                                if schedules.isEmpty {
                                    Text("No schedules added")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("\(schedules.count) schedule(s) added")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isScheduleExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isScheduleExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isScheduleExpanded.toggle()
                        }
                    }

                    // Expandable content
                    if isScheduleExpanded {
                        ForEach(Array(schedules.enumerated()), id: \.element.id) { index, schedule in
                            ScheduleRowView(index: index,schedule: schedule) {
                                editingScheduleIndex = index
                                editingSchedule = schedule
                            } onDelete: {
                                if index < schedules.count {
                                    schedules.remove(at: index)
                                }
                            }
                        }

                        Button(action: {
                            editingScheduleIndex = nil
                            editingSchedule = Schedule(
                                startDate: Date(),
                                endDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
                                interval: "day",
                                duration: 0,
                                recurring: true,
                                dateTimeArray: [],
                                notificationBuffer: 30
                            )
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Schedule")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Notifications")) {
                                 // Header row - always visible
                                 HStack {
                                     VStack(alignment: .leading) {
                                         if !isNotificationExpanded {
                                             if notifications.isEmpty {
                                                 Text("No notifications added")
                                                     .font(.caption)
                                                     .foregroundColor(.gray)
                                             } else {
                                                 Text("\(notifications.count) notification(s) added")
                                                     .font(.caption)
                                                     .foregroundColor(.gray)
                                             }
                                         }
                                     }
                                     
                                     Spacer()
                                     
                                     Button(action: {
                                         withAnimation(.easeInOut(duration: 0.2)) {
                                             isNotificationExpanded.toggle()
                                         }
                                     }) {
                                         Image(systemName: isNotificationExpanded ? "chevron.down" : "chevron.right")
                                             .foregroundColor(.gray)
                                     }
                                 }
                                 .contentShape(Rectangle())
                                 .onTapGesture {
                                     withAnimation(.easeInOut(duration: 0.2)) {
                                         isNotificationExpanded.toggle()
                                     }
                                 }
                                 
                                 // Expandable content
                                 if isNotificationExpanded {
                                     ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                                         NotificationRowView(index:index,notification: notification) {
                                             editingNotificationIndex = index
                                             editingNotification = notification
                                         } onDelete: {
                                             if index < notifications.count {
                                                 notifications.remove(at: index)
                                             }
                                         }
                                     }
                                     
                                     Button(action: {
                                         editingNotificationIndex = nil
                                         editingNotification = NotificationRule()
                                     }) {
                                         HStack {
                                             Image(systemName: "plus.circle.fill")
                                                 .foregroundColor(.blue)
                                             Text("Add Notification")
                                                 .foregroundColor(.blue)
                                         }
                                     }
                                     .padding(.vertical, 8)
                                 }
                             }
                
                Section(header: Text("Field Configuration")) {
                    // Header row - always visible
                    HStack {
                        VStack(alignment: .leading) {
                            if !isFieldConfigExpanded {
                                if fieldConfigs.isEmpty {
                                    Text("No field configurations added")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("\(fieldConfigs.count) field configuration(s) added")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFieldConfigExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isFieldConfigExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFieldConfigExpanded.toggle()
                        }
                    }
                    
                    // Expandable content
                    if isFieldConfigExpanded {
                        ForEach(Array(fieldConfigs.enumerated()), id: \.element.id) { index, fieldConfig in
                            FieldConfigRowView(index:index,fieldConfig: fieldConfig) {
                                editingFieldConfigIndex = index
                                editingFieldConfig = fieldConfig
                            } onDelete: {
                                if index < fieldConfigs.count {
                                    fieldConfigs.remove(at: index)
                                }
                            }
                        }
                        
                        Button(action: {
                            editingFieldConfigIndex = nil
                            editingFieldConfig = FieldConfig()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Field Configuration")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                
            }
            .navigationTitle(isEditing ? "Edit incident record" : "Add incident record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Save") {
                        Task {
                            await saveIncident()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                    .foregroundColor(isFormValid && !isLoading ? .accent : .gray)
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
            await loadData()
        }
            .alert("Error", isPresented: .constant(incidentStore.errorMessage != nil)) {
                Button("OK") {
                    incidentStore.errorMessage = nil
                }
            } message: {
                if let errorMessage = incidentStore.errorMessage {
                    Text(errorMessage)
                }
            }
            .toast(message: $incidentStore.errorMessage, type: .error)
            .toast(message: $incidentStore.successMessage, type: .success)
            .alert("Incident Limit Reached", isPresented: $showingIncidentLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(limitAlertMessage)
            }
            .sheet(isPresented: $showingPatientPicker) {
                PatientPickerView(selectedPatient: $selectedPatient)
                    .environmentObject(patientViewModel)
            }
            .sheet(isPresented: $showingNursePicker) {
                NursePickerView(selectedNurses: $selectedNurses)
                    .environmentObject(nurseViewModel)
            }
            .sheet(item: $editingSchedule) { schedule in
                ScheduleEditorView(
                    schedule: schedule,
                    onSave: { newSchedule in
                        if let index = editingScheduleIndex, index < schedules.count {
                            schedules[index] = newSchedule
                        } else {
                            schedules.append(newSchedule)
                        }
                        editingScheduleIndex = nil
                    }
                )
            }
            .sheet(item: $editingNotification) { notification in
                NotificationEditorView(
                    notification: notification,
                    onSave: { newNotification in
                        if let index = editingNotificationIndex, index < notifications.count {
                            notifications[index] = newNotification
                        } else {
                            notifications.append(newNotification)
                        }
                        editingNotificationIndex = nil
                    }
                )
            }
            .sheet(item: $editingFieldConfig) { fieldConfig in
                FieldConfigEditorView(
                    fieldConfig: fieldConfig,
                    onSave: { newFieldConfig in
                        if let index = editingFieldConfigIndex, index < fieldConfigs.count {
                            fieldConfigs[index] = newFieldConfig
                        } else {
                            fieldConfigs.append(newFieldConfig)
                        }
                        editingFieldConfigIndex = nil
                    }
                )
            }
        }
        .interactiveDismissDisabled()
    }

    private var isEditing: Bool {
        incidentToEdit != nil
    }

    private var isFormValid: Bool {
        // For non-patient users, patient selection is required
        let patientValid = TokenManager.shared.loadCurrentUser()?.role == "Patient" || selectedPatient != nil

        return patientValid &&
            !incidentName.isEmpty &&
            !selectedDrainageType.isEmpty &&
            !location.isEmpty &&
            startDate < endDate
    }

    // MARK: - Methods

    private func loadData() async {
        await patientViewModel.fetchPatients()
        await nurseViewModel.fetchNurses()
        await configurationService.fetchConfiguration()

        if let incident = incidentToEdit {
            // Pre-populate form with existing data
            incidentName = incident.name
            selectedDrainageType = incident.drainageType
            location = incident.location
            startDate = incident.startDate
            endDate = incident.endDate
            catheterInsertionDate = incident.catheterInsertionDate ?? Date()
            description = incident.description ?? ""
            schedules = incident.schedule ?? []
            notifications = incident.notification ?? []
            fieldConfigs = incident.fieldConfig ?? []

            // Find patient
            selectedPatient = patientViewModel.patients.first { $0.userSlug == incident.patientId }

            // Find nurses
            selectedNurses = Set(nurseViewModel.nurses.filter { incident.access.contains($0.id) })
        } else if let linkedIncident = linkedFromIncident {
            // Auto-select patient for linked incidents
            selectedPatient = patientViewModel.patients.first { $0.userSlug == linkedIncident.patientId }
        }
    }
    
    private func loadDynamicConfiguration(for drainageType: String) {
        // Get patient age if patient is selected
        var patientAge: Int? = nil
        if let patient = selectedPatient {
            patientAge = configurationService.getPatientAge(from: patient.dob ?? "")
        }
        
        // Load notifications from configuration with age filtering
        let configNotifications = configurationService.getNotifications(for: drainageType, patientAge: patientAge)
        if !configNotifications.isEmpty {
            notifications = configNotifications
        }
        
        // Load field configurations from configuration
        let configFieldConfigs = configurationService.getFieldConfigs(for: drainageType)
        if !configFieldConfigs.isEmpty {
            fieldConfigs = configFieldConfigs
        }
    }

    private func saveIncident() async {
        // Check incident count limit before saving (only for new incidents)
        if incidentToEdit == nil {
            let incidentLimitCheck = featureLimitService.canCreateIncident()
            if !incidentLimitCheck.allowed {
                limitAlertMessage = incidentLimitCheck.message ?? "Incident limit reached"
                showingIncidentLimitAlert = true
                return
            }
        }
        
        isLoading = true
        defer { isLoading = false }

        // Add current user to access list
        var accessList = selectedNurses.map { $0.id }
        if let currentUserId = TokenManager.shared.getUserId() {
            accessList.append(currentUserId)
        }

        // Handle patient information based on user role
        let finalPatientId: String
        let finalPatientName: String

        if TokenManager.shared.loadCurrentUser()?.role == "Patient" {
            finalPatientId = TokenManager.shared.loadCurrentUser()?.userSlug ?? ""
            finalPatientName = TokenManager.shared.getUserName() ?? ""
        } else {
            guard let patient = selectedPatient else { return }
            finalPatientId = patient.userSlug
            finalPatientName = patient.fullName
        }

        // Prepare linked incidents array
        var linkedIncidents: [LinkedIncident] = []
        
        if let linkedIncident = linkedFromIncident {
            // Add existing linked incidents from the source incident
            if let existingLinked = linkedIncident.linked {
                linkedIncidents.append(contentsOf: existingLinked)
            }
            
            // Add the current source incident to the linked list
            let sourceLinkedIncident = LinkedIncident(
                incident: LinkedIncidentData(
                    id: linkedIncident.id,
                    name: linkedIncident.name,
                    patientName: linkedIncident.patientName,
                    patientId: linkedIncident.patientId,
                    drainageType: linkedIncident.drainageType,
                    location: linkedIncident.location,
                    description: linkedIncident.description,
                    startDate: linkedIncident.startDate,
                    endDate: linkedIncident.endDate,
                    catheterInsertionDate: linkedIncident.catheterInsertionDate,
                    status: linkedIncident.status,
                    incidentId: linkedIncident.incidentId,
                    createdAt: linkedIncident.createdAt,
                    updatedAt: linkedIncident.updatedAt,
                    linked: linkedIncident.linked
                ),
                linkedDate: Date()
            )
            linkedIncidents.append(sourceLinkedIncident)
        }
        
        let incident = Incident(
            id: incidentToEdit?.id ?? "",
            userId: TokenManager.shared.getUserId() ?? "",
            patientId: finalPatientId,
            patientName: finalPatientName,
            patientData: incidentToEdit?.patientData, // Preserve existing patient data if editing
            name: incidentName,
            drainageType: selectedDrainageType,
            location: location,
            description: description.isEmpty ? nil : description,
            startDate: startDate,
            endDate: endDate,
            catheterInsertionDate: catheterInsertionDate,
            access: accessList,
            schedule: schedules.isEmpty ? nil : schedules,
            notification: notifications.isEmpty ? nil : notifications,
            fieldConfig: fieldConfigs.isEmpty ? nil : fieldConfigs,
            createdAt: incidentToEdit?.createdAt ?? Date(),
            updatedAt: Date(),
            incidentId: incidentToEdit?.incidentId,
            status: "Active",
            linked: linkedIncidents.isEmpty ? nil : linkedIncidents
        )

        if isEditing {
            await incidentStore.updateIncident(incident)
        } else {
            await incidentStore.addIncident(incident)
        }

        if incidentStore.errorMessage == nil {
            // Post notification to refresh incident list
            NotificationCenter.default.post(name: .RefreshIncidentList, object: nil)
            if isEditing {
                NotificationCenter.default.post(name: .updateIncidentRecord, object: nil)
            }
            
            // Refresh feature limits after successful incident creation/deletion
            await featureLimitService.fetchFeatureLimits()
            
            // Dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2 * 1000000000) // 2 seconds delay
            dismiss()
        }
    }

    // MARK: - Utility Functions

    /// Converts a timestamp (TimeInterval) to ISO 8601 date string format
    /// - Parameter timestamp: The timestamp to convert
    /// - Returns: ISO 8601 formatted date string
    private func timestampToISO8601(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Converts a Date to ISO 8601 date string format
    /// - Parameter date: The date to convert
    /// - Returns: ISO 8601 formatted date string
    private func dateToISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Test function to verify timestamp conversion
    /// This function demonstrates how the timestamps from your example will be converted
    private func testTimestampConversion() {
        // Your example timestamps
        let startTimestamp: TimeInterval = 776622243.70906103
        let endTimestamp: TimeInterval = 776971440

        let startDateString = timestampToISO8601(startTimestamp)
        let endDateString = timestampToISO8601(endTimestamp)

        print("Start Date: \(startDateString)")
        print("End Date: \(endDateString)")

        // This should output something like:
        // Start Date: 2025-08-15T10:30:43.709Z
        // End Date: 2025-08-15T16:21:00.000Z
    }
}

// MARK: - Schedule Row View

struct ScheduleRowView: View {
    let index: Int
    let schedule: Schedule
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("schedule \(index + 1)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(formatScheduleDetails(schedule))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onEdit) {
                        HStack {
                            Image(systemName: "pencil")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())

                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
            }

            Divider()
        }
        .padding(.vertical, 4)
        .alert("Delete Schedule", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this schedule? This action cannot be undone.")
        }
    }

    

    private func formatScheduleDetails(_ schedule: Schedule) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let startDateStr = formatter.string(from: schedule.startDate)
        let endDateStr = formatter.string(from: schedule.endDate)

        if schedule.recurring {
            let intervalText = schedule.interval.isEmpty ? "Custom" : schedule.interval.capitalized
            return "\(startDateStr) - \(endDateStr) • \(intervalText) • \(schedule.duration) times"
        } else {
            return "\(startDateStr) - \(endDateStr) • \(schedule.dateTimeArray.count) specific times"
        }
    }
}

// MARK: - Time Row View (UI shows only time, but stores full date)

struct TimeRowView: View {
    let dateTime: Date
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTimeOnly(dateTime))
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("Specific Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
//                Button(action: onEdit) {
//                    HStack {
//                        Image(systemName: "pencil")
//                    }
//                    .foregroundColor(.blue)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 6)
//                    .background(Color.blue.opacity(0.1))
//                    .clipShape(RoundedRectangle(cornerRadius: 6))
//                }
//                .buttonStyle(PlainButtonStyle())
//                .contentShape(Rectangle())
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .alert("Delete Specific Time", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this specific time? This action cannot be undone.")
        }
    }
    
    // UI shows only time, but the actual dateTime still contains full date data
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let index: Int
    let notification: NotificationRule
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification \(index + 1)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(formatNotificationDetails(notification))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: onEdit) {
                        HStack {
                            Image(systemName: "pencil")
                          
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
            }

            Divider()
        }
        .padding(.vertical, 4)
        .alert("Delete Notification", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this notification? This action cannot be undone.")
        }
    }

    private func formatNotificationTitle(_ notification: NotificationRule) -> String {
        return "\(notification.fieldKey.capitalized) Alert"
    }

    private func formatNotificationDetails(_ notification: NotificationRule) -> String {
        let conditionText = notification.condition.uppercased()
        let levelText = notification.notificationLevel.capitalized
        return "\(conditionText) \(notification.value) • \(levelText) Priority"
    }
}

// MARK: - Notification Editor View

struct NotificationEditorView: View {
    let notification: NotificationRule?
    let onSave: (NotificationRule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var fieldKey: String = ""
    @State private var condition: String = ""
    @State private var value: String = ""
    @State private var notificationLevel: String = "HIGH"

    private let fieldKeyOptions = ["amount", "fluidSalineFlushAmount", "color", "painLevel", "temperature", "bloodPressure", "heartRate", "respiratoryRate", "oxygenSaturation"]
    private let conditionOptions = ["gt", "gte", "lt", "lte", "includes", "eq"]
    private let notificationLevelOptions = ["HIGH", "MID", "LOW"]

    init(notification: NotificationRule?, onSave: @escaping (NotificationRule) -> Void) {
        self.notification = notification
        self.onSave = onSave

        if let notification = notification {
            _fieldKey = State(initialValue: notification.fieldKey)
            _condition = State(initialValue: notification.condition)
            _value = State(initialValue: notification.value.displayText)
            _notificationLevel = State(initialValue: notification.notificationLevel)
        } else {
            _fieldKey = State(initialValue: "")
            _condition = State(initialValue: "")
            _value = State(initialValue: "")
            _notificationLevel = State(initialValue: "HIGH")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Drainage Vitals")) {
                    Picker("Field", selection: $fieldKey) {
                        Text("Select Field").tag("")
                        ForEach(fieldKeyOptions, id: \.self) { option in
                            Text(formatFieldKey(option)).tag(option)
                        }
                    }
                    .onChange(of: fieldKey) { newFieldKey in
                        // Clear value for all fields - no default values
                        value = ""
                    }
                }

                Section(header: Text("Condition")) {
                    Picker("Condition", selection: $condition) {
                        Text("Select Condition").tag("")
                        ForEach(conditionOptions, id: \.self) { option in
                            Text(formatCondition(option)).tag(option)
                        }
                    }
                }

                Section(header: Text("Trigger Value")) {
                    if fieldKey == "painLevel" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Pain Level: \(value)")
                                    .font(.headline)
                                Spacer()
                            }

                            Slider(value: Binding(
                                get: { Double(value) ?? 5 },
                                set: { value = String(Int($0)) }
                            ), in: 0 ... 10, step: 1)

                            HStack {
                                Text("0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("10")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        TextField("Enter value", text: $value)
                            .keyboardType(getKeyboardType())
                    }
                }

                Section(header: Text("Alert Level")) {
                    Picker("Level", selection: $notificationLevel) {
                        ForEach(notificationLevelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle(notification == nil ? "New Notification" : "Edit Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let valueType: NotificationValue
                        if ["amount", "fluidSalineFlushAmount", "painLevel", "temperature"].contains(fieldKey) {
                            if let intVal = Int(value) {
                                valueType = .int(intVal)
                            } else {
                                valueType = .string(value) // fallback if parsing fails
                            }
                        } else {
                            valueType = .string(value)
                        }

                        let newNotification = NotificationRule(
                            fieldKey: fieldKey,
                            condition: condition,
                            value: valueType,
                            notificationLevel: notificationLevel,
                            id: notification?.id
                        )
                        onSave(newNotification)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private var isFormValid: Bool {
        // Field key and condition are required, but value is optional for vital signs
        if fieldKey.isEmpty || condition.isEmpty {
            return false
        }
        
        // For vital signs fields, value can be empty (optional)
        if ["heartRate", "respiratoryRate", "oxygenSaturation", "bloodPressure", "temperature", "painLevel", "amount", "fluidSalineFlushAmount"].contains(fieldKey) {
            return true
        }
        
        // For other fields, value is required
        return !value.isEmpty
    }

    private func formatFieldKey(_ key: String) -> String {
        switch key {
        case "amount": return "Amount"
        case "fluidSalineFlushAmount": return "Fluid Saline Flush Amount"
        case "color": return "Color"
        case "painLevel": return "Pain Level"
        case "temperature": return "Temperature"
        case "bloodPressure": return "Blood Pressure"
        case "heartRate": return "Heart Rate"
        case "respiratoryRate": return "Respiratory Rate"
        case "oxygenSaturation": return "Oxygen Saturation"
        default: return key.capitalized
        }
    }

    private func formatCondition(_ condition: String) -> String {
        switch condition {
        case "gt": return "Greater Than (>)"
        case "gte": return "Greater Than or Equal (≥)"
        case "lt": return "Less Than (<)"
        case "lte": return "Less Than or Equal (≤)"
        case "includes": return "Includes"
        case "eq": return "Equals (=)"
        default: return condition.uppercased()
        }
    }

    private func getKeyboardType() -> UIKeyboardType {
        switch fieldKey {
        case "amount", "fluidSalineFlushAmount", "painLevel", "temperature", "heartRate", "respiratoryRate", "oxygenSaturation":
            return .numberPad
        case "bloodPressure":
            return .numbersAndPunctuation
        default:
            return .default
        }
    }
}

// MARK: - Schedule Editor View

struct ScheduleEditorView: View {
    let schedule: Schedule?
    let onSave: (Schedule) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var interval: String = "day"
    @State private var duration: Int = 0
    @State private var recurring: Bool = true // Always true now
    @State private var dateTimeArray: [Date] = []
    @State private var notificationBuffer: Int = 60

    @State private var showingDateTimePicker = false
    @State private var selectedDateTimeIndex: Int?
    @State private var isFirstTimeSelection = true

    private let intervalOptions = ["", "day"]
    private let notificationBufferOptions = [15, 30, 45, 60, 90, 120]

    init(schedule: Schedule?, onSave: @escaping (Schedule) -> Void) {
        self.schedule = schedule
        self.onSave = onSave

        if let schedule = schedule {
            print("Initializing ScheduleEditorView with existing schedule: recurring=\(schedule.recurring), interval='\(schedule.interval)', duration=\(schedule.duration)")
            _startDate = State(initialValue: schedule.startDate)
            _endDate = State(initialValue: schedule.endDate)
            _interval = State(initialValue: schedule.interval)
            _duration = State(initialValue: schedule.duration)
            _recurring = State(initialValue: true) // Always true
            _dateTimeArray = State(initialValue: schedule.dateTimeArray)
            _notificationBuffer = State(initialValue: schedule.notificationBuffer)
        } else {
            print("Initializing ScheduleEditorView with new schedule")
            let now = Date()
            _startDate = State(initialValue: now)
            _endDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now)
            _interval = State(initialValue: "")
            _duration = State(initialValue: 0)
            _recurring = State(initialValue: true) // Always true
            _dateTimeArray = State(initialValue: [])
            _notificationBuffer = State(initialValue: 30)
        }
    }

        var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                    DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                    Stepper("How Many times a day drainage needs to be : \(duration) times", value: $duration, in: 1 ... 365)
                }
                
//                Section(header: Text("Recurrence Settings")) {
//                    Picker("Interval", selection: $interval) {
//                        ForEach(intervalOptions.dropFirst(), id: \.self) { option in
//                            Text(option.capitalized).tag(option)
//                        }
//                    }
//                }
                
                Section(header: Text("Select Time")) {
                    ForEach(Array(dateTimeArray.enumerated()), id: \.offset) { index, dateTime in
                        TimeRowView(
                            dateTime: dateTime,
                            onEdit: {
                                selectedDateTimeIndex = index
                                showingDateTimePicker = true
                            },
                            onDelete: {
                                if index < dateTimeArray.count {
                                    dateTimeArray.remove(at: index)
                                }
                            }
                        )
                    }
                    
                    Button("Select Time") {
                        selectedDateTimeIndex = nil
                        showingDateTimePicker = true
                    }
                    .foregroundColor(.blue)
                }

                Section(header: Text("Notification Settings")) {
                    Picker("When we notify you. (minutes)", selection: $notificationBuffer) {
                        ForEach(notificationBufferOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                }
            }
            .navigationTitle(schedule == nil ? "Schedule" :  "Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        print("ScheduleEditorView Save button tapped")
                        let newSchedule = Schedule(
                            startDate: startDate,
                            endDate: endDate,
                            interval: interval,
                            duration: duration,
                            recurring: recurring,
                            dateTimeArray: dateTimeArray,
                            notificationBuffer: notificationBuffer,
                            id: schedule?.id // Preserve the existing ID when editing
                        )
                        print("Created newSchedule: \(newSchedule)")
                        onSave(newSchedule)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingDateTimePicker) {
                DateTimePickerView(
                    dateTime: selectedDateTimeIndex != nil && selectedDateTimeIndex! < dateTimeArray.count ? dateTimeArray[selectedDateTimeIndex!] : Date(),
                    duration: duration,
                    isFirstTime: schedule == nil ? isFirstTimeSelection : false, // Set to false when editing existing time
                    onSave: { newDateTimes in
                        if let index = selectedDateTimeIndex, index < dateTimeArray.count {
                            // Editing existing time - replace with new times
                            dateTimeArray.remove(at: index)
                            dateTimeArray.insert(contentsOf: newDateTimes, at: index)
                        } else {
                            // Adding new time - append all generated times
                            dateTimeArray.append(contentsOf: newDateTimes)
                        }
                        selectedDateTimeIndex = nil
                        isFirstTimeSelection = schedule == nil ? isFirstTimeSelection : false // Mark as not first time anymore
                    }
                )
            }
        }
    }

    private var isFormValid: Bool {
        return startDate < endDate && !interval.isEmpty && duration > 0
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Time Picker View (UI shows only time, but stores full date)

struct DateTimePickerView: View {
    let dateTime: Date
    let duration: Int
    let isFirstTime: Bool
    let onSave: ([Date]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date
    
    init(dateTime: Date, duration: Int, isFirstTime: Bool, onSave: @escaping ([Date]) -> Void) {
        self.dateTime = dateTime
        self.duration = duration
        self.isFirstTime = isFirstTime
        self.onSave = onSave
        _selectedTime = State(initialValue: dateTime)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if duration > 1 && isFirstTime {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Will generate \(duration) times (every \(24/duration) hours) starting from selected time")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                }
                
                // UI shows only time picker, but we still store full date data
                DatePicker("", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(WheelDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Create a full date by combining today's date with selected time
                        let calendar = Calendar.current
                        let today = Date()
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
                        let baseDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                                                   minute: timeComponents.minute ?? 0, 
                                                   second: 0, 
                                                   of: today) ?? selectedTime
                        
                        var generatedTimes: [Date] = []
                        
                        if duration > 1 && isFirstTime {
                            // Generate multiple times based on duration (only on first time)
                            let hoursBetween = 24 / duration
                            
                            for i in 0..<duration {
                                let hoursToAdd = i * hoursBetween
                                if let newTime = calendar.date(byAdding: .hour, value: hoursToAdd, to: baseDate) {
                                    generatedTimes.append(newTime)
                                }
                            }
                        } else {
                            // Just add the selected time once
                            generatedTimes.append(baseDate)
                        }
                        
                        onSave(generatedTimes)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Patient Picker

struct PatientPickerView: View {
    @Binding var selectedPatient: PatientData?
    @EnvironmentObject private var viewModel: PatientSelectionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.patients) { patient in
                    Button {
                        selectedPatient = patient
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(patient.fullName)
                                    .foregroundColor(.primary)
                                Text(patient.email ?? "No email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedPatient?.id == patient.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.teal)
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(currentPatient: patient)
                        }
                    }
                }
            }
            .navigationTitle("Select Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Nurse Picker

struct NursePickerView: View {
    @Binding var selectedNurses: Set<NurseData>
    @EnvironmentObject private var viewModel: NurseSelectionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Nurses Section
                if !viewModel.nurses.isEmpty {
                    Section(header: Text("Nurses")) {
                        ForEach(viewModel.nurses) { nurse in
                            Button {
                                if selectedNurses.contains(nurse) {
                                    selectedNurses.remove(nurse)
                                } else {
                                    selectedNurses.insert(nurse)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(nurse.fullName)
                                            .foregroundColor(.primary)
                                        Text(nurse.email ?? "No email")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedNurses.contains(nurse) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.teal)
                                    }
                                }
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(currentNurse: nurse)
                                }
                            }
                        }
                    }
                }
                
                // Doctors Section
                if !viewModel.doctors.isEmpty {
                    Section(header: Text("Doctors")) {
                        ForEach(viewModel.doctors) { doctor in
                            Button {
                                if selectedNurses.contains(doctor) {
                                    selectedNurses.remove(doctor)
                                } else {
                                    selectedNurses.insert(doctor)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(doctor.fullName)
                                            .foregroundColor(.primary)
                                        Text(doctor.email ?? "No email")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedNurses.contains(doctor) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.teal)
                                    }
                                }
                            }
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(currentNurse: doctor)
                                }
                            }
                        }
                    }
                }
                
                // Empty State
                if viewModel.nurses.isEmpty && viewModel.doctors.isEmpty && !viewModel.isLoading {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("No staff found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("No nurses or doctors are available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Field Config Row View

struct FieldConfigRowView: View {
    let index: Int
    let fieldConfig: FieldConfig
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("fieldConfig \(index + 1)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(formatFieldConfigDetails(fieldConfig))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: onEdit) {
                        HStack {
                            Image(systemName: "pencil")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
            }

            Divider()
        }
        .padding(.vertical, 4)
        .alert("Delete Field Configuration", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this field configuration? This action cannot be undone.")
        }
    }

    private func formatFieldConfigTitle(_ fieldConfig: FieldConfig) -> String {
        return "\(formatFieldKey(fieldConfig.fieldKey)) Configuration"
    }

    private func formatFieldConfigDetails(_ fieldConfig: FieldConfig) -> String {
        let valueText = fieldConfig.value.displayText
        let defaultText = fieldConfig.isDefault ? "Default" : "Custom"
        let hiddenText = fieldConfig.isHidden ? "Hidden" : "Visible"
        let requiredText = fieldConfig.isRequired ? "Required" : "Optional"
        
        return "Value: \(valueText) • \(defaultText) • \(hiddenText) • \(requiredText)"
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
        case "bloodPressure": return "Blood Pressure"
        case "heartRate": return "Heart Rate"
        case "respiratoryRate": return "Respiratory Rate"
        case "oxygenSaturation": return "Oxygen Saturation"
        case "doctorNotified": return "Doctor Notified"
        case "beforeImage": return "Before Image"
        case "afterImage": return "After Image"
        case "fluidCupImage": return "Fluid Cup Image"
        case "beforeImageSign": return "Before Image Sign"
        case "afterImageSign": return "After Image Sign"
        case "fluidCupImageSign": return "Fluid Cup Image Sign"
        case "access": return "Access"
        case "accessData": return "Access Data"
        case "drainageId": return "Drainage ID"
        default: return key.capitalized
        }
    }
}

// MARK: - Field Config Editor View

struct FieldConfigEditorView: View {
    let fieldConfig: FieldConfig?
    let onSave: (FieldConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var fieldKey: String = ""
    @State private var value: String = ""
    @State private var otherValue: String = ""
    @State private var consistencyOtherValue: String = ""
    @State private var selectedConsistencyOptions: Set<String> = []
    @State private var isDefault: Bool = false
    @State private var isHidden: Bool = false
    @State private var isRequired: Bool = false
    @State private var selectedValueType: String = "string"

//    private let fieldKeyOptions = [
//         "fluidType", "color","consistency", "odor", "drainageType", "painLevel", "temperature","beforeImage", "afterImage", "fluidCupImage"
//    ]
    
    
    private let fieldKeyOptions = [
         "color", "temperature","fluidType","painLevel","consistency", "bloodPressure", "heartRate", "respiratoryRate", "oxygenSaturation"
    ]
    
    private let valueTypeOptions = ["string", "int", "double", "bool", "stringArray"]

    init(fieldConfig: FieldConfig?, onSave: @escaping (FieldConfig) -> Void) {
        self.fieldConfig = fieldConfig
        self.onSave = onSave

        if let fieldConfig = fieldConfig {
            _fieldKey = State(initialValue: fieldConfig.fieldKey)
            _value = State(initialValue: fieldConfig.value.displayText)
            _isDefault = State(initialValue: !fieldConfig.isDefault)
            _isHidden = State(initialValue: fieldConfig.isHidden)
            _isRequired = State(initialValue: fieldConfig.isRequired)
            
            // Set value type based on the current value
            switch fieldConfig.value {
            case .string: _selectedValueType = State(initialValue: "string")
            case .int: _selectedValueType = State(initialValue: "int")
            case .double: _selectedValueType = State(initialValue: "double")
            case .bool: _selectedValueType = State(initialValue: "bool")
            case .stringArray: _selectedValueType = State(initialValue: "stringArray")
            }
            
            // Set consistency options if it's a consistency field
            if fieldConfig.fieldKey == "consistency" {
                switch fieldConfig.value {
                case .stringArray(let array):
                    let options = Set(array)
                    let predefinedOptions = Set(DrainageEntry.consistencyOptions)
                    let customValues = options.subtracting(predefinedOptions)
                    
                    // Start with predefined options that are selected
                    var selectedOptions = options.intersection(predefinedOptions)
                    
                    // If there are custom values, add "Other" to selected options
                    if !customValues.isEmpty {
                        selectedOptions.insert("Other")
                        // Join multiple custom values with comma if there are more than one
                        let customValueString = customValues.joined(separator: ", ")
                        _consistencyOtherValue = State(initialValue: customValueString)
                    }
                    
                    _selectedConsistencyOptions = State(initialValue: selectedOptions)
                default:
                    _selectedConsistencyOptions = State(initialValue: [])
                }
            }
            
            // Set other value if the current value is not in the dropdown options
            if hasDropdownOptions(fieldConfig.fieldKey) {
                let options = getDropdownOptions(for: fieldConfig.fieldKey)
                if case .string(let strValue) = fieldConfig.value, !options.contains(strValue) {
                    _otherValue = State(initialValue: strValue)
                    _value = State(initialValue: "Other")
                }
            }
        } else {
            _fieldKey = State(initialValue: "")
            _value = State(initialValue: "")
            _otherValue = State(initialValue: "")
            _consistencyOtherValue = State(initialValue: "")
            _selectedConsistencyOptions = State(initialValue: [])
            _isDefault = State(initialValue: false)
            _isHidden = State(initialValue: false)
            _isRequired = State(initialValue: false)
            _selectedValueType = State(initialValue: "string")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Drainage Vitals")) {
                    Picker("Field", selection: $fieldKey) {
                        Text("Select Field").tag("")
                        ForEach(fieldKeyOptions, id: \.self) { option in
                            Text(formatFieldKey(option)).tag(option)
                        }
                    }
                    .onChange(of: fieldKey) { newFieldKey in
                        // Auto-set value type based on field key
                        selectedValueType = getValueTypeForField(newFieldKey)
                        
                        // Set default value based on field key
                        switch newFieldKey {
                        case "consistency":
                            value = ""
                            selectedConsistencyOptions = []
                            consistencyOtherValue = ""
                        case "isFluidSalineFlush", "odorPresent", "doctorNotified":
                            value = "false"
                        case "fluidType":
                            value = DrainageEntry.fluidTypes.first ?? ""
                        case "color":
                            value = DrainageEntry.colorOptions.first ?? ""
                        case "odor":
                            value = DrainageEntry.odorOptions.first ?? ""
                        case "drainageType":
                            value = DrainageEntry.drainageTypeOptions.first ?? ""
                        default:
                            value = ""
                        }
                        
                        // Reset other values when field changes
                        otherValue = ""
                        consistencyOtherValue = ""
                    }
                }

                Section(header: Text("Value")) {
                    if isImageField(fieldKey) {
                        Text("Image fields don't require default values")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else if fieldKey == "consistency" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Consistency Options")
                                .font(.system(size: 16))
                            
                            ForEach(DrainageEntry.consistencyOptions, id: \.self) { option in
                                HStack {
                                    Button(action: {
                                        if selectedConsistencyOptions.contains(option) {
                                            selectedConsistencyOptions.remove(option)
                                        } else {
                                            selectedConsistencyOptions.insert(option)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedConsistencyOptions.contains(option) ? "checkmark.square.fill" : "square")
                                                .foregroundColor(selectedConsistencyOptions.contains(option) ? .accentColor : .gray)
                                            Text(option)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Spacer()
                                }
                            }
                        }
                        
                        if selectedConsistencyOptions.contains("Other") {
                            TextField("Specify Consistency", text: $consistencyOtherValue)
                        }
                    } else if selectedValueType == "bool" {
                        Picker("Boolean Value", selection: $value) {
                            Text("True").tag("true")
                            Text("False").tag("false")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    } else if hasDropdownOptions(fieldKey) {
                        Picker("Select Value", selection: $value) {
                            Text("Select a value").tag("")
                            ForEach(getDropdownOptions(for: fieldKey), id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        
                        if value == "Other" {
                            TextField("Specify \(formatFieldKey(fieldKey))", text: $otherValue)
                        }
                    } else if selectedValueType == "stringArray" {
                        TextField("Enter comma-separated values", text: $value)
                    } else {
                        TextField("Enter value", text: $value)
                            .keyboardType(getKeyboardType())
                    }
                }

                Section(header: Text("Field Settings")) {
                    Toggle("Can Changeable ?", isOn: $isDefault)
                    Toggle("Hidden", isOn: $isHidden)
                    Toggle("Required", isOn: $isRequired)
                }
            }
            .navigationTitle(fieldConfig == nil ? "New Field Configuration" : "Edit Field Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let fieldConfigValue = createFieldConfigValue()
                        let newFieldConfig = FieldConfig(
                            fieldKey: fieldKey,
                            value: fieldConfigValue,
                            isDefault: !isDefault,
                            isHidden: isHidden,
                            isRequired: isRequired,
                            id: fieldConfig?.id
                        )
                        onSave(newFieldConfig)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private var isFormValid: Bool {
        if fieldKey.isEmpty { return false }
        
        // For image fields, value can be empty
        if isImageField(fieldKey) {
            return true
        }
        
        // For optional vital signs fields, value can be empty
        if ["heartRate", "respiratoryRate", "oxygenSaturation", "bloodPressure", "temperature", "painLevel", "amount", "fluidSalineFlushAmount"].contains(fieldKey) {
            return true
        }
        
        // For consistency field, at least one option should be selected
        if fieldKey == "consistency" {
            if selectedConsistencyOptions.isEmpty {
                return false
            }
            
            // If "Other" is selected, the other value should not be empty
            if selectedConsistencyOptions.contains("Other") && consistencyOtherValue.isEmpty {
                return false
            }
            
            return true
        }
        
        // For dropdown fields with "Other" selected, otherValue should not be empty
        if hasDropdownOptions(fieldKey) && value == "Other" {
            return !otherValue.isEmpty
        }
        
        return !value.isEmpty
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
        case "bloodPressure": return "Blood Pressure"
        case "heartRate": return "Heart Rate"
        case "respiratoryRate": return "Respiratory Rate"
        case "oxygenSaturation": return "Oxygen Saturation"
        case "doctorNotified": return "Doctor Notified"
        case "beforeImage": return "Before Image"
        case "afterImage": return "After Image"
        case "fluidCupImage": return "Fluid Cup Image"
        case "beforeImageSign": return "Before Image Sign"
        case "afterImageSign": return "After Image Sign"
        case "fluidCupImageSign": return "Fluid Cup Image Sign"
        case "access": return "Access"
        case "accessData": return "Access Data"
        case "drainageId": return "Drainage ID"
        default: return key.capitalized
        }
    }

    private func getKeyboardType() -> UIKeyboardType {
        switch selectedValueType {
        case "int", "double":
            return .decimalPad
        case "string":
            if fieldKey == "bloodPressure" {
                return .numbersAndPunctuation
            }
            return .default
        default:
            return .default
        }
    }
    
    private func createFieldConfigValue() -> FieldConfigValue {
        // For image fields, return empty string array
        if isImageField(fieldKey) {
            return .stringArray([])
        }
        
        // For consistency field, return selected options
        if fieldKey == "consistency" {
            var options = Array(selectedConsistencyOptions)
            
            // If "Other" is selected and has a value, replace "Other" with the custom value(s)
            if selectedConsistencyOptions.contains("Other") && !consistencyOtherValue.isEmpty {
                options.removeAll { $0 == "Other" }
                // Split the other value by comma to handle multiple custom values
                let customValues = consistencyOtherValue.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                options.append(contentsOf: customValues)
            }
            
            return .stringArray(options)
        }
        
        switch selectedValueType {
        case "int":
            return .int(Int(value) ?? 0)
        case "double":
            return .double(Double(value) ?? 0.0)
        case "bool":
            return .bool(value.lowercased() == "true")
        case "stringArray":
            let array = value.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            return .stringArray(array)
        default:
            // For dropdown fields, if "Other" is selected, use the otherValue
            if hasDropdownOptions(fieldKey) && value == "Other" {
                return .string(otherValue)
            }
            return .string(value)
        }
    }
    
    private func getValueTypeForField(_ fieldKey: String) -> String {
        switch fieldKey {
        case "amount", "fluidSalineFlushAmount", "temperature":
            return "double"
        case "painLevel", "heartRate", "respiratoryRate", "oxygenSaturation":
            return "int"
        case "bloodPressure":
            return "string" // Blood pressure is typically stored as "120/80" format
        case "consistency", "beforeImage", "afterImage", "fluidCupImage", "beforeImageSign", "afterImageSign", "fluidCupImageSign", "access", "accessData":
            return "stringArray"
        case "isFluidSalineFlush", "odorPresent", "doctorNotified":
            return "bool"
        case "fluidType", "color", "colorOther", "odor", "drainageType", "location", "amountUnit", "fluidSalineFlushAmountUnit", "comments", "patientId", "patientName", "userId", "drainageId":
            return "string"
        default:
            return "string"
        }
    }
    
    private func isImageField(_ fieldKey: String) -> Bool {
        return ["beforeImage", "afterImage", "fluidCupImage", "beforeImageSign", "afterImageSign", "fluidCupImageSign"].contains(fieldKey)
    }
    
    private func hasDropdownOptions(_ fieldKey: String) -> Bool {
        return ["fluidType", "color", "odor", "drainageType"].contains(fieldKey)
    }
    
    private func getDropdownOptions(for fieldKey: String) -> [String] {
        switch fieldKey {
        case "fluidType":
            return DrainageEntry.fluidTypes
        case "color":
            return DrainageEntry.colorOptions
        case "odor":
            return DrainageEntry.odorOptions
        case "drainageType":
            return DrainageEntry.drainageTypeOptions
        default:
            return []
        }
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

struct AddIncidentView_Previews: PreviewProvider {
    static var previews: some View {
        AddIncidentView()
            .environmentObject(IncidentStore())
    }
}
