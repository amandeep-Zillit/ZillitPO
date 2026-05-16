//
//  AssignedTimecardsModule.swift
//  ZillitPO
//
//  Scaffold for `AssignedTimecardsModule.jsx` (2,834 LOC) — completer's
//  view of the crew members they're assigned to complete timecards
//  for. Visible only when `metadata.is_completer == true`.
//

import SwiftUI

struct AssignedTimecardsModule: View {
    @EnvironmentObject var tc: TimecardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                placeholder
            }
            .padding(16)
        }
        .navigationBarTitle("Assigned Timecards", displayMode: .inline)
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Assigned Timecards")
                .font(.system(size: 14, weight: .semibold))
            Text("Crew members you've been assigned to complete timecards for. Full coordinator surface ports in a follow-up turn.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
