import SwiftUI

struct PatientSelectionView: View {
    @StateObject private var viewModel = PatientSelectionViewModel()
    @Binding var isPresented: Bool
    @Binding var selectedPatientId: String
    @Binding var selectedPatientName: String
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search patients...", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: viewModel.searchText) { _, _ in
                            viewModel.searchPatients()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.searchPatients()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List(viewModel.patients) { patient in
                        Button(action: {
                            selectedPatientId = patient.userSlug
                            selectedPatientName = patient.fullName
                            isPresented = false
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(patient.fullName)
                                    .font(.body)
                                Text(patient.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .task {
                await viewModel.fetchPatients()
            }
        }
    }
}
