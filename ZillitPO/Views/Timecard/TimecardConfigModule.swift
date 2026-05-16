//
//  TimecardConfigModule.swift
//  ZillitPO
//
//  Scaffold for `TimecardConfigModule.jsx` (1,838 LOC) — accountant-side
//  config: approval-tier matrix, OT defaults, project settings. Visible
//  only when `metadata.is_accountant == true`.
//

import SwiftUI

struct TimecardConfigModule: View {
    @EnvironmentObject var tc: TimecardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Timecard Config").font(.system(size: 14, weight: .semibold))
                Text("Approval-tier matrix, OT defaults and project-wide timecard settings. Full config ports in a follow-up turn.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .padding(.horizontal, 16)
        }
        .navigationBarTitle("Timecard Config", displayMode: .inline)
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
    }
}
