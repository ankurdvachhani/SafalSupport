//
//  Untitled.swift
//  SafalCalendar
//
//  Created by Apple on 24/06/25.
//
import SwiftUI
import Foundation

// MARK: - Custom Text Fields
struct CustomIntegrationTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @State private var isEditing: Bool = false
    @State private var showPassword: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
                
                if isSecure {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEditing ? Color.dynamicAccent : Color.clear, lineWidth: 1)
                    )
            )
            .onTapGesture {
                isEditing = true
            }
            .onSubmit {
                isEditing = false
            }
        }
    }
}
