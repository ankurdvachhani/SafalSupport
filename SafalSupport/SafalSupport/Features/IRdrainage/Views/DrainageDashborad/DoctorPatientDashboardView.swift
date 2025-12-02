import SwiftUI
import Charts

struct DoctorPatientDashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    @StateObject private var configService = ConfigurationService.shared
    
    @State private var selectedTimeRange: DashboardViewModel.TimeRange = .week
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Patient Header
                patientHeaderSection
                
                // Drainage Summary Cards
                drainageSummarySection
                
                // Quick Actions
                quickActionsSection
                
                // Recent Entries
                recentEntriesSection
                
                // Drainage Trends Chart
                drainageTrendsSection
                
                // Alerts Section
                alertsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(viewModel.patientData?.firstName ?? "") \(viewModel.patientData?.lastName ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await viewModel.loadPatientSpecificData()
        }
    }
    
    // MARK: - Patient Header Section
    private var patientHeaderSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Patient Avatar
                Circle()
                    .fill(Color.teal.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("\(viewModel.patientData?.firstName.prefix(1) ?? "")\(viewModel.patientData?.lastName.prefix(1) ?? "")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.teal)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(viewModel.patientData?.firstName ?? "") \(viewModel.patientData?.lastName ?? "")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Patient ID: \(viewModel.patientData?.userSlug ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.patientData?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Label("Active", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("Under Care")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.teal.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }
    
    // MARK: - Drainage Summary Section
    private var drainageSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Drainage Summary")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DoctorPatientStatCard(
                    title: "Today's Entries",
                    value: "\(viewModel.patientDashboardData?.stats.todayEntries ?? 0)",
                    icon: "list.clipboard.fill",
                    color: .teal
                )
                
                DoctorPatientStatCard(
                    title: "Total Volume",
                    value: String(format: "%.1f ml", viewModel.patientDashboardData?.stats.totalVolume ?? 0),
                    icon: "drop.fill",
                    color: .blue
                )
                
                DoctorPatientStatCard(
                    title: "Average Volume",
                    value: String(format: "%.1f ml", viewModel.patientDashboardData?.stats.averageVolume ?? 0),
                    icon: "chart.bar.fill",
                    color: .purple
                )
                
                DoctorPatientStatCard(
                    title: "Critical Alerts",
                    value: "\(viewModel.patientDashboardData?.alerts.count ?? 0)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                if configService.isIncidentEnabled {
                    DoctorPatientQuickActionButton(
                        title: "Add Entry",
                        icon: "plus.circle.fill",
                        color: .teal
                    ) {
                        NavigationManager.shared.navigate(
                            to: .addDrainage(),
                            style: .presentSheet()
                        )
                    }
                }
                
                DoctorPatientQuickActionButton(
                    title: "View History",
                    icon: "clock.fill",
                    color: .blue
                ) {
                    NavigationManager.shared.navigate(
                        to: .drainageListView(patientSlug: viewModel.patientData?.userSlug, patientName: "\(viewModel.patientData?.firstName ?? "") \(viewModel.patientData?.lastName ?? "")")
                    )
                }
                
                DoctorPatientQuickActionButton(
                    title: "Download Report",
                    icon: "arrow.down.doc.fill",
                    color: .purple
                ) {
                    // Download report functionality
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
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
                    NavigationManager.shared.navigate(
                        to: .drainageListView(patientSlug: viewModel.patientData?.userSlug, patientName: "\(viewModel.patientData?.firstName ?? "") \(viewModel.patientData?.lastName ?? "")")
                    )
                }
                .font(.subheadline)
                .foregroundColor(.teal)
            }
            
            if let entries = viewModel.patientDashboardData?.recentEntries, !entries.isEmpty {
                ForEach(entries.prefix(5)) { entry in
                    DoctorPatientEntryRow(entry: entry)
                        .onTapGesture {
                            NavigationManager.shared.navigate(to: .drainageDetail(entry: entry))
                        }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 50))
                        .foregroundColor(.teal.opacity(0.6))
                    
                    Text("No entries yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This patient hasn't recorded any drainage entries yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if configService.isIncidentEnabled {
                        Button("Add First Entry") {
                            NavigationManager.shared.navigate(
                                to: .addDrainage(),
                                style: .presentSheet()
                            )
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.teal)
                        .cornerRadius(25)
                    }
                   
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.teal.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Drainage Trends Section
    private var drainageTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Drainage Trends")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(DashboardViewModel.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            if let trends = viewModel.patientDashboardData?.drainageTrends, !trends.isEmpty {
                DoctorPatientDrainageChart(trends: trends)
                    .frame(height: 200)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    Text("No chart data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add more entries to see drainage trends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Alerts Section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Patient Alerts")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let alerts = viewModel.patientDashboardData?.alerts, !alerts.isEmpty {
                    Text("\(alerts.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            
            if let alerts = viewModel.patientDashboardData?.alerts, !alerts.isEmpty {
                ForEach(alerts.prefix(3)) { alert in
                    DoctorPatientAlertRow(alert: alert)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("All good!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("No alerts for this patient")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Supporting Views

struct DoctorPatientStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
}

struct DoctorPatientQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DoctorPatientEntryRow: View {
    let entry: DrainageEntry
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.teal.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "drop.fill")
                        .foregroundColor(.teal)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.amount, specifier: "%.1f") \(entry.amountUnit)")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Location: \(entry.location)")
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
                    .background(Color.teal)
                    .clipShape(Capsule())
                
                if entry.odorPresent == true {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.teal.opacity(0.05))
        .cornerRadius(16)
    }
}

struct DoctorPatientDrainageChart: View {
    let trends: [DrainageTrend]
    
    var body: some View {
        Chart(trends) { trend in
            LineMark(
                x: .value("Date", trend.date),
                y: .value("Volume", trend.totalVolume)
            )
            .foregroundStyle(.teal)
            .lineStyle(StrokeStyle(lineWidth: 3))
            
            AreaMark(
                x: .value("Date", trend.date),
                y: .value("Volume", trend.totalVolume)
            )
            .foregroundStyle(.teal.opacity(0.2))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

struct DoctorPatientAlertRow: View {
    let alert: CriticalAlert
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: alert.alertType.icon)
                .foregroundColor(alert.alertType.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(alert.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(alert.severity.rawValue)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(alert.severity.color)
                .clipShape(Capsule())
        }
        .padding()
        .background(alert.severity.color.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Preview
struct DoctorPatientDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DoctorPatientDashboardView(
            viewModel: DashboardViewModel(
                patient: PatientData(
                    id: "1",
                    firstName: "John",
                    lastName: "Doe", dob: "",
                    role: "patient",
                    userSlug: "john-doe-123",
                    metadata: PatientMetadata(
                        organizationId: "org1",
                        priority: .p1,
                        ncpiNumber: "NCPI123"
                    ),
                    email: "john.doe@example.com"
                )
            )
        )
    }
} 
