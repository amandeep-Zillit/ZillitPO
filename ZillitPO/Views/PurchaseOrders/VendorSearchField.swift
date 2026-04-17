import SwiftUI
import UIKit

struct VendorSearchField: View {
    @Binding var vendorId: String
    let vendors: [Vendor]
    var hasError: Bool = false

    @State private var searchText = ""
    @State private var isEditing = false

    private var selectedVendor: Vendor? { vendors.first { $0.id == vendorId } }

    private var filteredVendors: [Vendor] {
        guard isEditing else { return [] }
        if searchText.isEmpty { return vendors }
        let q = searchText.lowercased()
        return vendors.filter {
            ($0.name ?? "").lowercased().contains(q) || ($0.email ?? "").lowercased().contains(q) || ($0.contactPerson ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.gray)
                if isEditing || vendorId.isEmpty {
                    TextField("Search by name, email, or contact...", text: $searchText, onEditingChanged: { editing in
                        isEditing = editing
                    })
                    .font(.system(size: 13))
                } else {
                    Text(selectedVendor?.name ?? "").font(.system(size: 13)).foregroundColor(.primary).lineLimit(1)
                    Spacer()
                    Button(action: { vendorId = ""; searchText = ""; isEditing = true }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.gray.opacity(0.5))
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(Color.bgSurface).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(hasError && vendorId.isEmpty ? Color.red : isEditing ? Color.goldDark : Color.borderColor, lineWidth: hasError && vendorId.isEmpty ? 1 : isEditing ? 1.5 : 1))
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing && !vendorId.isEmpty {
                    vendorId = ""; searchText = ""; isEditing = true
                }
            }

            // Inline vendor list (shows all when empty, filtered when typing)
            if !filteredVendors.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredVendors, id: \.id) { vendor in
                            Button(action: {
                                vendorId = vendor.id; searchText = ""; isEditing = false
                                #if canImport(UIKit)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                #endif
                            }) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vendor.name ?? "").font(.system(size: 13, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                        HStack(spacing: 8) {
                                            if !(vendor.email ?? "").isEmpty {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "envelope").font(.system(size: 8)).foregroundColor(.gray)
                                                    Text(vendor.email ?? "").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                                }
                                            }
                                            if !(vendor.contactPerson ?? "").isEmpty {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "person").font(.system(size: 8)).foregroundColor(.gray)
                                                    Text(vendor.contactPerson ?? "").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                                                }
                                            }
                                        }
                                    }
                                    Spacer()
                                    if vendor.id == vendorId {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.goldDark)
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.bgSurface)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            if vendor.id != filteredVendors.last?.id { Divider().padding(.horizontal, 8) }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .background(Color.bgSurface).cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.top, 4)
            }
        }
    }
}
