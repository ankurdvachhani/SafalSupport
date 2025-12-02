import SwiftUI
import PDFKit
import CoreImage.CIFilterBuiltins

extension Notification.Name {
    static let RefreshReportList = Notification.Name("RefreshReportList")
    static let ShowReportPDF = Notification.Name("ShowReportPDF")
}

struct IncidentReportListView: View {
    @StateObject private var reportStore: IncidentReportStore
    @State private var searchText = ""
    @State private var selectedSortOption: IncidentReportSortOption = .dateDesc
    @State private var showingSortSheet = false
    @State private var selectedReportForPDF: IncidentReport?
    @State private var pdfURL: URL?
    @State private var selectedReportForBarcode: IncidentReport?
    
    let reportType: String // "incident" or "drainage"
    
    init(reportType: String = "incident") {
        self.reportType = reportType
        self._reportStore = StateObject(wrappedValue: IncidentReportStore(reportType: reportType))
    }

    var body: some View {
        mainContent
            .navigationTitle(reportType == "drainage" ? "Drainage Reports" : "Incident Reports")
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
                       let report = userInfo["report"] as? IncidentReport,
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

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
          //  searchAndSortSection
            contentBody
        }
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

    // MARK: - Filtered Reports

    private var filteredReports: [IncidentReport] {
        var filtered = reportStore.reports

        // Apply sort
        filtered = filtered.sorted(by: selectedSortOption.sortDescriptor)

        return filtered
    }

    // MARK: - Reports List

    private var reportsList: some View {
        List {
            ForEach(filteredReports) { report in
                ReportRowView(report: report) {
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
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.teal.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Reports Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(searchText.isEmpty ? "No incident reports available yet" : "No reports match your search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Report Download
    
    private func downloadAndShowReport(for report: IncidentReport) async {
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

// MARK: - Report Row View

struct ReportRowView: View {
    let report: IncidentReport
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

                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("PDF Report")
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

// MARK: - Supporting Views

struct ReportShimmerRow: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon shimmer
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .shimmerEffectincident()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ReportShimmerBox(width: 150, height: 20)
                        Spacer()
                        ReportShimmerBox(width: 80, height: 16)
                    }

                    HStack {
                        ReportShimmerBox(width: 100, height: 16)
                        Spacer()
                        ReportShimmerBox(width: 60, height: 16)
                    }
                }

                ReportShimmerBox(width: 12, height: 12)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct ReportShimmerBox: View {
    let width: CGFloat
    let height: CGFloat
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmerEffectincident()
    }
}

extension View {
    func shimmerEffectincident() -> some View {
        ShimmerEffectViewincident(content: self)
    }
}

struct ShimmerEffectViewincident<Content: View>: View {
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

struct incidentReportNoSearchResultsView: View {
    let searchText: String
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.teal.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("No reports found for '\(searchText)'")
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
                    .foregroundColor(.teal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Report Sort Sheet

struct incidentReportSortSheet: View {
    @Binding var selectedSortOption: IncidentReportSortOption
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            Text("Sort Report Entries")
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(IncidentReportSortOption.allCases) { option in
                        Button(action: {
                            selectedSortOption = option
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
            .padding()
        }
        .background(Color.dynamicBackground)
        .cornerRadius(20)
    }
}

// MARK: - Preview

// MARK: - Custom PDF Overlay

struct incidentCustomPDFOverlay: View {
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
                        incidentPDFKitView(data: pdfData)
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

struct incidentPDFKitView: UIViewRepresentable {
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

// MARK: - Report Barcode Display View

struct ReportBarcodeDisplayView: View {
    let reportId: String
    @Environment(\.dismiss) private var dismiss
    @State private var isBarcodeGenerated = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Report ID Barcode")
                    .font(.title2)
                    .fontWeight(.semibold)

                if !reportId.isEmpty {
                    VStack(spacing: 16) {
                        BarcodeView(data: reportId)
                            .frame(height: 120)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onAppear {
                                isBarcodeGenerated = true
                            }

                        Text(reportId)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)

                        Text("Scan this barcode to access report details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No report ID available")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("This report doesn't have a barcode ID")
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
            print("ReportBarcodeDisplayView appeared with reportId: \(reportId)")
        }
    }
}

struct IncidentReportListView_Previews: PreviewProvider {
    static var previews: some View {
        IncidentReportListView()
    }
}
