import SwiftUI

struct ThemeResponse: Codable {
    let success: Bool
    let backgroundColors: [BackgroundColor]
    let primaryColors: [PrimaryColor]
}

struct BackgroundColor: Codable, Identifiable {
    let bg: String
    let fg: String
    let name: String
    let border: String
    let ring: String
    
    var id: String { name }
    
    var backgroundColor: Color {
        Color(hex: bg)
    }
    
    var foregroundColor: Color {
        Color(hex: fg)
    }
    
    var borderColor: Color {
        Color(hex: border)
    }
    
    var ringColor: Color {
        Color(hex: ring)
    }
}

struct PrimaryColor: Codable, Identifiable {
    let bg: String
    let fg: String
    let fg_dark: String
    let name: String
    let bg300: String
    let bg400: String
    let bg600: String
    let bg700: String
    
    var id: String { name }
    
    var backgroundColor: Color {
        Color(hex: bg)
    }
    
    var foregroundColor: Color {
        Color(hex: fg)
    }
    
    var foregroundDarkColor: Color {
        Color(hex: fg_dark)
    }
    
    var background300: Color {
        Color(hex: bg300)
    }
    
    var background400: Color {
        Color(hex: bg400)
    }
    
    var background600: Color {
        Color(hex: bg600)
    }
    
    var background700: Color {
        Color(hex: bg700)
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 