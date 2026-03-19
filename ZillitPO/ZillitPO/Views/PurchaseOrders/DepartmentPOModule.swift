import SwiftUI

struct DepartmentPOModule: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            mainBody
        }
        .navigationBarTitle(Text(appState.showCreatePO || appState.editingPO != nil ? "Create PO" : "Purchase Orders"), displayMode: .inline)
        .navigationBarBackButtonHidden(appState.showCreatePO || appState.editingPO != nil)
        .navigationBarItems(leading: (appState.showCreatePO || appState.editingPO != nil) ?
            AnyView(Button(action: { appState.showCreatePO = false; appState.editingPO = nil; appState.resumeDraft = nil }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }) : AnyView(EmptyView())
        )
        .sheet(isPresented: $appState.showRejectSheet) { RejectSheetView().environmentObject(appState) }
        .alert(isPresented: .init(get: { appState.deleteTarget != nil }, set: { if !$0 { appState.deleteTarget = nil } })) {
            Alert(title: Text("Delete PO?"), message: Text("This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) { if let t = appState.deleteTarget { appState.deletePO(t) } },
                  secondaryButton: .cancel())
        }
    }

    @ViewBuilder
    private var mainBody: some View {
        if appState.showCreatePO || appState.editingPO != nil {
            POFormView(editingPO: appState.editingPO, resumeDraft: appState.resumeDraft,
                       onBack: { appState.showCreatePO = false; appState.editingPO = nil; appState.resumeDraft = nil })
        } else {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        tabBar
                        tabContent
                    }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 80)
                }

                // Floating Create PO button
                Button(action: { appState.showCreatePO = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("Create PO").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.gold)
                    .cornerRadius(28)
                    .shadow(color: Color.gold.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRANSACTIONS").font(.system(size: 10, weight: .semibold)).foregroundColor(.goldDark)
            Text("Purchase Orders").font(.system(size: 26, weight: .bold))
            Text("Create, track, and manage purchase orders for your department.").font(.system(size: 13)).foregroundColor(.secondary)
        }
    }

    private var userInfo: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.gold.opacity(0.2)).frame(width: 30, height: 30)
                Text(appState.currentUser?.initials ?? "?").font(.system(size: 10, weight: .bold)).foregroundColor(.goldDark)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(appState.currentUser?.fullName ?? "").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(appState.currentUser?.displayDesignation ?? "").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(appState.currentUser?.displayDepartment ?? "").font(.system(size: 9, weight: .bold)).lineLimit(1)
                .foregroundColor(.blue).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).cornerRadius(4)
        }.padding(10).background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach([DeptTab.all, .my, .department, .vendors], id: \.self) { tabButton($0) }
                Spacer().frame(width: 8)
                ForEach([DeptTab.templates, .drafts], id: \.self) { tabButton($0) }
            }
        }.overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)
    }

    private func tabButton(_ tab: DeptTab) -> some View {
        Button(action: { appState.activeTab = tab; appState.activeFilter = .all }) {
            HStack(spacing: 4) {
                Text(tab.rawValue).font(.system(size: 12, weight: appState.activeTab == tab ? .semibold : .regular)).lineLimit(1).fixedSize()
                if let count = appState.tabCounts[tab] {
                    Text("\(count)").font(.system(size: 9, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 2)
                        .background(appState.activeTab == tab ? Color.gold.opacity(0.2) : Color.bgRaised).cornerRadius(10)
                }
            }.foregroundColor(appState.activeTab == tab ? .goldDark : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 10)
            .overlay(appState.activeTab == tab ? Rectangle().fill(Color.goldDark).frame(height: 2) : nil, alignment: .bottom)
        }.buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch appState.activeTab {
        case .all, .my, .department:
            QuickFiltersBar()
            if appState.isLoading && appState.purchaseOrders.isEmpty { LoaderView() }
            else { POStatsCards(); POTableView() }
        case .vendors: VendorsModuleView()
        case .templates: POTemplatesListView()
        case .drafts: PODraftsListView()
        }
    }
}
