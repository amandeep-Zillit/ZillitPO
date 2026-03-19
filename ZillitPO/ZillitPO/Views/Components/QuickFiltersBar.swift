import SwiftUI

struct QuickFiltersBar: View {
    @EnvironmentObject var appState: AppState
    @State private var showFilterSheet = false
    @State private var showSortSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Filter dropdown
                Button(action: { showFilterSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                        Text(appState.activeFilter.rawValue).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())

                // Sort dropdown
                Button(action: { showSortSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                        Text(appState.sortKey.rawValue).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                TextField("Search POs by number, vendor, description...", text: $appState.searchText).font(.system(size: 13))
            }.padding(10).background(Color.white).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(
                title: "Filter",
                options: QuickFilter.allCases.map { ($0.rawValue, $0) },
                selected: appState.activeFilter,
                onSelect: { appState.activeFilter = $0; showFilterSheet = false }
            )
        }
        .sheet(isPresented: $showSortSheet) {
            SortSheetView(
                options: SortKey.allCases.map { ($0.rawValue, $0) },
                selected: appState.sortKey,
                onSelect: { appState.sortKey = $0; showSortSheet = false }
            )
        }
    }
}

// MARK: - Filter Sheet

struct FilterSheetView: View {
    let title: String
    let options: [(String, QuickFilter)]
    let selected: QuickFilter
    let onSelect: (QuickFilter) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(options, id: \.1) { label, value in
                    Button(action: { onSelect(value) }) {
                        HStack {
                            Text(label).font(.system(size: 14)).foregroundColor(.primary)
                            Spacer()
                            if value == selected {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                            }
                        }.padding(.vertical, 2)
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle(Text("Filter"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { onSelect(selected) }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}

// MARK: - Sort Sheet

struct SortSheetView: View {
    let options: [(String, SortKey)]
    let selected: SortKey
    let onSelect: (SortKey) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(options, id: \.1) { label, value in
                    Button(action: { onSelect(value) }) {
                        HStack {
                            Text(label).font(.system(size: 14)).foregroundColor(.primary)
                            Spacer()
                            if value == selected {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                            }
                        }.padding(.vertical, 2)
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle(Text("Sort By"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { onSelect(selected) }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}
