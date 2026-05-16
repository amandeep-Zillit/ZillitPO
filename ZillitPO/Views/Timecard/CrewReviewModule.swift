//
//  CrewReviewModule.swift
//  ZillitPO
//
//  Scaffold for `CrewReviewModule.jsx` (998 LOC) — the Review Inbox
//  surface where crew can review/dispute completed timecards before
//  signing off.
//

import SwiftUI

struct CrewReviewModule: View {
    @EnvironmentObject var tc: TimecardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "tray.full")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Review Inbox").font(.system(size: 14, weight: .semibold))
                Text("Completed timecards awaiting your review and sign-off. Full surface ports in a follow-up turn.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .padding(.horizontal, 16)
        }
        .navigationBarTitle("Review Inbox", displayMode: .inline)
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
    }
}
