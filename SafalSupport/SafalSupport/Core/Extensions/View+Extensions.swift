import SwiftUI
import Foundation

extension View {
    func errorAlert(error: Binding<Error?>, buttonTitle: String = "OK") -> some View {
        let localizedError = error.wrappedValue?.localizedDescription ?? ""
        return alert(isPresented: .constant(error.wrappedValue != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(localizedError),
                dismissButton: .default(Text(buttonTitle)) {
                    error.wrappedValue = nil
                }
            )
        }
    }
    
    @ViewBuilder
    func loadingOverlay(isLoading: Bool) -> some View {
        if isLoading {
            self.overlay {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        } else {
            self
        }
    }
    
    func embedInNavigation() -> some View {
        NavigationView { self }
    }
    func delay(_ seconds: Double) async {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

