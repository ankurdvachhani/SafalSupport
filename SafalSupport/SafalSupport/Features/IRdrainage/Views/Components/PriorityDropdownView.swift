import SwiftUI

struct PriorityDropdownView: View {
    @Binding var selectedPriority: Priority
    @State private var showingPrioritySheet = false
    let onPriorityChanged: (Priority) -> Void
    
    var body: some View {
        Button(action: {
            showingPrioritySheet = true
        }) {
            HStack(spacing: 8) {
                // Priority circle
                Circle()
                    .fill(Color(hex: selectedPriority.color))
                    .frame(width: 12, height: 12)
                
                // Priority text
                Text(selectedPriority.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.dynamicAccent)
                
                Spacer()
                
                // Dropdown arrow
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingPrioritySheet) {
            PrioritySelectionSheet(
                selectedPriority: $selectedPriority,
                isPresented: $showingPrioritySheet, onPriorityChanged: onPriorityChanged
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

struct PrioritySelectionSheet: View {
    @Binding var selectedPriority: Priority
    @Binding var isPresented: Bool
    let onPriorityChanged: (Priority) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            // Title
            Text("Select Priority")
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 10)
            
            Divider()
            
            // Priority options
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        Button(action: {
                            selectedPriority = priority
                            onPriorityChanged(priority)
                            isPresented = false
                        }) {
                            HStack(spacing: 12) {
                                // Priority circle
                                Circle()
                                    .fill(Color(hex: priority.color))
                                    .frame(width: 16, height: 16)
                                
                                // Priority text
                                Text(priority.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.dynamicAccent)
                                
                                Spacer()
                                
                                // Checkmark for selected item
                                if priority == selectedPriority {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.dynamicAccent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if priority != Priority.allCases.last {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
            
            // Cancel button
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Text("Cancel")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(Color.dynamicAccent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.dynamicAccent, lineWidth: 2)
                    )
            }
            .padding()
        }
        .background(Color.dynamicBackground)
        .cornerRadius(20)
    }
}

#Preview {
    VStack {
        PriorityDropdownView(
            selectedPriority: .constant(.p1),
            onPriorityChanged: { _ in }
        )
        .padding()
    }
}

