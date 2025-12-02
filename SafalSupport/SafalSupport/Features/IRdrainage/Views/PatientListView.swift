import SwiftUI

struct PatientListView: View {
    @StateObject private var viewModel = PatientSelectionViewModel()
    @State private var selectedSortOption: PatientSortOption = .nameAsc
    @State private var showingSortSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar and buttons row
            HStack(spacing: 12) {
                searchBar
                
                // Sort button
                Button {
                    showingSortSheet = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color.dynamicAccent)
                }
            }
            .padding()
            
            // Content
            ZStack {
                if viewModel.isLoading && viewModel.patients.isEmpty {
                    patientShimmerList
                } else if !viewModel.searchText.isEmpty && filteredPatients.isEmpty {
                    PatientNoSearchResultsView(searchText: viewModel.searchText)
                } else if viewModel.patients.isEmpty {
                    EmptyPatientView()
                } else {
                    patientList
                }
            }
            .navigationTitle("Patients")
        }
        .sheet(isPresented: $showingSortSheet) {
            PatientSortSheet(
                selectedSortOption: $selectedSortOption,
                isPresented: $showingSortSheet
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.searchPatients()
        }
        .toast(message: $viewModel.errorMessage, type: .error)
        .toast(message: $viewModel.successMessage, type: .success)
        .task {
            await viewModel.fetchPatients()
        }
    }
    
    private var patientList: some View {
        List {
            ForEach(filteredPatients) { patient in
                PatientRow(patient: patient)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 Patient tapped - userSlug: \(patient.userSlug), name: \(patient.firstName) \(patient.lastName)")
                   //    NavigationManager.shared.navigate(to: .doctorPatientDashboard(patient: patient))
                        NavigationManager.shared.navigate(
                            to: .drainageListView(patientSlug: patient.userSlug, patientName: patient.firstName + patient.lastName)
                        )
                    }
                    .task {
                        await viewModel.loadMoreIfNeeded(currentPatient: patient)
                    }
            }
        }
        .listStyle(.plain)
        .refreshable {
            try? await Task.sleep(nanoseconds: 500_000_000) // Add a small delay
            await viewModel.refreshPatients()
        }
    }
    
    private var patientShimmerList: some View {
        List {
            ForEach(0..<5) { _ in
                PatientShimmerRow()
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
            
            TextField("Search Patients...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .autocorrectionDisabled()
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
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
    
    private var filteredPatients: [PatientData] {
        var filtered = viewModel.patients
        filtered = filtered.sorted(by: selectedSortOption.sortDescriptor)
        return filtered
    }
}

struct PatientRow: View {
    let patient: PatientData
    @State private var selectedPriority: Priority
    @State private var isUpdatingPriority = false
    @State private var showPriorityUpdateError = false
    @State private var priorityUpdateErrorMessage = ""
    
    private let priorityService = PatientPriorityService()
    
    init(patient: PatientData) {
        self.patient = patient
        self._selectedPriority = State(initialValue: patient.priority)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(patient.firstName) \(patient.lastName)")
                        .font(.headline)
                    
                    Text(patient.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority dropdown
                PriorityDropdownView(
                    selectedPriority: $selectedPriority,
                    onPriorityChanged: { newPriority in
                        Task {
                            await updatePatientPriority(newPriority)
                        }
                    }
                )
                .disabled(isUpdatingPriority)
                .opacity(isUpdatingPriority ? 0.6 : 1.0)
                
            }
            
            if isUpdatingPriority {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Updating priority...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Priority Update Failed", isPresented: $showPriorityUpdateError) {
            Button("OK") { }
        } message: {
            Text(priorityUpdateErrorMessage)
        }
    }
    
    private func updatePatientPriority(_ newPriority: Priority) async {
        guard newPriority != patient.priority else { return }
        
        isUpdatingPriority = true
        
        do {
            let success = try await priorityService.updatePatientPriority(
                patientId: patient.id, patientSlug: patient.userSlug,
                priority: newPriority,
                organizationId: patient.metadata.organizationId ?? "",
                ncpiNumber: patient.metadata.ncpiNumber
            )
            
            if success {
                // Priority updated successfully
                print("✅ Priority updated successfully for patient: \(patient.fullName)")
            } else {
                // API returned success: false
                await MainActor.run {
                    priorityUpdateErrorMessage = "Failed to update priority. Please try again."
                    showPriorityUpdateError = true
                    selectedPriority = patient.priority // Revert to original
                }
            }
        } catch {
            await MainActor.run {
                priorityUpdateErrorMessage = "Error updating priority: \(error.localizedDescription)"
                showPriorityUpdateError = true
                selectedPriority = patient.priority // Revert to original
            }
        }
        
        await MainActor.run {
            isUpdatingPriority = false
        }
    }
}

struct PatientShimmerRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DrainageShimmerBox(width: 150, height: 20)
                Spacer()
                DrainageShimmerBox(width: 80, height: 20)
            }
            
            DrainageShimmerBox(width: 120, height: 16)
        }
        .padding(.vertical, 8)
    }
}

struct PatientNoSearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.dynamicAccent)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No patients found for '\(searchText)'")
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

struct EmptyPatientView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicAccent)
            
            Text("No Patients")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("There are no patients in your organization yet")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PatientSortSheet: View {
    @Binding var selectedSortOption: PatientSortOption
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            Text("Sort Patients")
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 10)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(PatientSortOption.allCases) { option in
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

#Preview {
    PatientListView()
}
