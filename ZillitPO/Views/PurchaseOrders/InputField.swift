import SwiftUI
import UIKit

struct InputField: View {
    @Binding var text: String
    var placeholder: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 13))
            .keyboardType(keyboard)
            .autocapitalization(keyboard == .emailAddress ? .none : .sentences)
            .disableAutocorrection(keyboard == .emailAddress || keyboard == .phonePad || keyboard == .decimalPad || keyboard == .numberPad)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.bgSurface)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
    }
}
