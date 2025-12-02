import SwiftUI
import Foundation

struct UpdateAlertView: View {
    let updateStatus: UpdateStatus
    let version: String
    let onUpdate: () -> Void
    let onLater: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicAccent)
            
            VStack(spacing: 8) {
                Text("New Version Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version \(version) is now available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: onUpdate) {
                    Text("Update Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.dynamicAccent)
                        .cornerRadius(12)
                }
                
                if updateStatus == .normal {
                    Button(action: onLater) {
                        Text("Later")
                            .font(.headline)
                            .foregroundColor(Color.dynamicAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.dynamicAccent, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding()
        .cornerRadius(24)
    }
}

class UpdateAlertViewModel: ObservableObject {
    @Published var isPresented = false
    @Published var updateStatus: UpdateStatus = .none
    @Published var version: String = ""
    
    func checkForUpdates() async {
        do {
            let response = try await UpdateService.shared.checkForUpdates()
            await MainActor.run {
                self.updateStatus = UpdateStatus.from(response.status)
                self.version = response.version
                self.isPresented = self.updateStatus != .none
            }
        } catch {
            Logger.error("Failed to check for updates: \(error)")
        }
    }
    
    func openAppStore() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/YOUR_APP_ID") else { return }
        UIApplication.shared.open(url)
    }
}
