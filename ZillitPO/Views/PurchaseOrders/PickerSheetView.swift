import SwiftUI

struct PickerSheetView: View {
    @Binding var selection: String
    let options: [DropdownOption]
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filteredOptions: [DropdownOption] {
        if searchText.isEmpty { return options }
        let q = searchText.lowercased()
        return options.filter { $0.label.lowercased().contains(q) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if options.count > 5 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                        TextField("Search...", text: $searchText).font(.system(size: 13))
                    }
                    .padding(10).background(Color.bgSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                }
                List {
                    ForEach(filteredOptions) { option in
                        Button(action: { selection = option.id; isPresented = false }) {
                            HStack {
                                Text(option.label).font(.system(size: 14)).foregroundColor(.primary)
                                Spacer()
                                if option.id == selection {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(.goldDark)
                                }
                            }.padding(.vertical, 2)
                        }
                    }
                }.listStyle(GroupedListStyle())
            }
            .navigationBarTitle(Text("Select Option"), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.goldDark))
        }
    }
}

// MARK: - Country Code Data
