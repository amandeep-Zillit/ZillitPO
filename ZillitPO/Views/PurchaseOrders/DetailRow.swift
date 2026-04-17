import SwiftUI

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 13))
            Spacer()
        }
    }
}
