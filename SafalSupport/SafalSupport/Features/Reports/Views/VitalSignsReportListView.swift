import SwiftUI

struct VitalSignsReportListView: View {
    @StateObject private var reportStore: VitalSignsReportStore
    @State private var searchText = ""
    @State private var selectedSortOption: IncidentReportSortOption = .dateDesc
    @State private var showingSortSheet = false
    @State private var selectedReportForPDF: VitalSignsReport?
    @State private var pdfURL: URL?
    @State private var selectedReportForBarcode: VitalSignsReport?
    @State private var showingGenerateReportSheet = false
    
    init() {
        self._reportStore = StateObject(wrappedValue: VitalSignsReportStore())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Generate & Download Report Button
            generateReportButton
            
            // Search and Sort Section
          //  searchAndSortSection
            
            // Content Body
            contentBody
        }
        .navigationTitle("Vital Signs Report")
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $reportStore.errorMessage, type: .error)
        .toast(message: $reportStore.successMessage, type: .success)
        .overlay {
            if let report = selectedReportForPDF, let url = pdfURL {
                incidentCustomPDFOverlay(url: url, incidentName: report.title) {
                    selectedReportForPDF = nil
                    pdfURL = nil
                }
            }
        }
        .sheet(item: $selectedReportForBarcode) { report in
            ReportBarcodeDisplayView(reportId: report.reportId)
        }
        .sheet(isPresented: $showingSortSheet) {
            incidentReportSortSheet(
                selectedSortOption: $selectedSortOption,
                isPresented: $showingSortSheet
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingGenerateReportSheet) {
            GenerateVitalSignsReportSheet(
                isPresented: $showingGenerateReportSheet,
                onReportGenerated: {
                    Task {
                        await reportStore.refreshReports()
                    }
                }
            )
            .presentationDetents( [.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: searchText) { newValue in
            reportStore.searchReports(query: newValue)
        }
        .onAppear {
            // Add notification observer for PDF display from scanner
            NotificationCenter.default.addObserver(
                forName: .ShowReportPDF,
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.object as? [String: Any],
                   let report = userInfo["report"] as? VitalSignsReport,
                   let url = userInfo["url"] as? URL {
                    selectedReportForPDF = report
                    pdfURL = url
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // MARK: - Generate Report Button
    
    private var generateReportButton: some View {
        Button {
            showingGenerateReportSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Generate & Download Report")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.dynamicAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }

    // MARK: - Search and Sort Section

    private var searchAndSortSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search reports...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            reportStore.searchReports(query: searchText)
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            reportStore.searchReports(query: "")
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
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color.dynamicAccent)
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
                            await reportStore.fetchReports(resetPages: true, sortOption: selectedSortOption)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Color.dynamicAccent)
                }
            }
        }
        .padding()
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        ZStack {
            if reportStore.isLoading && reportStore.reports.isEmpty {
                reportShimmerList
            } else if !searchText.isEmpty && filteredReports.isEmpty {
                incidentReportNoSearchResultsView(searchText: searchText) {
                    searchText = ""
                    reportStore.searchReports(query: "")
                }
            } else if reportStore.reports.isEmpty {
                emptyStateView
            } else {
                reportsList
            }
        }
    }

    // MARK: - Filtered Reports

    private var filteredReports: [VitalSignsReport] {
        var filtered = reportStore.reports

        // Apply sort
        filtered = filtered.sorted(by: selectedSortOption.vitalSignsSortDescriptor)

        return filtered
    }

    // MARK: - Reports List

    private var reportsList: some View {
        List {
            ForEach(filteredReports) { report in
                VitalSignsReportRowView(report: report) {
                    Task {
                        await downloadAndShowReport(for: report)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        await downloadAndShowReport(for: report)
                    }
                }
                .task {
                    await reportStore.loadMoreIfNeeded(currentItem: report)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        Task {
                            await downloadAndShowReport(for: report)
                        }
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .tint(.blue)
                    
                    // Barcode option
                    if !report.reportId.isEmpty {
                        Button {
                            selectedReportForBarcode = report
                        } label: {
                            Label("Report ID Code", systemImage: "barcode")
                        }
                    }
                }
                .contextMenu {
                    Button {
                        Task {
                            await downloadAndShowReport(for: report)
                        }
                    } label: {
                        Label("Download Report", systemImage: "arrow.down.circle")
                    }
                    
                    // Barcode option
                    if !report.reportId.isEmpty {
                        Button {
                            selectedReportForBarcode = report
                        } label: {
                            Label("Report ID Code", systemImage: "barcode")
                        }
                    }
                }
            }

            if reportStore.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more reports...")
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
            await reportStore.refreshReports()
        }
        .onAppear {
            // Add notification observer
            NotificationCenter.default.addObserver(
                forName: .RefreshReportList,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await reportStore.refreshReports()
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
    }

    // MARK: - Shimmer List

    private var reportShimmerList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0 ..< 5) { _ in
                    ReportShimmerRow()
                }
            }
            .padding()
        }
        .disabled(true)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image("vital-signs")
                .resizable()
                .frame(width: 80, height: 80)
                .font(.system(size: 80))
                .foregroundColor(.dynamicAccent.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Vital Signs Reports Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(searchText.isEmpty ? "No vital signs reports available yet" : "No reports match your search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Report Download
    
    private func downloadAndShowReport(for report: VitalSignsReport) async {
        do {
            let url = try await reportStore.downloadReport(reportId: report.id)
            await MainActor.run {
                self.pdfURL = url
                self.selectedReportForPDF = report
            }
        } catch {
            await MainActor.run {
                reportStore.errorMessage = "Failed to download report: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Vital Signs Report Row View

struct VitalSignsReportRowView: View {
    let report: VitalSignsReport
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(report.title)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(2)

                            Spacer()

                            Text(report.reportId)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.dynamicAccent)
                                .clipShape(Capsule())
                        }

                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(formatDate(report.createdAt))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "heart.text.square")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Vital Signs Report")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VitalSignsReportListView()
}
