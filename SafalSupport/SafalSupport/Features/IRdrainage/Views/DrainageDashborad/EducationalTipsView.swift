import SwiftUI

struct EducationalTipsView: View {
    var tips: [EducationalTip]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if tips.isEmpty {
                    EmptyTipsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(tips) { tip in
                                EducationalTipDetailCard(tip: tip)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Health Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EducationalTipDetailCard: View {
    let tip: EducationalTip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Circle()
                    .fill(tip.category.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: tip.icon)
                            .foregroundColor(tip.category.color)
                            .font(.title2)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(tip.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(tip.category.color)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            
            Text(tip.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Empty State View
struct EmptyTipsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Health Tips Available")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Health tips will appear here when they become available. Check back later for helpful information about your care.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview
struct EducationalTipsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with tips
            EducationalTipsView(tips: [
                EducationalTip(
                    title: "Proper Wound Care",
                    description: "Keep the drainage site clean and dry. Change dressings as instructed by your healthcare provider. This is a longer description to show how the card handles multiple lines of text.",
                    category: .aftercare,
                    icon: "bandage.fill"
                ),
                EducationalTip(
                    title: "Monitor for Infection",
                    description: "Watch for signs of infection: increased redness, swelling, or foul odor.",
                    category: .hygiene,
                    icon: "eye.fill"
                )
            ])
            .previewDisplayName("With Tips")
            
            // Preview with empty state
            EducationalTipsView(tips: [])
                .previewDisplayName("Empty State")
        }
    }
}
