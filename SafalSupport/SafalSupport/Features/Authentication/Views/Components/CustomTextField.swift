import SwiftUI

struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var error: String?
    var isSecure: Bool = false
    @Binding var showSecureText: Bool
    var isDisabled: Bool = false
    var onChange: ((String) -> Void)?
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        error: String? = nil,
        isSecure: Bool = false,
        showSecureText: Binding<Bool> = .constant(false),
        isDisabled: Bool = false,
        onChange: ((String) -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.error = error
        self.isSecure = isSecure
        self._showSecureText = showSecureText
        self.isDisabled = isDisabled
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack {
                if isSecure {
                    if showSecureText {
                        TextField(placeholder, text: $text)
                            .onChange(of: text) { newValue in
                                onChange?(newValue)
                            }
                            .disabled(isDisabled)
                    } else {
                        SecureField(placeholder, text: $text)
                            .onChange(of: text) { newValue in
                                onChange?(newValue)
                            }
                            .disabled(isDisabled)
                    }
                } else {
                    TextField(placeholder, text: $text)
                        .onChange(of: text) { newValue in
                            onChange?(newValue)
                        }
                        .disabled(isDisabled)
                }
                
                if isSecure {
                    Button(action: {
                        showSecureText.toggle()
                    }) {
                        Image(systemName: showSecureText ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isDisabled ? Color(.systemGray5) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        error == nil ? Color.gray.opacity(0.2) : Color.red,
                        lineWidth: 1
                    )
            )
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    VStack {
        CustomTextField(
            title: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            error: nil
        )
        
        CustomTextField(
            title: "Password",
            placeholder: "Enter your password",
            text: .constant(""),
            error: "Password is too short",
            isSecure: true,
            showSecureText: .constant(false)
        )
    }
    .padding()
} 
