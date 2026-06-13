import SwiftUI

extension View {
    /// Presents the standard "Error" alert bound to an optional message; dismissing or tapping OK clears it.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Error", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
