import SwiftUI

// MARK: - Theme Manager (singleton, drives all Color.xxx tokens)

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "app-theme-dark") }
    }

    private init() {
        self.isDark = UserDefaults.standard.bool(forKey: "app-theme-dark")
    }

    func toggleTheme() { isDark.toggle() }

    // ── Brand colors (matching web ThemeContext.jsx) ──────────────

    var primary: Color {                                             // gold
        Color(red: 252/255, green: 148/255, blue: 4/255)            // #FC9404
    }

    var primaryDark: Color {                                         // goldDark
        Color(red: 224/255, green: 134/255, blue: 0/255)            // #E08600
    }

    // ── Full palette (light / dark from ThemeContext.jsx) ─────────

    var bgBase: Color {          // --bg-base
        isDark ? Color(hex: "#14161B") : Color(hex: "#F8F9FB")
    }

    var bgSurface: Color {       // --bg-surface  (cards, rows)
        isDark ? Color(hex: "#1A1D23") : Color.white
    }

    var bgRaised: Color {        // --bg-raised
        isDark ? Color(hex: "#22262E") : Color(hex: "#F3F4F6")
    }

    var borderColor: Color {     // --border
        isDark ? Color.white.opacity(0.08) : Color(hex: "#E2E4E9")
    }

    var borderSubtle: Color {    // --border-subtle
        isDark ? Color(hex: "#2A2E38") : Color(hex: "#EDF0F4")
    }

    var textPrimary: Color {     // --text
        isDark ? Color(hex: "#E5E7EB") : Color(UIColor.label)
    }

    var textSecondary: Color {   // --text-dim
        isDark ? Color(hex: "#9CA3AF") : Color(UIColor.secondaryLabel)
    }

    var textMuted: Color {       // --text-muted
        isDark ? Color(hex: "#6B7280") : Color(UIColor.tertiaryLabel)
    }
}

// MARK: - Color(hex:) initialiser

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 6: // RGB
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (252, 148, 4, 255) // fallback to gold
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme-aware Color tokens

extension Color {
    static var gold: Color       { ThemeManager.shared.primary }
    static var goldDark: Color   { ThemeManager.shared.primaryDark }
    static var bgBase: Color     { ThemeManager.shared.bgBase }
    static var bgRaised: Color   { ThemeManager.shared.bgRaised }
    static var bgSurface: Color  { ThemeManager.shared.bgSurface }
    static var borderColor: Color { ThemeManager.shared.borderColor }
    static var borderSubtle: Color { ThemeManager.shared.borderSubtle }
}

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var appState: POViewModel
    @ObservedObject private var theme = ThemeManager.shared

    @State private var showUserPicker = false
    @State private var showPurchaseOrders = false
    @State private var showCardExpenses = false
    @State private var showCashExpenses = false

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
    @EnvironmentObject var appState: POViewModel
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
