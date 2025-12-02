import SwiftUI
import WebKit

struct PolicyView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss
    var onAccept: () -> Void
    var onReject: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                WebView(htmlContent: content)
                
                // Bottom buttons
                HStack(spacing: 16) {
                    Button {
                        onReject()
                        dismiss()
                    } label: {
                        Text("Reject")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        onAccept()
                        dismiss()
                    } label: {
                        Text("Accept")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accent)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .withGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onReject()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.accent)
                    }
                }
            }
        }
    }
}

// MARK: - WebView
private struct WebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, system-ui;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #333333;
                    margin: 16px;
                    padding: 0;
                    background-color: transparent;
                }
                * {
                    max-width: 100%;
                    word-wrap: break-word;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #FFFFFF;
                    }
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

// MARK: - Preview
struct PolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PolicyView(
            title: "Terms & Conditions",
            content: "Sample content goes here",
            onAccept: {},
            onReject: {}
        )
    }
} 

struct SettingPolicyView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss
    var onAccept: () -> Void
    var onReject: () -> Void
    
    var body: some View {
            VStack {
                WebView(htmlContent: content)
                
            }
            .withGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title)
    }
}
