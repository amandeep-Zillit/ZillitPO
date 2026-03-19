import SwiftUI

struct QuickFiltersBar: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Quick Filters:").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).fixedSize()
                    ForEach(QuickFilter.allCases, id: \.self) { f in
                        Button(action: { appState.activeFilter = f }) {
                            Text(f.rawValue).font(.system(size: 12, weight: appState.activeFilter == f ? .semibold : .regular)).fixedSize()
                                .foregroundColor(appState.activeFilter == f ? .black : .secondary)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(appState.activeFilter == f ? Color.gold : Color.white).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(appState.activeFilter == f ? Color.gold : Color.borderColor, lineWidth: 1))
                        }.buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(width: 16)
                    Text("Sort:").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).fixedSize()
                    Picker("", selection: $appState.sortKey) {
                        ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(DefaultPickerStyle()).fixedSize()
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                TextField("Search POs by number, vendor, description...", text: $appState.searchText).font(.system(size: 13))
            }.padding(10).background(Color.white).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
    }
}
