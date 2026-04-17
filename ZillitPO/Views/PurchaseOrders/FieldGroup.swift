import SwiftUI

struct FieldGroup<Content: View>: View {
    var label: String
    var optional: Bool = false
    let content: () -> Content
    init(label: String, optional: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.label = label; self.optional = optional; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if optional {
                        Text("(optional)")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                            .italic()
                            .lineLimit(1)
                    }
                }
            }
            content()
        }
    }
}
