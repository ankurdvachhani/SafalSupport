//
//  ReportsListView.swift
//  SafalCalendar
//
//  Created by Apple on 30/06/25.
//

import SwiftUI

struct ReportsListView: View {
    @StateObject private var viewModel = ReportsListViewModel()
    @State private var searchText = ""
    @State private var showingSortSheet = false
    @State private var showingFilterSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar and sort/filter buttons
//            VStack(spacing: 8) {
//                HStack(spacing: 12) {
//                    searchBar
//                    
//                    // Filter button
//                    Button {
//                        showingFilterSheet = true
//                    } label: {
//                        ZStack {
//                            Image(systemName: "line.3.horizontal.decrease.circle")
//                                .font(.system(size: 22, weight: .medium))
//                                .foregroundColor(Color.dynamicAccent)
//                            
//                            // Red dot indicator for active filters
//                            if viewModel.filters.hasActiveFilters {
//                                Circle()
//                                    .fill(Color.red)
//                                    .frame(width: 8, height: 8)
//                                    .offset(x: 8, y: -8)
//                            }
//                        }
//                    }
//                    
//                    // Sort button
//                    Button {
//                        showingSortSheet = true
//                    } label: {
//                        Image(systemName: "arrow.up.arrow.down.circle")
//                            .font(.system(size: 22, weight: .medium))
//                            .foregroundColor(Color.dynamicAccent)
//                    }
//                }
//                .padding()
//            }
//            .padding(.vertical, 12)
            
