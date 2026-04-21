import SwiftUI

enum VendorFilter: String, CaseIterable {
    case all = "All"
    case verified = "Verified"
    case nonVerified = "Non-Verified"
    case addedByMe = "Added by Me"
}

// MARK: - Shared vendor state (used by pinned header + scrollable list)

class VendorListState: ObservableObject {
    @Published var search = ""
    @Published var activeFilter: VendorFilter = .all
    @Published var selectedVendor: Vendor?
    @Published var navigateToCreate = false
    @Published var navigateToDetail = false
}

let vendorListState = VendorListState()
// MARK: - Legacy VendorsModuleView (kept for backward compatibility)

struct VendorsModuleView: View {
    @EnvironmentObject var appState: POViewModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                VendorsPinnedHeader()
                    .padding(.horizontal, 16).padding(.top, 10)
                    .background(Color.bgBase)

                // The ScrollView must stay in the hierarchy through
                // refreshes — it holds the hidden NavigationLink that
                // pushes the vendor detail page. Replacing it with a
                // loader (the previous approach) unwound the whole
                // nav stack when `loadVendors` fires from the edit
                // form's `.onDisappear`, so Back skipped the detail
                // page and dropped the user on the list.
                //
                // Instead: always render the ScrollView, and overlay
                // a full-area LoaderView only on the initial fetch
                // (when `vendors` is empty). Subsequent refreshes run
                // silently in the background with no loader.
                ZStack {
                    ScrollView {
                        VendorsScrollableList()
                            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 80)
                    }
                    if appState.isLoadingVendors && appState.vendors.isEmpty {
                        VStack { Spacer(); LoaderView(); Spacer() }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.bgBase)
                    }
                }
            }

            // Floating New Vendor button
            Button(action: { vendorListState.navigateToCreate = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("New Vendor").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.gold)
                .cornerRadius(28)
                .shadow(color: Color.gold.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .navigationBarTitle(Text("Vendors"), displayMode: .inline)
        .onAppear { appState.loadVendors() }
    }
}
