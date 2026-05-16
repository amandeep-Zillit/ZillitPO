//
//  AccountHubAccountantView.swift
//  ZillitPO
//
//  New live-shape entry view. Owns the 5 split VMs as `@StateObject`,
//  binds them (PO/Invoices/Card/Cash hold a weak ref to AccountHub),
//  fires the per-VM bootstrap loads, and injects all VMs into every
//  destination via `environmentObject`.
//
//  When pasted into live, the destination view names (`DepartmentPOModule`,
//  `VendorsModuleView`, etc.) are already correct because the file mirrors
//  live's `AccountHubAccountantView.swift` verbatim.
//

import SwiftUI

struct AccountHubAccountantView: View {

    @StateObject private var hub      = AccountHubViewModel()
    @StateObject private var po       = POViewModel()
    @StateObject private var invoices = InvoicesViewModel()
    @StateObject private var card     = CardViewModel()
    @StateObject private var cash     = CashViewModel()
    @StateObject private var invoiceBadgeViewModel = InvoiceBadgeViewModel()
    @State private var didBind = false

    @Environment(\.presentationMode) var presentationMode

    @State private var navigateToAllPOs = false
    @State private var navigateToVendors = false
    @State private var navigateToInvoices = false
    @State private var navigateToCardExpenses = false
    @State private var navigateToCashExpenses = false

    /// Inject all five VMs into a destination so child views can pull
    /// whichever ones they need via @EnvironmentObject.
    private func injectVMs<V: View>(_ view: V) -> some View {
        view
            .environmentObject(hub)
            .environmentObject(po)
            .environmentObject(invoices)
            .environmentObject(card)
            .environmentObject(cash)
            .environmentObject(invoiceBadgeViewModel)
    }

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    // Purchase Orders tile
                    // Note: the demo's `DepartmentPOModule` is still wired to
                    // `LegacyPOViewModel`. On copy-paste to live, this links
                    // to the post-swap module view that reads the split VMs
                    // via @EnvironmentObject.
                    Text("New AccountHub entry — wiring the 5 split VMs.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 6)

                    accountHubTile(
                        title: "Purchase Orders",
                        subtitle: "View, create and manage POs",
                        icon: "cart.fill",
                        color: .gold,
                        isActive: $navigateToAllPOs
                    )

                    accountHubTile(
                        title: "Vendors",
                        subtitle: "Manage vendor contacts",
                        icon: "person.2.fill",
                        color: Color(red: 0.35, green: 0.72, blue: 0.36),
                        isActive: $navigateToVendors
                    )

                    accountHubTile(
                        title: "Invoices",
                        subtitle: "View and manage invoices",
                        icon: "doc.text.fill",
                        color: Color(red: 0.2, green: 0.6, blue: 0.86),
                        badge: invoiceBadgeViewModel.invoiceBadgesCount,
                        isActive: $navigateToInvoices
                    )

                    accountHubTile(
                        title: "Card Expenses",
                        subtitle: "Track and manage card expenses",
                        icon: "creditcard.fill",
                        color: Color(red: 0.56, green: 0.27, blue: 0.68),
                        isActive: $navigateToCardExpenses
                    )

                    accountHubTile(
                        title: "Cash & Expenses",
                        subtitle: "Petty cash & out-of-pocket claims",
                        icon: "sterlingsign.circle.fill",
                        color: Color(red: 0.2, green: 0.7, blue: 0.45),
                        isActive: $navigateToCashExpenses
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .navigationBarTitle(Text("Account Hub"), displayMode: .inline)
        .onAppear {
            guard !didBind else { return }
            didBind = true
            po.bind(to: hub)
            invoices.bind(to: hub, poVM: po)
            card.bind(to: hub)
            cash.bind(to: hub)
            hub.loadVendors()
            po.loadApprovalTiers()
            invoices.loadInvoiceApprovalTiers()
            invoiceBadgeViewModel.setupObserver()
        }
    }

    /// Single tile shape used five times above. Each tile carries its
    /// own destination `NavigationLink` rendered as a hidden sibling so
    /// the visible button can stay outside the link's tap area (avoids
    /// the iOS 13 chevron + double-tap quirks).
    @ViewBuilder
    private func accountHubTile(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        badge: Int? = nil,
        isActive: Binding<Bool>
    ) -> some View {
        ZStack {
            NavigationLink(destination: destination(for: title), isActive: isActive) { EmptyView() }.hidden()
            Button(action: { isActive.wrappedValue = true }) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 20)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(color).cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 15, weight: .semibold))
                        Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let n = badge, n > 0 { SwiftBadgeView(badgeCount: n) }
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(color)
                }
                .padding(14).background(Color.bgSurface).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }

    /// Demo destination routing. On copy-paste to live these all become
    /// the post-swap module views injected with the split VMs. For the
    /// demo, we route to a placeholder that surfaces the new VMs so the
    /// user can verify the entry compiles + binds correctly without
    /// disturbing the legacy module views (which still drive the
    /// existing ContentView path).
    @ViewBuilder
    private func destination(for title: String) -> some View {
        injectVMs(
            VStack(spacing: 8) {
                Text(title).font(.title3.bold())
                Text("Hooked up via AccountHubAccountantView — split VMs are bound. Live's module views drop in here on copy-paste.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding()
        )
    }
}
