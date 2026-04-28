import SwiftUI

struct QuickFiltersBar: View {
    @EnvironmentObject var appState: POViewModel
    var onDraftsTemplatesTap: (() -> Void)? = nil
    @State private var showFilterSheet = false
    @State private var showSortSheet = false

    var body: some View {
        GeometryReader { geo in
            // Compact mode is governed only by the screen width again
            // (iPhone SE-class). The sort button's label (e.g. "Date ↓",
            // "Amount ↓", "Vendor A-Z") therefore stays visible on
            // standard-size devices regardless of which filter is
            // selected — the smaller fonts/paddings on the row already
            // give every label enough room without truncation.
            let compact = geo.size.width < 360
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Filter dropdown
                    filterButton(compact: false)

                    // Sort dropdown
                    sortButton(compact: compact)

                    Spacer()

                    // Drafts / Templates button — sized down slightly so
                    // a longer selected filter label (e.g. "Approved",
                    // "Rejected") still fits inside the filter button
                    // without truncation. Layout shape unchanged.
                    if let action = onDraftsTemplatesTap {
                        Button(action: action) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc").font(.system(size: 9, weight: .medium))
                                Text("Drafts / Templates").font(.system(size: 11, weight: .semibold)).lineLimit(1).fixedSize()
                            }
                            .foregroundColor(.goldDark)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.bgSurface).cornerRadius(6)
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
                }.padding(10).background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
            }
        }.frame(height: 76)
    }

    /// SF Symbol that reflects the currently-active status filter, so
    /// the filter button shows at a glance which state is selected
    /// (consistent with the sort button's `sortIconName` behaviour).
    private var filterIconName: String {
        switch appState.activeFilter {
        case .all:      return "line.3.horizontal.decrease"  // generic "filter" glyph
        case .pending:  return "clock"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        }
    }

    // Separate views so each can own its own .actionSheet
    private func filterButton(compact: Bool) -> some View {
        Button(action: { showFilterSheet = true }) {
            HStack(spacing: 5) {
                Image(systemName: filterIconName).font(.system(size: 9, weight: .medium)).foregroundColor(.goldDark)
                Text(appState.activeFilter.rawValue).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.bgSurface).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .selectionActionSheet(
            title: "Filter by Status",
            isPresented: $showFilterSheet,
            options: QuickFilter.allCases,
            isSelected: { $0 == appState.activeFilter },
            label: { $0.rawValue },
            onSelect: { appState.activeFilter = $0 }
        )
    }

    /// SF Symbol that reflects the currently-active sort key. Used in
    /// place of the generic `arrow.up.arrow.down` icon so that, when
    /// the sort button collapses to icon-only (compact mode), the user
    /// can still see at a glance which sort is selected.
    private var sortIconName: String {
        switch appState.sortKey {
        case .dateDesc:   return "calendar"
        case .amountDesc: return "sterlingsign"
        case .vendorAsc:  return "building.2"
        }
    }

    private func sortButton(compact: Bool) -> some View {
        Button(action: { showSortSheet = true }) {
            HStack(spacing: 5) {
                Image(systemName: sortIconName).font(.system(size: 9, weight: .medium)).foregroundColor(.goldDark)
                if !compact {
                    Text(appState.sortKey.rawValue).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .medium)).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, compact ? 8 : 10).padding(.vertical, 7)
            .background(Color.bgSurface).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .selectionActionSheet(
            title: "Sort By",
            isPresented: $showSortSheet,
            options: SortKey.allCases,
            isSelected: { $0 == appState.sortKey },
            label: { $0.rawValue },
            onSelect: { appState.sortKey = $0 }
        )
    }
}
