import SwiftUI

struct ToastView: View {
    let message: String
    let type: ToastType
    let show: Bool
    
    enum ToastType {
        case error
        case success
        case warning
        
        var backgroundColor: Color {
            switch self {
            case .error:
                return Color.red.opacity(0.9)
            case .success:
                return Color.green.opacity(0.9)
            case .warning:
                return Color.orange.opacity(0.9)
            }
        }
        
        var icon: String {
            switch self {
            case .error:
                return "exclamationmark.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            }
        }
        
        var duration: TimeInterval {
            switch self {
            case .error:
                return 3.0
            case .success:
                return 2.0
            case .warning:
                return 2.5
            }
        }
    }
    
    var body: some View {
        VStack {
            if show {
                HStack(spacing: 12) {
                    Image(systemName: type.icon)
                        .foregroundColor(.white)
                    
                    Text(message)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(type.backgroundColor)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100) // Ensure it stays on top
            }
            
            Spacer()
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let type: ToastView.ToastType
    
    @State private var workItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            ToastView(
                message: message ?? "",
                type: type,
                show: message != nil
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: message)
        .onChange(of: message) { newMessage in
            if newMessage != nil {
                // Cancel any existing work item
                workItem?.cancel()
                
                // Create a new work item for auto-dismissal
                let task = DispatchWorkItem {
                    withAnimation {
                        message = nil
                    }
                }
                workItem = task
                
                // Schedule the auto-dismissal
                DispatchQueue.main.asyncAfter(deadline: .now() + type.duration, execute: task)
            }
        }
        .onDisappear {
            // Cancel the work item when the view disappears
            workItem?.cancel()
        }
    }
}

extension View {
    func toast(message: Binding<String?>, type: ToastView.ToastType = .error) -> some View {
        modifier(ToastModifier(message: message, type: type))
    }
}

#Preview {
    VStack {
        Text("Content")
            .onTapGesture {
                // Test different toast types
            }
    }
    .toast(message: .constant("This is an error message that might be long and need to wrap to multiple lines"))
} 