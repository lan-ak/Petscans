import SwiftUI

extension View {
    /// Dismisses keyboard when tapping outside text fields
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            dismissKeyboard()
        }
    }

    /// Adds a toolbar above the keyboard with Cancel and Done buttons
    func keyboardToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Cancel") {
                    dismissKeyboard()
                }
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}
