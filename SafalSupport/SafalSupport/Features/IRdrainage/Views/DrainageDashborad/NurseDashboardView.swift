import SwiftUI

struct NurseDashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject private var appState: AppState
    @StateObject private var configService = ConfigurationService.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Stats Cards
                nurseStatsSection
                
                // Quick Actions (Large Touch Targets)
                nurseQuickActionsSection
                
                // Assigned Patients
                assignedPatientsSection
                
                // Recent Entries
                recentEntriesSection
                
                // Overdue Entries
                overdueEntriesSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Nurse Stats Section
    private var nurseStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            NurseStatCard(
                title: "My Patients",
                value: "\(viewModel.nurseDashboardData?.stats.totalPatients ?? 0)",
                icon: "person.3.fill",
                color: .green
            )
            
            NurseStatCard(
                title: "Today's Entries",
                value: "\(viewModel.nurseDashboardData?.stats.todayEntries ?? 0)",
                icon: "list.clipboard.fill",
                color: .blue
            )
            
            NurseStatCard(
                title: "Overdue",
                value: "\(viewModel.nurseDashboardData?.stats.overdueEntries ?? 0)",
                icon: "clock.badge.exclamationmark",
                color: .orange
            )
            
            NurseStatCard(
                title: "Total Volume",
                value: String(format: "%.0f ml", viewModel.nurseDashboardData?.stats.totalVolume ?? 0),
                icon: "drop.fill",
                color: .purple
            )
        }
    }
    
    // MARK: - Nurse Quick Actions Section
    private var nurseQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.nurseDashboardData?.quickActions ?? []) { action in
                    NurseQuickActionCard(action: action) {
                        handleQuickAction(action.action)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Assigned Patients Section
    private var assignedPatientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Patients")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to patient list
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            
            if let patients = viewModel.nurseDashboardData?.assignedPatients, !patients.isEmpty {
                ForEach(patients.prefix(5)) { patient in
                    NursePatientRow(patient: patient)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No patients assigned")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Contact your supervisor to get assigned patients")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Recent Entries Section
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Entries")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to entries list
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            
            if let entries = viewModel.nurseDashboardData?.recentEntries, !entries.isEmpty {
                ForEach(entries.prefix(5)) { entry in
                    NurseEntryRow(entry: entry)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No recent entries")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Start recording drainage entries for your patients")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Overdue Entries Section
    private var overdueEntriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overdue Entries")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let overdue = viewModel.nurseDashboardData?.overdueEntries, !overdue.isEmpty {
                    Text("\(overdue.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            
            if let overdue = viewModel.nurseDashboardData?.overdueEntries, !overdue.isEmpty {
                ForEach(overdue.prefix(3)) { entry in
                    NurseOverdueEntryRow(entry: entry)
                }
                
                if overdue.count > 3 {
                    Button("View All Overdue (\(overdue.count))") {
                        // Navigate to overdue list
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("All caught up!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("No overdue entries to record")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    private func handleQuickAction(_ action: QuickAction.QuickActionType) {
        switch action {
        case .addEntry:
            if configService.isIncidentEnabled {
                NavigationManager.shared.navigate(
                    to: .addDrainage(),
                    style: .presentSheet()
                )
            }
        case .patientList:
            NavigationManager.shared.navigate(to: .patientList)
        case .criticalAlerts:
            // Navigate to overdue entries
            break
        case .reports:
            // Navigate to reports
            appState.selectedTab = .Drainage
            break
        case .settings:
            appState.selectedTab = .settings
       
        case .notifications:
            break
           // NavigationManager.shared.navigate(to: .notificationview)
        }
    }
}

// MARK: - Supporting Views

struct NurseStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct NurseQuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: action.icon)
                    .font(.system(size: 36))
                    .foregroundColor(action.color)
                
                Text(action.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NursePatientRow: View {
    let patient: PatientSummary
    
    var body: some View {
        HStack(spacing: 16) {
            // Patient Avatar
            Circle()
                .fill(patient.status.color.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(patient.status.color)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.patientName)
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Image(systemName: patient.status.icon)
                        .foregroundColor(patient.status.color)
                        .font(.caption)
                    
                    Text(patient.status.rawValue)
                        .font(.caption)
                        .foregroundColor(patient.status.color)
                }
                
                if let lastEntry = patient.lastEntryDate {
                    Text("Last entry: \(lastEntry, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(patient.totalEntries)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NurseEntryRow: View {
    let entry: DrainageEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Entry Icon
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.patientName ?? "Unknown Patient")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("\(entry.amount, specifier: "%.1f") \(entry.amountUnit) • \(entry.location)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(entry.recordedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.fluidType)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
                
                if entry.odorPresent == true {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NurseOverdueEntryRow: View {
    let entry: DrainageEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Overdue Icon
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.orange)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.patientName ?? "Unknown Patient")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Overdue by \(entry.recordedAt, style: .relative)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Text("Location: \(entry.location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Record") {
                // Navigate to add entry for this patient
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct NurseDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NurseDashboardView(
            viewModel: DashboardViewModel()
        )
    }
} 
