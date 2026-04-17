import SwiftUI

struct DropdownOption: Identifiable {
    let id: String
    let label: String
    init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

struct PickerField: View {
    @Binding var selection: String
    var placeholder: String
    var options: [DropdownOption]
    @State private var showSheet = false

    private var selectedLabel: String {
        options.first { $0.id == selection }?.label ?? ""
    }

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack {
                Text(selection.isEmpty ? placeholder : selectedLabel)
                    .font(.system(size: 13))
                    .foregroundColor(selection.isEmpty ? .gray : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.bgSurface)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
        }
        .buttonStyle(BorderlessButtonStyle())
        .sheet(isPresented: $showSheet) {
            PickerSheetView(selection: $selection, options: options, isPresented: $showSheet)
        }
    }
}
