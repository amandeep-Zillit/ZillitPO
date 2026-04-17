import SwiftUI

// MARK: - Vendors Pinned Header (filter buttons + search bar — stays above ScrollView)

struct VendorsPinnedHeader: View {
    @EnvironmentObject var appState: POViewModel
    @ObservedObject private var state = vendorListState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Filters
            HStack(spacing: 6) {
                ForEach(VendorFilter.allCases, id: \.self) { filter in
                    Button(action: { state.activeFilter = filter }) {
                        Text(filter.rawValue).font(.system(size: 12, weight: state.activeFilter == filter ? .semibold : .regular))
                            .foregroundColor(state.activeFilter == filter ? .black : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(state.activeFilter == filter ? Color.gold : Color.bgSurface).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(state.activeFilter == filter ? Color.gold : Color.borderColor, lineWidth: 1))
                            .contentShape(Rectangle())
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                TextField("Search vendors by name, email...", text: $state.search).font(.system(size: 13))
            }.padding(10).background(Color.bgSurface).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
    }
}
