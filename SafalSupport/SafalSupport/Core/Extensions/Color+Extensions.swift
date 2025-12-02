import SwiftUI

extension Color {
    static var dynamicBackground: Color {
        ThemeManager.shared.backgroundColor
    }
    
    static var dynamicAccent: Color {
        ThemeManager.shared.accentColor
    }
    
    static var dynamicForeground: Color {
        ThemeManager.shared.foregroundColor
    }
    
    static var dynamicBorder: Color {
        ThemeManager.shared.borderColor
    }
    
    static var dynamicEvent: Color {
        ThemeManager.shared.getEventColor()
    }
    
    static var dynamicMeeting: Color {
        ThemeManager.shared.getMeetingColor()
    }
}

struct DynamicBackgroundStyle: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(Color.dynamicBackground)
    }
}

struct GradientBackgroundStyle: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeManager.backgroundColor.opacity(0.15),
                        themeManager.accentColor.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func withDynamicBackground() -> some View {
        modifier(DynamicBackgroundStyle())
    }
    
    func withGradientBackground() -> some View {
        modifier(GradientBackgroundStyle())
    }
    
    func withThemeColors() -> some View {
        self
            .tint(Color.dynamicAccent)
            .accentColor(Color.dynamicAccent)
    }
} 
