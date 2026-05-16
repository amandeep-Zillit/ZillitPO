//
//  WeeklyTimecardModule.swift
//  ZillitPO
//
//  Compact scaffold for `WeeklyTimecardModule.jsx` (5,894 LOC in the
//  web client). Shows the current-week grid header and lists the 7
//  days; tap a day → opens the editor in a follow-up turn.
//

import SwiftUI

struct WeeklyTimecardModule: View {
    @EnvironmentObject var tc: TimecardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                weekHeader
                if tc.isLoadingCurrent {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    daysList
                }
            }
            .padding(16)
        }
        .navigationBarTitle("Weekly Timecard", displayMode: .inline)
        .background(Color.bgBase.edgesIgnoringSafeArea(.all))
        .onAppear {
            tc.loadTimecards(weekStarting: tc.weekStartingMs)
        }
    }

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WEEK STARTING")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.8)
            Text(TimecardViewModel.weekOfLabel(tc.weekStartingMs))
                .font(.system(size: 20, weight: .bold))
        }
    }

    private var daysList: some View {
        let card = tc.timecards.first
        let days = card?.days ?? []
        return VStack(spacing: 8) {
            if days.isEmpty {
                emptyDays
            } else {
                ForEach(days) { day in
                    dayRow(day: day)
                }
            }
        }
    }

    private var emptyDays: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No timecard yet for this week.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Start by logging your first day.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func dayRow(day: TimecardDay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimecardViewModel.dayLabel(day.date))
                    .font(.system(size: 13, weight: .semibold))
                Text((day.dayType ?? "work").replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimecardViewModel.hoursLabel(day.hoursWorked))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                if let c = day.callTime, let w = day.wrapTime {
                    Text("\(c) – \(w)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.bgSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}
