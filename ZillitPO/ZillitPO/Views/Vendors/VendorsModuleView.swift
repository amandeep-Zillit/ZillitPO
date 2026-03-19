import SwiftUI
import Combine

struct VendorsModuleView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""; @State private var selectedVendor: Vendor?
    @State private var showCreate = false

    var filtered: [Vendor] {
        if search.isEmpty { return appState.vendors }
        let q = search.lowercased()
        return appState.vendors.filter { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vendors").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { showCreate = true }) {
                    HStack(spacing: 4) { Image(systemName: "plus"); Text("New Vendor") }
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.gold).cornerRadius(6)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 11))
                TextField("Search vendors...", text: $search).font(.system(size: 12))
            }.padding(8).background(Color.white).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                    Text("No vendors found").font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            } else {
                ForEach(filtered, id: \.id) { vendor in
                    Button(action: { selectedVendor = vendor }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vendor.name).font(.system(size: 14, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                if !vendor.address.formatted.isEmpty { Text(vendor.address.formatted).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }
                            }
                            Spacer()
                            Circle().fill(vendor.verified ? Color.green : Color.gray).frame(width: 6, height: 6)
                            Text(vendor.verified ? "Verified" : "Unverified").font(.system(size: 10)).foregroundColor(vendor.verified ? .green : .secondary)
                        }.padding(12)
                    }.buttonStyle(PlainButtonStyle()).background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                }
            }
        }
        .sheet(item: $selectedVendor) { v in VendorDetailView(vendor: v) }
        .sheet(isPresented: $showCreate) { VendorFormView { showCreate = false; appState.loadAllData() }.environmentObject(appState) }
    }
}

struct VendorDetailView: View {
    let vendor: Vendor
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Details")) {
                    HStack { Text("Name"); Spacer(); Text(vendor.name) }
                    HStack { Text("Contact"); Spacer(); Text(vendor.contactPerson) }
                    HStack { Text("Email"); Spacer(); Text(vendor.email) }
                    HStack { Text("Phone"); Spacer(); Text("\(vendor.phone.countryCode) \(vendor.phone.number)") }
                    HStack { Text("Address"); Spacer(); Text(vendor.address.formatted.isEmpty ? "—" : vendor.address.formatted) }
                    if let vat = vendor.vatNumber, !vat.isEmpty { HStack { Text("VAT"); Spacer(); Text(vat) } }
                    HStack { Text("Status"); Spacer(); Text(vendor.verified ? "Verified" : "Unverified") }
                }
            }.listStyle(GroupedListStyle())
            .navigationBarTitle(Text(vendor.name), displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

struct VendorFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    var onSave: () -> Void
    @State private var name = ""; @State private var contact = ""; @State private var email = ""
    @State private var phone = ""; @State private var addr = ""; @State private var city = ""
    @State private var postal = ""; @State private var country = ""; @State private var vat = ""
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) { TextField("Name *", text: $name); TextField("Contact", text: $contact); TextField("Email", text: $email); TextField("Phone", text: $phone) }
                Section(header: Text("Address")) { TextField("Address", text: $addr); TextField("City", text: $city); TextField("Postal Code", text: $postal); TextField("Country", text: $country) }
                Section(header: Text("Tax")) { TextField("VAT Number", text: $vat) }
            }.listStyle(GroupedListStyle())
            .navigationBarTitle(Text("New Vendor"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") { createVendor() }.disabled(name.isEmpty)
            )
        }
    }

    private func createVendor() {
        APIClient.shared.post("/api/v2/vendors", body: [
            "name": name, "contact_person": contact, "email": email,
            "phone": ["country_code": "+44", "number": phone],
            "address": ["line1": addr, "city": city, "postal_code": postal, "country": country],
            "vat_number": vat] as [String: Any])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in onSave(); presentationMode.wrappedValue.dismiss() })
            .store(in: &cancellables)
    }
}
