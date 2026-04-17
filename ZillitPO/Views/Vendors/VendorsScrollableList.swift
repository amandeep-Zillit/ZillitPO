import SwiftUI

// MARK: - Vendors Scrollable List (vendor cards — scrolls below pinned header)

struct VendorsScrollableList: View {
    @EnvironmentObject var appState: POViewModel
    @ObservedObject private var state = vendorListState

    /// A vendor can be deleted only by the accountant or by its creator
    /// (creator = `addedBy` with a fallback to `userId`, matching the
    /// "Added by me" filter above). Keeps the UI and the server's
    /// permission model aligned — the list-row trash icon is hidden for
    /// anyone who couldn't follow through.
    private func canDelete(_ vendor: Vendor) -> Bool {
        if appState.currentUser?.isAccountant == true { return true }
        guard let uid = appState.currentUser?.id else { return false }
        return (vendor.addedBy ?? vendor.userId) == uid
    }

    var filtered: [Vendor] {
        var result = appState.vendors

        switch state.activeFilter {
        case .all: break
        case .verified: result = result.filter { $0.verified }
        case .nonVerified: result = result.filter { !$0.verified }
        case .addedByMe:
            if let userId = appState.currentUser?.id {
                result = result.filter { ($0.addedBy ?? $0.userId) == userId }
            }
        }

        if !state.search.isEmpty {
            let q = state.search.lowercased()
            result = result.filter { ($0.name ?? "").lowercased().contains(q) || ($0.email ?? "").lowercased().contains(q) }
        }

        return result
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                if appState.isLoadingVendors && appState.vendors.isEmpty {
                    LoaderView()
                        .frame(maxWidth: .infinity, minHeight: 480)
                } else if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "person.2").font(.system(size: 28)).foregroundColor(.gray.opacity(0.3))
                        Text("No vendors found").font(.system(size: 13)).foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: 480)
                } else {
                    ForEach(filtered, id: \.id) { vendor in
                        HStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vendor.name ?? "").font(.system(size: 14, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                    if !(vendor.address?.formatted ?? "").isEmpty { Text(vendor.address?.formatted ?? "").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }
                                }
                                Spacer()
                                Circle().fill(vendor.verified ? Color.green : Color.gray).frame(width: 6, height: 6)
                                Text(vendor.verified ? "Verified" : "Non-Verified").font(.system(size: 10)).foregroundColor(vendor.verified ? .green : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { state.selectedVendor = vendor; state.navigateToDetail = true }

                            // Trash is only shown to the accountant or the vendor's
                            // creator — same rule as the "Added by me" filter above
                            // (creator = addedBy ?? userId). Hiding the icon entirely
                            // for other users prevents the tap → 403 round trip.
                            if canDelete(vendor) {
                                Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red.opacity(0.6))
                                    .padding(10)
                                    .contentShape(Rectangle())
                                    .onTapGesture { appState.deleteVendorId = vendor.id }
                            }
                        }.padding(12)
                        .background(Color.bgSurface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                }
            }

            // Hidden NavigationLink to push vendor form page
            NavigationLink(
                destination: VendorFormPage().environmentObject(appState),
                isActive: $state.navigateToCreate
            ) { EmptyView() }
            .hidden()

            // Hidden NavigationLink to push vendor detail page
            NavigationLink(
                destination: Group {
                    if let v = state.selectedVendor {
                        VendorDetailPage(vendor: v).environmentObject(appState)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $state.navigateToDetail
            ) { EmptyView() }
            .hidden()
        }
    }
}
