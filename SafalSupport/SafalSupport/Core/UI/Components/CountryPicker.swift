import SwiftUI

struct CountryPicker: View {
    @Binding var selectedCountry: String
    let error: String?
    
    private let countries = [
       // "IND": "India",
        "USA": "United States"
        // Add more countries as needed
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                ForEach(countries.sorted(by: { $0.value < $1.value }), id: \.key) { code, name in
                    Button {
                        selectedCountry = code
                    } label: {
                        HStack {
                            Text(name)
                            if selectedCountry == code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedCountry.isEmpty ? "Select Country" : (countries[selectedCountry] ?? selectedCountry))
                        .foregroundColor(selectedCountry.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error == nil ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                )
            }
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}


struct RolePicker: View {
    @Binding var selectedRole: String
    let error: String?

    private let roles = [
        "Admin",
        "Employee",
        "Individual"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                ForEach(roles, id: \.self) { role in
                    Button {
                        selectedRole = role
                    } label: {
                        HStack {
                            Text(role)
                            if selectedRole == role {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedRole.isEmpty ? "Select Role" : selectedRole)
                        .foregroundColor(selectedRole.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error == nil ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                )
            }

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}