            // Content
            if viewModel.isLoading && viewModel.reports.isEmpty {
                reportsShimmerList
            } else if !searchText.isEmpty && filteredReports.isEmpty {
                ReportNoSearchResultsView(searchText: searchText)
            } else if viewModel.reports.isEmpty {
                EmptyReportsView()
            } else {
                reportsList
            }
        }
        .navigationTitle("Activity Log")
        .sheet(isPresented: $showingSortSheet) {
            ReportSortSheet(
                selectedSortOption: $viewModel.filters.sortOption,
                selectedSortOrder: $viewModel.filters.sortOrder,
                isPresented: $showingSortSheet
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showingSortSheet) { isPresented in
            if !isPresented {
                // Apply filters when sort sheet is dismissed
                viewModel.applyFilters()
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            ReportFilterSheet(
                filters: $viewModel.filters,
                isPresented: $showingFilterSheet
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showingFilterSheet) { isPresented in
            if !isPresented {
                // Apply filters when filter sheet is dismissed
                viewModel.applyFilters()
            }
        }
        .onChange(of: searchText) { newValue in
            print("🔎 Search Text Changed to: \(newValue)")
            if newValue.isEmpty {
                // Reset pagination and fetch fresh data when search is cleared
                viewModel.resetPagination()
                Task {
                    await viewModel.fetchReports()
                }
            } else {
                viewModel.searchReports(query: newValue)
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshReports()
            }
        }
        .toast(message: $viewModel.errorMessage, type: .error)
        .toast(message: $viewModel.successMessage, type: .success)
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            TextField("Search by title name...", text: $searchText)
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
    
    private var reportsList: some View {
        ZStack {
            List {
                ForEach(filteredReports) { report in
                    ReportRow(report: report)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .contentShape(Rectangle())
                        .task {
                            // Only trigger pagination for the last item in the original reports array
                            if let lastReport = viewModel.reports.last,
                               report.id == lastReport.id {
                                await viewModel.loadMoreIfNeeded(currentItem: report)
                            }
                        }
                }
                
                // Loading indicator at the bottom
                if viewModel.isLoading && !viewModel.reports.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
                
                // End of list indicator
                if !viewModel.hasMorePages && !viewModel.reports.isEmpty {
                    HStack {
                        Spacer()
                        Text("End of reports")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable {
                try? await Task.sleep(nanoseconds: 500_000_000) // Add a small delay
                await viewModel.refreshReports()
            }
        }
    }
    
    private var reportsShimmerList: some View {
        List {
            ForEach(0..<5) { _ in
                ShimmerReportRow()
            }
        }
        .listStyle(.plain)
        .disabled(true)
    }
    
    private var filteredReports: [Report] {
        print("🔍 Total Reports: \(viewModel.reports.count)")
        return viewModel.reports
    }
}

struct ReportRow: View {
    let report: Report
    @State private var isExpanded = false
    
    // Helper function to format values
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "N/A" }
        
        if let array = value as? [Any] {
            return array.map { String(describing: $0) }.joined(separator: ", ")
        } else if let dateString = value as? String, dateString.contains("T") {
            // Try to format date strings
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                return displayFormatter.string(from: date)
            }
        }
        
        return String(describing: value)
    }
    
    private var moduleIcon: String {
        switch report.module {
        case "incident":
            return "exclamationmark.triangle"
        case "drainage":
            return "drop"
        case "security":
            return "lock.shield"
        default:
            return "doc.text"
        }
    }
    
    private var moduleColor: Color {
        switch report.module {
        case "incident":
            return .orange
        case "drainage":
            return .blue
        case "security":
            return .green
        default:
            return Color.dynamicAccent
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main row with title on left, module and date on right
            HStack(alignment: .top, spacing: 12) {
                // Title - takes most of the space
                Text(report.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side column with module and date
                VStack(alignment: .trailing, spacing: 8) {
                    // Module tag - top right
                    Text(report.module.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(moduleColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    // Timestamp - bottom right
                    Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            // View Changes section - positioned below main content
            if report.newValue != nil || report.oldValue != nil {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with expand/collapse button
                    HStack {
                        Text("View Changes")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "Hide" : "Show")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.accentColor)
                                
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Expandable content
                    if isExpanded {
                        HStack(alignment: .top, spacing: 16) {
                            // Old Values Column
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Old Values")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                                
                                if let oldValue = report.oldValue {
                                    ForEach(Array(oldValue.keys.sorted()), id: \.self) { key in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(key)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                            Text(formatValue(oldValue[key]?.value))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.bottom, 2)
                                    }
                                } else {
                                    Text("N/A")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // New Values Column
                            VStack(alignment: .leading, spacing: 4) {
                                Text("New Values")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                                
                                if let newValue = report.newValue {
                                    ForEach(Array(newValue.keys.sorted()), id: \.self) { key in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(key)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                            Text(formatValue(newValue[key]?.value))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.bottom, 2)
                                    }
                                } else {
                                    Text("N/A")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

struct ShimmerReportRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EventShimmerBox(width: 24, height: 24)
                EventShimmerBox(width: 80, height: 16)
                Spacer()
                EventShimmerBox(width: 100, height: 16)
            }
            
            EventShimmerBox(width: .infinity, height: 20)
            EventShimmerBox(width: .infinity, height: 16)
            EventShimmerBox(width: .infinity, height: 16)
        }
        .padding(.vertical, 8)
    }
}
struct EventShimmerBox: View {
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
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .mask(
                RoundedRectangle(cornerRadius: height/4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.clear, .white, .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .offset(x: isAnimating ? (width == .infinity ? UIScreen.main.bounds.width : width) : -(width == .infinity ? UIScreen.main.bounds.width : width))
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

struct EmptyReportsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicAccent)
            
            Text("No Reports")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("There are no reports to display at this time")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReportNoSearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.dynamicAccent)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No reports found for '\(searchText)'")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Try different keywords")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReportSortSheet: View {
    @Binding var selectedSortOption: ReportSortOption
    @Binding var selectedSortOrder: ReportSortOrder
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Sort Options
                Section(header: Text("Sort By")) {
                    ForEach(ReportSortOption.allCases) { option in
                        HStack {
                            Button(action: {
                                selectedSortOption = option
                            }) {
                                HStack {
                                    Image(systemName: selectedSortOption == option ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedSortOption == option ? .accentColor : .gray)
                                    Text(option.rawValue)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                    }
                }
                
                // Sort Order
                Section(header: Text("Order")) {
                    ForEach(ReportSortOrder.allCases) { order in
                        HStack {
                            Button(action: {
                                selectedSortOrder = order
                            }) {
                                HStack {
                                    Image(systemName: selectedSortOrder == order ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedSortOrder == order ? .accentColor : .gray)
                                    Text(order.displayName)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Sort Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        isPresented = false
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

struct ReportFilterSheet: View {
    @Binding var filters: ReportFilters
    @Binding var isPresented: Bool
    @State private var tempFilters: ReportFilters
    @Environment(\.dismiss) private var dismiss
    
    init(filters: Binding<ReportFilters>, isPresented: Binding<Bool>) {
        self._filters = filters
        self._isPresented = isPresented
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Module Filter
                Section(header: Text("Module")) {
                    ForEach(ReportModuleFilter.allCases) { module in
                        HStack {
                            Button(action: {
                                tempFilters.moduleFilter = module
                            }) {
                                HStack {
                                    Image(systemName: tempFilters.moduleFilter == module ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(tempFilters.moduleFilter == module ? .accentColor : .gray)
                                    Text(module.displayName)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                    }
                }
                
                // Date Range Filter
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: Binding(
                        get: { tempFilters.startDate ?? Date() },
                        set: { tempFilters.startDate = $0 }
                    ), displayedComponents: [.date])
                    
                    DatePicker("End Date", selection: Binding(
                        get: { tempFilters.endDate ?? Date() },
                        set: { tempFilters.endDate = $0 }
                    ), displayedComponents: [.date])
                    
                    if tempFilters.startDate != nil || tempFilters.endDate != nil {
                        Button("Clear Date Range") {
                            tempFilters.startDate = nil
                            tempFilters.endDate = nil
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Filter Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        tempFilters = ReportFilters()
                        filters = tempFilters
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filters = tempFilters
                        isPresented = false
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

#Preview {
    ReportsListView()
}
