//
//  TimecardLandingModule.swift
//  ZillitPO
//
//  Time-card module entry. Mirrors `TimecardLandingModule.jsx` — a
//  6-card grid of sub-modules (role-gated via `TimecardMetadata`) plus
//  an embedded Daily Login section at the bottom.
//

import SwiftUI

struct TimecardLandingModule: View {
    @StateObject private var tc = TimecardViewModel()
    @State private var didBoot = false

    /// One-binding-per-destination for iOS 15 push navigation.
    @State private var pushView: TimecardLandingView? = nil

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    cardGrid
                    dailyLoginSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            navigationLinks
        }
        .navigationBarTitle(Text("Time Cards"), displayMode: .inline)
        .environmentObject(tc)
        .onAppear {
            guard !didBoot else { return }
            didBoot = true
            tc.bootstrap()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TIMECARDS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.8)
            Text("Time Cards")
                .font(.system(size: 20, weight: .bold))
            Text("Manage your weekly timecards, daily logins, approvals and timecard configuration.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 2-column card grid

    private var cardGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10),
                      GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(tc.visibleLandingViews) { view in
                TimecardLandingCard(view: view) { pushView = view }
            }
        }
    }

    // MARK: - Daily login section

    private var dailyLoginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.goldDark)
                Text("Daily Login")
                    .font(.system(size: 14, weight: .bold))
                Text("—").foregroundColor(.secondary.opacity(0.5))
                Text(TimecardViewModel.longDateLabel(Date()))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 4)

            DailyLoginInlineSection().environmentObject(tc)
        }
    }

    // MARK: - Push links (one per sub-module)

    @ViewBuilder
    private var navigationLinks: some View {
        ForEach(TimecardLandingView.allCases) { v in
            NavigationLink(
                destination: destination(v),
                tag: v,
                selection: $pushView
            ) { EmptyView() }.hidden()
        }
    }

    @ViewBuilder
    private func destination(_ v: TimecardLandingView) -> some View {
        switch v {
        case .weekly:            WeeklyTimecardModule().environmentObject(tc)
        case .myTimecards:       MyTimecardsModule().environmentObject(tc)
        case .approvalQueue:     TCApprovalQueuePage().environmentObject(tc)
        case .assignedTimecards: AssignedTimecardsModule().environmentObject(tc)
        case .crewReview:        CrewReviewModule().environmentObject(tc)
        case .timecardConfig:    TimecardConfigModule().environmentObject(tc)
        }
    }
}

// MARK: - Card

private struct TimecardLandingCard: View {
    let view: TimecardLandingView
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.opacity(0.12))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.3), lineWidth: 1)
                    Image(systemName: view.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tint)
                }
                .frame(width: 32, height: 32)
                Text(view.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.goldDark.opacity(0.7))
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(Color.bgSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
        }
        .buttonStyle(BorderlessButtonStyle())
    }

    private var tint: Color { Color(hex: view.tintHex) }
}

// MARK: - Embedded daily-login section

private struct DailyLoginInlineSection: View {
    @EnvironmentObject var tc: TimecardViewModel

    private var isLoggedIn: Bool {
        (tc.dailyLoginToday?.status == "logged_in")
    }

    private var loggedOut: Bool {
        (tc.dailyLoginToday?.status == "logged_out")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusBadge
                Spacer()
                if let h = tc.dailyLoginToday?.hoursWorked, h > 0 {
                    Text(TimecardViewModel.hoursLabel(h))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.goldDark)
                }
            }

            HStack(spacing: 16) {
                stamp("Logged in",   ms: tc.dailyLoginToday?.loginDetails?.timestamp)
                Divider().frame(height: 36)
                stamp("Logged out",  ms: tc.dailyLoginToday?.logoutDetails?.timestamp)
            }

            HStack(spacing: 10) {
                Button(action: { tc.loginNow() }) {
                    Text(isLoggedIn || loggedOut ? "Logged in" : "Log in now")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(isLoggedIn || loggedOut ? Color.gray.opacity(0.15) : Color.goldDark)
                        .foregroundColor(isLoggedIn || loggedOut ? .secondary : .white)
                        .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isLoggedIn || loggedOut)

                Button(action: { tc.logoutNow() }) {
                    Text(loggedOut ? "Logged out" : "Log out")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isLoggedIn ? Color.goldDark : Color.borderColor, lineWidth: 1))
                        .foregroundColor(isLoggedIn ? .goldDark : .secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(!isLoggedIn)
            }
        }
        .padding(14)
        .background(Color.bgSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderColor, lineWidth: 1))
    }

    private var statusBadge: some View {
        let label: String
        let color: Color
        if loggedOut       { label = "Logged out — \(TimecardViewModel.hoursLabel(tc.dailyLoginToday?.hoursWorked))"; color = Color(red: 0.21, green: 0.64, blue: 0.37) }
        else if isLoggedIn { label = "Currently logged in";  color = Color(red: 0.21, green: 0.64, blue: 0.37) }
        else               { label = "Not logged in yet";    color = .secondary }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
        }
    }

    private func stamp(_ label: String, ms: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.4)
            Text(formatTime(ms))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
    }

    private func formatTime(_ ms: Int64?) -> String {
        guard let ms = ms, ms > 0 else { return "—" }
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
