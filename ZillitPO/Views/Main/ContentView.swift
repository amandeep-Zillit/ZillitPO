import SwiftUI

// Theme (ThemeManager + Color tokens) lives in Utils/AccHubThemeManager.swift

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var appState: LegacyPOViewModel
    @ObservedObject private var theme = ThemeManager.shared

    @State private var showUserPicker = false
    @State private var showPurchaseOrders = false
    @State private var showCardExpenses = false
    @State private var showCashExpenses = false
    /// Secondary entry into the new live-shape `AccountHubAccountantView`
    /// (drives `AccountHubViewModel` + the 4 split module VMs). The
    /// existing tiles below still drive the legacy `LegacyPOViewModel`
    /// path so the demo continues to work unchanged.
    @State private var showNewAccountHub = false
    /// Deal Memo entry — mirrors `DealMemoModule.jsx`.
    @State private var showDealMemo = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)

                // GeometryReader supplies the available height so the inner
                // content can stretch to at least the viewport (keeping the
                // "Zillit Coda · Account Hub" footer anchored to the bottom
                // when content fits), while ScrollView handles overflow on
                // smaller devices / large Dynamic Type without clipping.
                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // ── Theme toggle (top-right) ─────────────────
                            HStack {
                                Spacer()
                                Button(action: { theme.toggleTheme() }) {
                                    Image(systemName: theme.isDark ? "sun.max.fill" : "moon.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.goldDark)
                                        .frame(width: 36, height: 36)
                                        .background(Color.gold.opacity(0.12))
                                        .cornerRadius(10)
                                }.buttonStyle(BorderlessButtonStyle())
                            }.padding(.horizontal, 20).padding(.top, 12)

                            VStack(spacing: 6) {
                                Image(systemName: "building.2.fill").font(.system(size: 36)).foregroundColor(.goldDark)
                                Text("Zillit Coda").font(.system(size: 24, weight: .bold))
                                Text("Account Hub").font(.system(size: 13)).foregroundColor(.secondary)
                            }.padding(.top, 20).padding(.bottom, 30)

                            if let user = appState.currentUser {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle().fill(Color.gold.opacity(0.2)).frame(width: 50, height: 50)
                                        Text(user.initials).font(.system(size: 18, weight: .bold)).foregroundColor(.goldDark)
                                    }
                                    Text(user.fullName ?? "").font(.system(size: 16, weight: .semibold))
                                    Text(user.displayDesignation).font(.system(size: 13)).foregroundColor(.secondary)
                                    Text(user.displayDepartment).font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.blue).padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1)).cornerRadius(4)
                                }.padding(.bottom, 30)
                            }

                            VStack(spacing: 12) {
                                // ── New live-shape AccountHub entry ──────
                                NavigationLink(destination: AccountHubAccountantView(), isActive: $showNewAccountHub) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles").font(.system(size: 20)).foregroundColor(.white)
                                            .frame(width: 36, height: 36).background(Color.goldDark).cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Account Hub (live-shape)").font(.system(size: 15, weight: .semibold))
                                            Text("New split-VM entry — mirrors live structure").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.goldDark.opacity(0.4), lineWidth: 1))
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())

                                Button { showUserPicker = true } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.crop.circle").font(.system(size: 20)).foregroundColor(.goldDark).frame(width: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Switch User").font(.system(size: 15, weight: .semibold))
                                            Text("Change the active user account").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
                                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())

                                NavigationLink(destination: POHubPage(), isActive: $showPurchaseOrders) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "cart.fill").font(.system(size: 20)).foregroundColor(.white)
                                            .frame(width: 36, height: 36).background(Color.gold).cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Purchase Orders").font(.system(size: 15, weight: .semibold))
                                            Text("Create, track, and manage POs").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())

                                NavigationLink(destination: CardExpensesModuleView().environmentObject(appState), isActive: $showCardExpenses) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "creditcard.fill").font(.system(size: 20)).foregroundColor(.white)
                                            .frame(width: 36, height: 36).background(Color(red: 0.56, green: 0.27, blue: 0.68)).cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Card Expenses").font(.system(size: 15, weight: .semibold))
                                            Text("Track and manage card expenses").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.56, green: 0.27, blue: 0.68))
                                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.56, green: 0.27, blue: 0.68).opacity(0.3), lineWidth: 1))
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())

                                NavigationLink(destination: DealMemoModule(), isActive: $showDealMemo) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.text.fill").font(.system(size: 20)).foregroundColor(.white)
                                            .frame(width: 36, height: 36).background(Color(red: 0.85, green: 0.45, blue: 0.15)).cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Deal Memo").font(.system(size: 15, weight: .semibold))
                                            Text("Crew contracts, rates and signature workflow").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.15))
                                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.85, green: 0.45, blue: 0.15).opacity(0.3), lineWidth: 1))
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())

                                NavigationLink(destination: CashExpensesHubView().environmentObject(appState), isActive: $showCashExpenses) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sterlingsign.circle.fill").font(.system(size: 20)).foregroundColor(.white)
                                            .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.7, blue: 0.45)).cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Cash & Expenses").font(.system(size: 15, weight: .semibold))
                                            Text("Petty cash & out-of-pocket claims").font(.system(size: 12)).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.45))
                                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.7, blue: 0.45).opacity(0.3), lineWidth: 1))
                                    .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())

                            }.padding(.horizontal, 20)

                            Spacer(minLength: 24)
                            Text("Zillit Coda · Account Hub").font(.system(size: 10)).foregroundColor(.gray).padding(.bottom, 16)
                        }
                        // Stretch to at least the viewport so the footer stays
                        // pinned at the bottom on tall devices where content
                        // doesn't overflow. Content still scrolls past this
                        // height when it grows beyond the viewport.
                        .frame(minHeight: proxy.size.height)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.gold)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .sheet(isPresented: $showUserPicker) {
            SidebarView().environmentObject(appState)
                .environment(\.colorScheme, theme.isDark ? .dark : .light)
        }
    }
}

// MARK: - PO Hub Page (3 tiles: All POs, Vendors, Invoices)

struct POHubPage: View {
    @EnvironmentObject var appState: LegacyPOViewModel
    @State private var navigateToAllPOs = false
    @State private var navigateToVendors = false
    @State private var navigateToInvoices = false

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                NavigationLink(destination: DepartmentPOModule(), isActive: $navigateToAllPOs) { EmptyView() }.hidden()
                Button(action: { navigateToAllPOs = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.gold).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Purchase Orders").font(.system(size: 15, weight: .semibold))
                            Text("View, create and manage POs").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                NavigationLink(destination: VendorsModuleView().environmentObject(appState), isActive: $navigateToVendors) { EmptyView() }.hidden()
                Button(action: { navigateToVendors = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color(red: 0.35, green: 0.72, blue: 0.36)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vendors").font(.system(size: 15, weight: .semibold))
                            Text("Manage vendor contacts").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.35, green: 0.72, blue: 0.36))
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.35, green: 0.72, blue: 0.36).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                NavigationLink(destination: InvoicesModuleView().environmentObject(appState), isActive: $navigateToInvoices) { EmptyView() }.hidden()
                Button(action: { navigateToInvoices = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.6, blue: 0.86)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invoices").font(.system(size: 15, weight: .semibold))
                            Text("View and manage invoices").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.86))
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.6, blue: 0.86).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationBarTitle(Text("Account Hub"), displayMode: .inline)
    }
}
