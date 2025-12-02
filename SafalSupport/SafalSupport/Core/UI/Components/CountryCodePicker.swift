import SwiftUI

struct CountryCode: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let flag: String
    
    static let allCountries: [CountryCode] = [
        CountryCode(code: "+91", name: "India", flag: "🇮🇳"),
        CountryCode(code: "+1", name: "United States", flag: "🇺🇸"),
        CountryCode(code: "+44", name: "United Kingdom", flag: "🇬🇧"),
        CountryCode(code: "+61", name: "Australia", flag: "🇦🇺"),
        CountryCode(code: "+86", name: "China", flag: "🇨🇳"),
        CountryCode(code: "+81", name: "Japan", flag: "🇯🇵"),
        CountryCode(code: "+82", name: "South Korea", flag: "🇰🇷"),
        CountryCode(code: "+65", name: "Singapore", flag: "🇸🇬"),
        CountryCode(code: "+971", name: "UAE", flag: "🇦🇪"),
        CountryCode(code: "+966", name: "Saudi Arabia", flag: "🇸🇦")
        // Add more countries as needed
    ]
}

struct CountryCodePicker: View {
    @Binding var selectedCode: String
    @State private var showPicker = false
    @State private var searchText = ""
    private var filteredCountries: [CountryCode] {
        if searchText.isEmpty {
            return CountryCode.allCountries
        }
        return CountryCode.allCountries.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.code.contains(searchText)
        }
    }
    
    private var selectedCountry: CountryCode? {
        CountryCode.allCountries.first { $0.code == selectedCode }
    }
    
    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Text(selectedCountry?.flag ?? "🌐")
                Text(selectedCode)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(width: 100)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color.gray.opacity(0.2) ,
                        lineWidth: 1
                    )
            )
        }
        .sheet(isPresented: $showPicker) {
            NavigationView {
                List {
                    ForEach(filteredCountries) { country in
                        Button {
                            selectedCode = country.code
                            showPicker = false
                        } label: {
                            HStack {
                                Text(country.flag)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(country.name)
                                        .foregroundColor(.primary)
                                    Text(country.code)
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                Spacer()
                                if country.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accent)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search countries")
                .navigationTitle("Select Country")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
} 
