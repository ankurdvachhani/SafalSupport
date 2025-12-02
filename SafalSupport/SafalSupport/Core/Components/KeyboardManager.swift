//
//  KeyboardManager.swift
//  SafalCalendar
//
//  Created by Apple on 05/06/25.
//
import SwiftUI
import Combine

// MARK: - Singleton Keyboard Manager
public class KeyboardManager: ObservableObject {
    public static let shared = KeyboardManager()
    @Published public var keyboardHeight: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
            .sink { [weak self] height in self?.keyboardHeight = height }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
            .sink { [weak self] height in self?.keyboardHeight = height }
            .store(in: &cancellables)
    }
}

// MARK: - Keyboard-Aware View Modifier
struct KeyboardAwareModifier: ViewModifier {
    @ObservedObject private var keyboard = KeyboardManager.shared
    @State private var bottomInset: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .padding(.bottom, bottomInset)
                .onReceive(keyboard.$keyboardHeight) { newHeight in
                    let safeAreaBottom = geometry.safeAreaInsets.bottom
                    let adjusted = max(0, newHeight - safeAreaBottom)
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.bottomInset = adjusted
                    }
                }
        }
    }
}

// MARK: - Tap-to-Dismiss View Modifier
struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.clear) // So tap is detected
            .simultaneousGesture(
                           TapGesture().onEnded {
                               UIApplication.shared.endEditing()
                           }
                       )
    }
}

// MARK: - View Extensions
public extension View {
    func keyboardAware() -> some View {
        self.modifier(KeyboardAwareModifier())
    }

    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTapModifier())
    }
}

// MARK: - UIApplication Extension
#if canImport(UIKit)
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}
#endif
