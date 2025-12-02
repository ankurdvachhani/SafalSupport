import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else {
                roleBasedDashboard
            }
        }
        .refreshable {
            await viewModel.refreshDashboard()
        }
        .task {
            await viewModel.loadDashboardData()
        }
    }
    
    @ViewBuilder
    private var roleBasedDashboard: some View {
        let userRole = TokenManager.shared.loadCurrentUser()?.role ?? "Patient"
        
        switch userRole {
        case "Doctor":
            DoctorDashboardView(viewModel: viewModel)
        case "Nurse":
            DoctorDashboardView(viewModel: viewModel)
        case "Patient":
            PatientDashboardView(viewModel: viewModel)
        default:
            DoctorDashboardView(viewModel: viewModel)
           //PatientDashboardView(viewModel: viewModel)
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Dashboard...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
} 
