//
//  CashExpensesModuleView.swift
//  ZillitPO
//

import SwiftUI

// MARK: - File-scope helpers (shared across all views in this file)

/// Maps a float status string to (foreground, background) colors used for
/// status badges. Mirrors the backend FloatRequestService state machine:
///   AWAITING_APPROVAL → APPROVED/ACCT_OVERRIDE → READY_TO_COLLECT → COLLECTED →
///   ACTIVE/SPENDING/SPENT/PENDING_RETURN → CLOSED/CANCELLED/REJECTED
///
/// Every status has a distinct color so two different states never look alike
/// in the badge list (e.g. AWAITING_APPROVAL was previously confused with
/// PENDING_RETURN because both used orange).
func floatStatusColors(_ s: String) -> (Color, Color) {
    let teal  = Color(red: 0.0,  green: 0.6,  blue: 0.5)   // #009980  — collected (got cash)
    let pink  = Color(red: 0.91, green: 0.29, blue: 0.48)  // #E84A7A  — pending return (needs physical action)
    let amber = Color(red: 0.95, green: 0.6,  blue: 0.0)   // #F29A00  — awaiting approval
    switch s.uppercased() {
    case "AWAITING_APPROVAL":   return (amber, amber.opacity(0.12))              // amber — awaiting review
    case "APPROVED",
         "ACCT_OVERRIDE":       return (.green, Color.green.opacity(0.12))       // green — approved
    case "READY_TO_COLLECT":    return (.blue, Color.blue.opacity(0.12))         // blue  — crew action needed
    case "COLLECTED":           return (teal, teal.opacity(0.12))                // teal  — cash in hand
    case "ACTIVE",
         "SPENDING":            return (.goldDark, Color.gold.opacity(0.15))     // gold  — in-use
    case "SPENT":               return (.purple, Color.purple.opacity(0.12))     // purple— out of cash
    case "PENDING_RETURN":      return (pink, pink.opacity(0.12))                // pink  — return required
    case "CLOSED":              return (.gray, Color.gray.opacity(0.12))         // gray  — terminal ok
    case "CANCELLED",
         "REJECTED":            return (.red, Color.red.opacity(0.1))            // red   — terminal bad
    default: return (.goldDark, Color.gold.opacity(0.15))
    }
}

// MARK: - Cash & Expenses Hub (2 tiles: Petty Cash, Out of Pocket)

struct CashExpensesHubView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToPettyCash = false
    @State private var navigateToOOP = false
    @State private var navigateToAuditQueue = false
    @State private var navigateToApprovalQueue = false
    @State private var navigateToCodingQueue = false

    private var isAcct: Bool { appState.currentUser?.isAccountant == true }
    private var isCoord: Bool { appState.cashMeta?.isCoordinator == true }

    private var auditClaims: [ClaimBatch] { appState.auditQueue }
    private var approvalClaims: [ClaimBatch] { appState.approvalQueueClaims }
    private var approvalQueueTotal: Int { appState.approvalQueueFloats.count + appState.approvalQueueClaims.count }
    private var codingClaims: [ClaimBatch] { appState.codingQueue }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 12) {
                    // Petty Cash tile
                    NavigationLink(destination: PettyCashModuleView().environmentObject(appState), isActive: $navigateToPettyCash) { EmptyView() }.hidden()
                    Button(action: { navigateToPettyCash = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "banknote.fill").font(.system(size: 20)).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.7, blue: 0.45)).cornerRadius(8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Petty Cash").font(.system(size: 15, weight: .semibold))
                                Text("Manage floats, submit & track claims").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.45))
                        }.padding(14).background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.7, blue: 0.45).opacity(0.3), lineWidth: 1))
                        .contentShape(Rectangle())
                    }.buttonStyle(BorderlessButtonStyle())

                    // Out of Pocket tile
                    NavigationLink(destination: OutOfPocketModuleView().environmentObject(appState), isActive: $navigateToOOP) { EmptyView() }.hidden()
                    Button(action: { navigateToOOP = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "wallet.pass.fill").font(.system(size: 20)).foregroundColor(.white)
                                .frame(width: 36, height: 36).background(Color(red: 0.56, green: 0.27, blue: 0.68)).cornerRadius(8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Out of Pocket").font(.system(size: 15, weight: .semibold))
                                Text("Submit & track reimbursement claims").font(.system(size: 12)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.56, green: 0.27, blue: 0.68))
                        }.padding(14).background(Color.bgSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.56, green: 0.27, blue: 0.68).opacity(0.3), lineWidth: 1))
                        .contentShape(Rectangle())
                    }.buttonStyle(BorderlessButtonStyle())

                    // Approval Queue tile (accountant + coordinator)
                    if isAcct || isCoord {
                        NavigationLink(destination: ApprovalQueuePage().environmentObject(appState), isActive: $navigateToApprovalQueue) { EmptyView() }.hidden()
                        Button(action: { navigateToApprovalQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color.goldDark).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Approval Queue").font(.system(size: 15, weight: .semibold))
                                        if approvalQueueTotal > 0 {
                                            Text("\(approvalQueueTotal)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.goldDark).cornerRadius(8)
                                        }
                                    }
                                    Text("Approve or reject pending floats & claims").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                            }.padding(14).background(Color.bgSurface).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())
                    }

                    // Coordinator-only tiles
                    if isCoord && !isAcct {
                        // Coding Queue tile
                        NavigationLink(
                            destination: CodingQueueListView(claims: codingClaims, isLoading: appState.isLoadingCodingQueue).environmentObject(appState)
                                .navigationBarTitle(Text("Coding Queue"), displayMode: .inline)
                                .onAppear { appState.loadCodingQueue() },   // GET /cash-expenses/claims/coding-queue
                            isActive: $navigateToCodingQueue
                        ) { EmptyView() }.hidden()
                        Button(action: { navigateToCodingQueue = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 20)).foregroundColor(.white)
                                    .frame(width: 36, height: 36).background(Color.blue).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Coding Queue").font(.system(size: 15, weight: .semibold))
                                        if !codingClaims.isEmpty {
                                            Text("\(codingClaims.count)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.blue).cornerRadius(8)
                                        }
                                    }
                                    Text("Claims awaiting budget coding").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.blue)
                            }.padding(14).background(Color.bgSurface).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())

                    }

                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Cash & Expenses"), displayMode: .inline)
        .onAppear {
            // Only metadata — each tile loads its own data on appear
            appState.loadCashExpenseMetadata()
        }
    }
}
