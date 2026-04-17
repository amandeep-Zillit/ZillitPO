import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Country Name Picker Sheet
// Mirrors `CountryCodePickerSheet` but selects the country NAME (e.g.
// "United Kingdom") instead of the dialing code. Used by the delivery
// address country field on the Create/Edit PO form so users can pick
// from a searchable list instead of typing free-form text.
// ═══════════════════════════════════════════════════════════════════

struct CountryNamePickerSheet: View {
    @Binding var selectedName: String
    @Binding var isPresented: Bool
    @State private var searchText = ""

    /// Deduplicate by name — the source list has repeats (e.g. multiple
    /// entries share "+1" across US/Canada, but name is unique).
    private var countries: [CountryCode] {
        var seen = Set<String>()
        return countryCodes.filter { seen.insert($0.name).inserted }
    }

    private var filtered: [CountryCode] {
        if searchText.isEmpty { return countries }
        let q = searchText.lowercased()
        return countries.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                    TextField("Search country…", text: $searchText).font(.system(size: 13))
                }
                .padding(10).background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                List {
                    ForEach(filtered) { c in
                        Button(action: {
                            selectedName = c.name
                            isPresented = false
                        }) {
                            HStack {
                                Text(c.flag).font(.system(size: 18))
                                Text(c.name)
                                    .font(.system(size: 14)).foregroundColor(.primary)
                                Spacer()
                                if c.name == selectedName {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.goldDark)
                                }
                            }.padding(.vertical, 2)
                        }
                    }
                }.listStyle(GroupedListStyle())
            }
            .navigationBarTitle(Text("Country"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}
