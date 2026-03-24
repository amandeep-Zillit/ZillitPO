import SwiftUI

struct DateFieldView: View {
    @Binding var hasDate: Bool
    @Binding var date: Date

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        if hasDate {
            HStack(spacing: 10) {
                // Calendar icon
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.goldDark)

                // DatePicker styled as compact — shows formatted date and opens picker on tap
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .accentColor(.goldDark)

                Spacer()

                // Clear button
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { hasDate = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.45))
                }.buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gold.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
            )
        } else {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    date = Date()
                    hasDate = true
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Text("Select a date")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Spacer()

                    Text("dd / mm / yyyy")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
        }
    }
}
