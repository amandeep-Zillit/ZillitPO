import SwiftUI

struct QuickFiltersBar: View {
    @EnvironmentObject var appState: AppState
    var onDraftsTemplatesTap: (() -> Void)? = nil
    @State private var showFilterSheet = false
    @State private var showSortSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Filter dropdown
                filterButton

                // Sort dropdown
                sortButton

                Spacer()

                // Drafts / Templates button
                if let action = onDraftsTemplatesTap {
                    Button(action: action) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc").font(.system(size: 10, weight: .medium))
                            Text("Drafts / Templates").font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
                        }
                        .foregroundColor(.goldDark)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                TextField("Search POs by number, vendor, description...", text: $appState.searchText).font(.system(size: 13))
            }.padding(10).background(Color.white).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
    }

    // Separate views so each can own its own .actionSheet
    private var filterButton: some View {
        Button(action: { showFilterSheet = true }) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                Text(appState.activeFilter.rawValue).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .actionSheet(isPresented: $showFilterSheet) {
            ActionSheet(
                title: Text("Filter by Status"),
                buttons: QuickFilter.allCases.map { filter in
                    let label = filter == appState.activeFilter ? "\(filter.rawValue) ✓" : filter.rawValue
                    return .default(Text(label)) { appState.activeFilter = filter }
                } + [.cancel()]
            )
        }
    }

    private var sortButton: some View {
        Button(action: { showSortSheet = true }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 10, weight: .medium)).foregroundColor(.goldDark)
                Text(appState.sortKey.rawValue).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .actionSheet(isPresented: $showSortSheet) {
            ActionSheet(
                title: Text("Sort By"),
                buttons: SortKey.allCases.map { key in
                    let label = key == appState.sortKey ? "\(key.rawValue) ✓" : key.rawValue
                    return .default(Text(label)) { appState.sortKey = key }
                } + [.cancel()]
            )
        }
    }
}
