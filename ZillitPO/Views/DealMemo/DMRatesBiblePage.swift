//
//  DMRatesBiblePage.swift
//  ZillitPO
//
//  Placeholder. The React `DMRatesBiblePage.jsx` is 874 LOC of nested
//  collapsible rate tables driven by `rates-bible-data.js`. Full port
//  lands in a follow-up turn — for now this surfaces the entry point
//  so the tab compiles and the user knows where the screen will live.
//

import SwiftUI

struct DMRatesBiblePage: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed").font(.system(size: 32)).foregroundColor(.secondary.opacity(0.5))
            Text("Rates Bible").font(.system(size: 14, weight: .semibold))
            Text("Industry rate book — ports in a follow-up turn.")
                .font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 16)
    }
}
