import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: POViewModel

    @State private var showUserPicker = false
    @State private var showPurchaseOrders = false
    @State private var showCardExpenses = false
    @State private var showCashExpenses = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgBase.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Image(systemName: "building.2.fill").font(.system(size: 36)).foregroundColor(.goldDark)
                        Text("Zillit Coda").font(.system(size: 24, weight: .bold))
                        Text("Account Hub").font(.system(size: 13)).foregroundColor(.secondary)
                    }.padding(.top, 60).padding(.bottom, 30)

                    if let user = appState.currentUser {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(Color.gold.opacity(0.2)).frame(width: 50, height: 50)
                                Text(user.initials).font(.system(size: 18, weight: .bold)).foregroundColor(.goldDark)
                            }
                            Text(user.fullName).font(.system(size: 16, weight: .semibold))
                            Text(user.displayDesignation).font(.system(size: 13)).foregroundColor(.secondary)
                            Text(user.displayDepartment).font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue).padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1)).cornerRadius(4)
                        }.padding(.bottom, 30)
                    }

                    VStack(spacing: 12) {
                        Button { showUserPicker = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle").font(.system(size: 20)).foregroundColor(.goldDark).frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Switch User").font(.system(size: 15, weight: .semibold))
                                    Text("Change the active user account").font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
                            }.padding(14).background(Color.white).cornerRadius(12)
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
                            }.padding(14).background(Color.white).cornerRadius(12)
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
                            }.padding(14).background(Color.white).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.56, green: 0.27, blue: 0.68).opacity(0.3), lineWidth: 1))
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
                            }.padding(14).background(Color.white).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.7, blue: 0.45).opacity(0.3), lineWidth: 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(BorderlessButtonStyle())

                    }.padding(.horizontal, 20)

                    Spacer()
                    Text("Zillit Coda · Account Hub").font(.system(size: 10)).foregroundColor(.gray).padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.gold)
        .sheet(isPresented: $showUserPicker) { SidebarView().environmentObject(appState) }
    }
}

// MARK: - PO Hub Page (3 tiles: All POs, Vendors, Invoices)

struct POHubPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToAllPOs = false
    @State private var navigateToVendors = false
    @State private var navigateToInvoices = false

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                // All Purchase Orders tile
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
                    }.padding(14).background(Color.white).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                // Vendors tile
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
                    }.padding(14).background(Color.white).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.35, green: 0.72, blue: 0.36).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                // Invoices tile
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
                    }.padding(14).background(Color.white).cornerRadius(12)
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

extension Color {
    static let gold = Color(red: 252/255, green: 148/255, blue: 4/255)
    static let goldDark = Color(red: 224/255, green: 134/255, blue: 0/255)
    static let bgBase = Color(red: 248/255, green: 249/255, blue: 251/255)
    static let bgRaised = Color(red: 243/255, green: 244/255, blue: 246/255)
    static let borderColor = Color(red: 226/255, green: 228/255, blue: 233/255)
    static let borderSubtle = Color(red: 237/255, green: 240/255, blue: 244/255)
}
