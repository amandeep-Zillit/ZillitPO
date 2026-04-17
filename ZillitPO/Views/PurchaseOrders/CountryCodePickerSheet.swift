import SwiftUI

struct CountryCodePickerSheet: View {
    @Binding var selectedCode: String
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filteredCodes: [CountryCode] {
        if searchText.isEmpty { return countryCodes }
        let q = searchText.lowercased()
        return countryCodes.filter { $0.name.lowercased().contains(q) || $0.code.contains(q) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                    TextField("Search country or code...", text: $searchText).font(.system(size: 13))
                }
                .padding(10).background(Color.bgSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                List {
                    ForEach(filteredCodes) { code in
                        Button(action: { selectedCode = code.code; isPresented = false }) {
                            HStack {
                                Text(code.flag).font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(code.name).font(.system(size: 14)).foregroundColor(.primary)
                                    Text(code.code).font(.system(size: 12)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if code.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.goldDark)
                                }
                            }.padding(.vertical, 2)
                        }
                    }
                }.listStyle(GroupedListStyle())
            }
            .navigationBarTitle(Text("Country Code"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}

// MARK: - Vendor Search Field (text field with inline vendor list)
