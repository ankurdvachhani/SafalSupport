import SwiftUI

struct NoInternetView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Animated Icon
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.dynamicAccent, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                    
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundColor(Color.dynamicAccent)
                }
                .padding(.bottom, 20)
                
                // Title
                Text("No Internet Connection")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                // Description
                Text("Please check your internet connection\nand try again")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Retry Button
                Button(action: {
                    // Trigger network check animation
                    withAnimation {
                        isAnimating = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isAnimating = true
                        }
                    }
                }) {
                    Text("Retry")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 44)
                        .background(Color.dynamicAccent)
                        .cornerRadius(22)
                        .shadow(color: Color.dynamicAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    NoInternetView()
}