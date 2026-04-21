import SwiftUI

enum DraftsTemplatesTab: String, CaseIterable {
    case drafts = "Drafts"
    case templates = "Templates"
}

struct DraftsTemplatesPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var activeTab: DraftsTemplatesTab = .drafts
    @State private var navigateToForm = false
    @State private var navigateToEditTemplate = false
    @State private var navigateToCreateDraft = false
    @State private var navigateToCreateTemplate = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Tab bar — tapping a tab re-fetches the matching list so
                // the loader shows immediately (and stale data can't
                // linger from a previous session).
                HStack(spacing: 0) {
                    ForEach(DraftsTemplatesTab.allCases, id: \.self) { tab in
                        Button(action: {
                            activeTab = tab
                            switch tab {
                            case .drafts:    appState.loadDrafts()
                            case .templates: appState.loadTemplates()
                            }
                        }) {
                            VStack(spacing: 6) {
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: activeTab == tab ? .semibold : .regular))
                                    .foregroundColor(activeTab == tab ? .goldDark : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .overlay(
                                activeTab == tab
                                    ? Rectangle().fill(Color.goldDark).frame(height: 2)
                                    : nil,
                                alignment: .bottom
                            )
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
                .background(Color.bgBase)
                .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .bottom)

                // Content — per-tab loader fires on every fetch (tab
                // switch, pull-to-refresh, or the initial onAppear).
                if activeTab == .drafts && appState.isLoadingDrafts {
                    VStack { Spacer(); LoaderView(); Spacer() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if activeTab == .templates && appState.isLoadingTemplates {
                    VStack { Spacer(); LoaderView(); Spacer() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if activeTab == .drafts {
                                PODraftsListView()
                            } else {
                                POTemplatesListView()
                            }
                        }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                    }
                }
            }

            // Floating Create button (only for Templates tab)
            if activeTab == .templates {
                Button(action: {
                    navigateToCreateTemplate = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        Text("Create Template").font(.system(size: 14, weight: .bold))
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
        .background(
            VStack {
                NavigationLink(
                    destination: POFormPage().environmentObject(appState),
                    isActive: $navigateToForm
                ) { EmptyView() }

                NavigationLink(
                    destination: POFormPage().environmentObject(appState),
                    isActive: $navigateToCreateDraft
                ) { EmptyView() }

                NavigationLink(
                    destination: EditTemplatePage(
                        template: appState.editingTemplate
                    ).environmentObject(appState),
                    isActive: $navigateToEditTemplate
                ) { EmptyView() }

                NavigationLink(
                    destination: CreateTemplatePage().environmentObject(appState),
                    isActive: $navigateToCreateTemplate
                ) { EmptyView() }
            }.frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text("Drafts & Templates"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onAppear {
            appState.loadDrafts()
            appState.loadTemplates()
        }
        .onReceive(appState.$resumeDraft) { draft in
            if draft != nil { navigateToForm = true }
        }
        .onReceive(appState.$editingTemplate) { tpl in
            if tpl != nil { navigateToEditTemplate = true }
        }
    }
}

// MARK: - Edit Template Page (Navigation destination)
