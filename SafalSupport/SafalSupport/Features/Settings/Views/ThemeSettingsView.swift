import SwiftUI

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("meetingColor") private var selectedMeetingColorName: String = "Orange"
    @AppStorage("eventColor") private var selectedEventColorName: String = "Green"
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showResetAlert = false
    @State private var showRestartConfirmation = false
    
    var body: some View {
        List {
            // Background Colors Section
//            Section(header: Text("Background Theme")) {
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 12) {
//                        ForEach(themeManager.backgroundColors) { color in
//                            ColorButton(
//                                color: color.backgroundColor,
//                                name: color.name,
//                                isSelected: themeManager.selectedBackgroundColor?.id == color.id
//                            ) {
//                                themeManager.setBackgroundColor(color)
//                            }
//                        }
//                    }
//                    .padding(.horizontal)
//                }
//                .listRowInsets(EdgeInsets())
//                .frame(height: 80)
//            }
            
            // Primary Colors Section
            Section(header: Text("Accent Color")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(themeManager.primaryColors) { color in
                            ColorButton(
                                color: color.backgroundColor,
                                name: color.name,
                                isSelected: themeManager.selectedPrimaryColor?.id == color.id
                            ) {
                                themeManager.setPrimaryColor(color)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .frame(height: 80)
            }
            
            // Meeting Colors Section
            Section(header: Text("Meeting Color")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(themeManager.primaryColors) { color in
                            ColorButton(
                                color: color.backgroundColor,
                                name: color.name,
                                isSelected: selectedMeetingColorName == color.name
                            ) {
                                selectedMeetingColorName = color.name
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .frame(height: 80)
            }
            
            // Event Colors Section
            Section(header: Text("Event Color")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(themeManager.primaryColors) { color in
                            ColorButton(
                                color: color.backgroundColor,
                                name: color.name,
                                isSelected: selectedEventColorName == color.name
                            ) {
                                selectedEventColorName = color.name
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .frame(height: 80)
            }
            
            // Preview Section
            Section(header: Text("Preview")) {
                VStack(spacing: 16) {
                    // Background Preview
                    HStack {
                        Text("Background")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.backgroundColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeManager.borderColor, lineWidth: 1)
                            )
                    }
                    
                    // Accent Preview
                    HStack {
                        Text("Accent")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.accentColor)
                            .frame(width: 40, height: 40)
                    }
                    
                    // Meeting Color Preview
                    HStack {
                        Text("Meeting")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(getMeetingColor())
                            .frame(width: 40, height: 40)
                    }
                    
                    // Event Color Preview
                    HStack {
                        Text("Event")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(getEventColor())
                            .frame(width: 40, height: 40)
                    }
                    
                    // Save Button
                    Button(action: {
                        Task {
                            await saveColors()
                        }
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentForeground))
                            }
                            Text("Save")
                        }
                        .foregroundColor(themeManager.accentForeground)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(themeManager.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSaving)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Theme Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                   showResetAlert = true
                }) {
                    Text("Reset")
                        .foregroundColor(Color.dynamicAccent)
                }
            }
        }
        .alert("Theme Settings", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Reset Theme Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                showRestartConfirmation = true
            }
        } message: {
            Text("Are you sure you want to reset all theme settings to default? This action cannot be undone.")
        }
        .alert("Restart App", isPresented: $showRestartConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                resetThemeSettings()
            }
        } message: {
            Text("The app needs to restart to apply the changes. Do you want to restart now?")
        }
    }
    
    private func getMeetingColor() -> Color {
        themeManager.primaryColors.first(where: { $0.name == selectedMeetingColorName })?.backgroundColor ?? .orange
    }
    
    private func getEventColor() -> Color {
        themeManager.primaryColors.first(where: { $0.name == selectedEventColorName })?.backgroundColor ?? .green
    }
    
    private func saveColors() async {
        isSaving = true
        do {
            try await themeManager.saveColors()
            alertMessage = "Colors saved successfully. App will restart to apply changes."
            showAlert = true
            
            // Delay the restart to allow the alert to be shown
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds delay
            
            // Restart the app
            exit(0)
            
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
        isSaving = false
    }
    
    private func saveResetColors() async {
        isSaving = true
        do {
            try await themeManager.saveResetColors()
            alertMessage = "Colors reset successfully. App will restart to apply changes."
            showAlert = true
            
            // Delay the restart to allow the alert to be shown
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds delay
            
            // Restart the app
            exit(0)
            
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
        isSaving = false
    }
    
    private func resetThemeSettings() {
        // Clear all stored colors
        Task {
            await saveResetColors()
        }
        // Fetch colors again to get the default values
//        Task {
//            await themeManager.fetchColors()
//            
//            // Show success message
//            alertMessage = "Theme settings have been reset to default"
//            showAlert = true
//        }
    }
}

struct ColorButton: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .shadow(radius: 1)
                            }
                        }
                    )
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    NavigationView {
        ThemeSettingsView()
    }
} 
