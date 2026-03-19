import SwiftUI
import Combine

enum DeleteAlertType: Identifiable {
    case po(PurchaseOrder)
    case template(String)
    case draft(String)
    case vendor(String)
    var id: String {
        switch self {
        case .po(let p): return "po-\(p.id)"
        case .template(let id): return "tpl-\(id)"
        case .draft(let id): return "dft-\(id)"
        case .vendor(let id): return "vnd-\(id)"
        }
    }
}

struct DepartmentPOModule: View {
    @EnvironmentObject var appState: AppState
    @State private var navigateToForm = false
    @State private var activeDeleteAlert: DeleteAlertType?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Pinned tab bar
                tabBar.padding(.horizontal, 16).padding(.top, 12)
                    .background(Color.bgBase)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        tabContent
                    }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                }
            }

            // Floating Create PO button
            Button(action: {
                appState.editingPO = nil
                appState.resumeDraft = nil
                navigateToForm = true
            }) {
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

            // Hidden NavigationLink to push form page
            NavigationLink(
                destination: POFormPage(
                    editingPO: appState.editingPO,
                    resumeDraft: appState.resumeDraft
                ).environmentObject(appState),
                isActive: $navigateToForm
            ) { EmptyView() }
            .hidden()
        }
        .navigationBarTitle(Text("Purchase Orders"), displayMode: .inline)
        .sheet(isPresented: $appState.showRejectSheet) { RejectSheetView().environmentObject(appState) }
        .alert(isPresented: .init(get: { activeDeleteAlert != nil }, set: { if !$0 { activeDeleteAlert = nil } })) {
            switch activeDeleteAlert {
            case .po(let po):
                return Alert(title: Text("Delete PO?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deletePO(po) },
                      secondaryButton: .cancel())
            case .template(let id):
                return Alert(title: Text("Delete Template?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deleteTemplate(id) },
                      secondaryButton: .cancel())
            case .draft(let id):
                return Alert(title: Text("Delete Draft?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deleteDraft(id) },
                      secondaryButton: .cancel())
            case .vendor(let id):
                return Alert(title: Text("Delete Vendor?"), message: Text("This cannot be undone."),
                      primaryButton: .destructive(Text("Delete")) { appState.deleteVendor(id) },
                      secondaryButton: .cancel())
            case .none:
                return Alert(title: Text("Delete?"))
            }
        }
        .onReceive(appState.$deleteTarget) { po in
            if let po = po { activeDeleteAlert = .po(po); appState.deleteTarget = nil }
        }
        .onReceive(appState.$deleteTemplateId) { id in
            if let id = id { activeDeleteAlert = .template(id); appState.deleteTemplateId = nil }
        }
        .onReceive(appState.$deleteDraftId) { id in
            if let id = id { activeDeleteAlert = .draft(id); appState.deleteDraftId = nil }
        }
        .onReceive(appState.$deleteVendorId) { id in
            if let id = id { activeDeleteAlert = .vendor(id); appState.deleteVendorId = nil }
        }
        .onReceive(appState.$editingPO) { po in
            if po != nil { navigateToForm = true }
        }
        .onReceive(appState.$resumeDraft) { draft in
            if draft != nil { navigateToForm = true }
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

// MARK: - PO Form Page (Navigation destination)

struct POFormPage: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    var editingPO: PurchaseOrder?
    var resumeDraft: PurchaseOrder?
    var prefilledVendorId: String?

    private var title: String {
        if editingPO != nil { return "Edit PO" }
        if resumeDraft != nil { return "Resume Draft" }
        return "Create PO"
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            POFormView(
                editingPO: editingPO,
                resumeDraft: resumeDraft,
                prefilledVendorId: prefilledVendorId,
                onBack: { presentationMode.wrappedValue.dismiss() }
            )
        }
        .navigationBarTitle(Text(title), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onDisappear {
            appState.editingPO = nil
            appState.resumeDraft = nil
            appState.showCreatePO = false
            appState.prefilledVendorId = nil
        }
    }
}
