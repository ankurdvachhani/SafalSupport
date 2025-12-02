import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private let defaults = UserDefaults.standard
    
    @Published var selectedBackgroundColor: BackgroundColor?
    @Published var selectedPrimaryColor: PrimaryColor?
    @Published var backgroundColors: [BackgroundColor] = []
    @Published var primaryColors: [PrimaryColor] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let themeService: ThemeServicing
    
    init(themeService: ThemeServicing = ThemeService()) {
        self.themeService = themeService
        loadSavedColors()
        
        // Try to load config from local storage
        if let config = ColorConfig.load() {
            applyConfig(config)
        }
    }
    
//    @MainActor
//    func fetchColors() async {
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            let response = try await themeService.fetchColors()
//            backgroundColors = response.backgroundColors
//            primaryColors = response.primaryColors
//            
//            // After fetching colors, fetch and apply config
//            if let config = try? await themeService.fetchColorConfig() {
//                applyConfig(config)
//            }
//            
//        } catch {
//            self.error = error
//            print("Error fetching colors: \(error)")
//        }
//    }
    
    private func applyConfig(_ config: ColorConfig) {
        // Set background color
//        if let background = backgroundColors.first(where: { $0.name == config.background }) {
//            selectedBackgroundColor = background
//            saveSelectedBackgroundColor(background)
//        }
//        
//        // Set primary color
//        if let primary = primaryColors.first(where: { $0.name == config.primary }) {
//            selectedPrimaryColor = primary
//            saveSelectedPrimaryColor(primary)
//        }
//        
//        // Save meeting and event colors
//        defaults.set(config.meeting, forKey: "meetingColor")
//        defaults.set(config.event, forKey: "eventColor")
    }
    
    func clearStoredColors() {
        // Clear all color-related data from UserDefaults
        defaults.removeObject(forKey: "selectedBackgroundColor")
        defaults.removeObject(forKey: "selectedPrimaryColor")
        
        // Reset @AppStorage values to their defaults
        // Note: We don't remove these values, we set them back to their default values
        // because @AppStorage properties need a value at all times
        defaults.set("Orange", forKey: "meetingColor")
        defaults.set("Green", forKey: "eventColor")
        
        // Clear the stored config
        ColorConfig.clear()
        
        // Reset published properties
        selectedBackgroundColor = nil
        selectedPrimaryColor = nil
        backgroundColors = []
        primaryColors = []
        
        // Note: We don't call saveResetColors() during logout since the token will be invalid
    }
    
    func setBackgroundColor(_ color: BackgroundColor) {
        selectedBackgroundColor = color
        saveSelectedBackgroundColor(color)
    }
    
    func setPrimaryColor(_ color: PrimaryColor) {
        selectedPrimaryColor = color
        saveSelectedPrimaryColor(color)
    }
    
    private func saveSelectedBackgroundColor(_ color: BackgroundColor) {
        if let encoded = try? JSONEncoder().encode(color) {
            defaults.set(encoded, forKey: "selectedBackgroundColor")
        }
    }
    
    private func saveSelectedPrimaryColor(_ color: PrimaryColor) {
        if let encoded = try? JSONEncoder().encode(color) {
            defaults.set(encoded, forKey: "selectedPrimaryColor")
        }
    }
    
    private func loadSavedColors() {
        if let savedBackgroundData = defaults.data(forKey: "selectedBackgroundColor"),
           let savedBackground = try? JSONDecoder().decode(BackgroundColor.self, from: savedBackgroundData) {
            selectedBackgroundColor = savedBackground
        }
        
        if let savedPrimaryData = defaults.data(forKey: "selectedPrimaryColor"),
           let savedPrimary = try? JSONDecoder().decode(PrimaryColor.self, from: savedPrimaryData) {
            selectedPrimaryColor = savedPrimary
        }
    }
    
    @MainActor
    func saveResetColors() async throws {
        try await themeService.saveColors(
            primary: "Teal",
            background: "Stone",
            meeting: "Teal",
            event: "Amber"
        )
    }
    
    @MainActor
    func saveColors() async throws {
        guard let primary = selectedPrimaryColor?.name,
              let background = selectedBackgroundColor?.name else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing required colors"])
        }
        
        let defaults = UserDefaults.standard
        let meeting = defaults.string(forKey: "meetingColor") ?? "Orange"
        let event = defaults.string(forKey: "eventColor") ?? "Green"
        
        try await themeService.saveColors(
            primary: primary,
            background: background,
            meeting: meeting,
            event: event
        )
    }
}

// MARK: - Color Getters
extension ThemeManager {
    var backgroundColor: Color {
        selectedBackgroundColor?.backgroundColor ?? Color(.systemGroupedBackground)
    }
    
    var foregroundColor: Color {
        selectedBackgroundColor?.foregroundColor ?? Color(hex: "#1AB2FF")
    }
    
    var borderColor: Color {
        selectedBackgroundColor?.borderColor ?? Color(hex: "#1AB2FF")
    }
    
    var ringColor: Color {
        selectedBackgroundColor?.ringColor ?? Color(hex: "#4581E4")
    }
    
    var accentColor: Color {
        selectedPrimaryColor?.backgroundColor ?? Color(hex: "#4581E4")
    }
    
    var accentForeground: Color {
        selectedPrimaryColor?.foregroundColor ?? Color(hex: "#4581E4")
    }
    
    var accentForegroundDark: Color {
        selectedPrimaryColor?.foregroundDarkColor ?? Color(hex: "#4581E4")
    }
    
    var accent300: Color {
        selectedPrimaryColor?.background300 ?? Color(hex: "#4581E4")
    }
    
    var accent400: Color {
        selectedPrimaryColor?.background400 ?? Color(hex: "#4581E4")
    }
    
    var accent600: Color {
        selectedPrimaryColor?.background600 ?? Color(hex: "#4581E4")
    }
    
    var accent700: Color {
        selectedPrimaryColor?.background700 ?? Color(hex: "#4581E4")
    }
    
    func getMeetingColor() -> Color {
        let defaults = UserDefaults.standard
        let colorName = defaults.string(forKey: "meetingColor") ?? "Orange"
        return primaryColors.first(where: { $0.name == colorName })?.backgroundColor ?? Color(hex: "#f97316")
    }
    
    func getEventColor() -> Color {
        let defaults = UserDefaults.standard
        let colorName = defaults.string(forKey: "eventColor") ?? "Green"
        return primaryColors.first(where: { $0.name == colorName })?.backgroundColor ?? Color(hex: "#22c55e")
    }
    
    func getMeetingColorScheme() -> PrimaryColor? {
        let defaults = UserDefaults.standard
        let colorName = defaults.string(forKey: "meetingColor") ?? "Orange"
        return primaryColors.first(where: { $0.name == colorName })
    }
    
    func getEventColorScheme() -> PrimaryColor? {
        let defaults = UserDefaults.standard
        let colorName = defaults.string(forKey: "eventColor") ?? "Green"
        return primaryColors.first(where: { $0.name == colorName })
    }
} 
