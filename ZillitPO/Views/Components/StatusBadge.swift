//
//  StatusBadge.swift
//  ZillitPO
//
//  Shared status pill used by PO / Invoice / Card / Cash detail
//  screens. Mirrors live's file 1:1.
//

import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .gray) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
