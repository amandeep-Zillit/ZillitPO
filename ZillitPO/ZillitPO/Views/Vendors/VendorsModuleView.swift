import SwiftUI
import Combine

enum VendorFilter: String, CaseIterable {
    case all = "All"
    case verified = "Verified"
    case nonVerified = "Non-Verified"
    case addedByMe = "Added by Me"
}

struct VendorsModuleView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""; @State private var selectedVendor: Vendor?
    @State private var navigateToCreate = false
    @State private var navigateToDetail = false
    @State private var activeFilter: VendorFilter = .all
    var filtered: [Vendor] {
        var result = appState.vendors

        // Apply filter
        switch activeFilter {
        case .all: break
        case .verified: result = result.filter { $0.verified }
        case .nonVerified: result = result.filter { !$0.verified }
        case .addedByMe:
            if let userId = appState.currentUser?.id {
                result = result.filter { ($0.addedBy ?? $0.userId) == userId }
            }
        }

        // Apply search
        if !search.isEmpty {
            let q = search.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }
        }

        return result
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Vendors").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button(action: { navigateToCreate = true }) {
                        HStack(spacing: 4) { Image(systemName: "plus"); Text("New Vendor") }
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Color.gold).cornerRadius(6)
                    }
                }

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(VendorFilter.allCases, id: \.self) { filter in
                            Button(action: { activeFilter = filter }) {
                                Text(filter.rawValue).font(.system(size: 12, weight: activeFilter == filter ? .semibold : .regular)).fixedSize()
                                    .foregroundColor(activeFilter == filter ? .black : .secondary)
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                                    .background(activeFilter == filter ? Color.gold : Color.white).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(activeFilter == filter ? Color.gold : Color.borderColor, lineWidth: 1))
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 12))
                    TextField("Search vendors by name, email...", text: $search).font(.system(size: 13))
                }.padding(10).background(Color.white).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))

                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                        Text("No vendors found").font(.system(size: 13)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                } else {
                    ForEach(filtered, id: \.id) { vendor in
                        HStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vendor.name).font(.system(size: 14, weight: .medium)).foregroundColor(.primary).lineLimit(1)
                                    if !vendor.address.formatted.isEmpty { Text(vendor.address.formatted).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }
                                }
                                Spacer()
                                Circle().fill(vendor.verified ? Color.green : Color.gray).frame(width: 6, height: 6)
                                Text(vendor.verified ? "Verified" : "Non-Verified").font(.system(size: 10)).foregroundColor(vendor.verified ? .green : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedVendor = vendor; navigateToDetail = true }

                            Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red.opacity(0.6))
                                .padding(10)
                                .contentShape(Rectangle())
                                .onTapGesture { appState.deleteVendorId = vendor.id }
                        }.padding(12)
                        .background(Color.white).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                    }
                }
            }

            // Hidden NavigationLink to push vendor form page
            NavigationLink(
                destination: VendorFormPage().environmentObject(appState),
                isActive: $navigateToCreate
            ) { EmptyView() }
            .hidden()

            // Hidden NavigationLink to push vendor detail page
            NavigationLink(
                destination: Group {
                    if let v = selectedVendor {
                        VendorDetailPage(vendor: v).environmentObject(appState)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToDetail
            ) { EmptyView() }
            .hidden()
        }
    }
}

// MARK: - Vendor Detail Page (Navigation push)

struct VendorDetailPage: View {
    let vendor: Vendor
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAlert = false
    @State private var navigateToCreatePO = false

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Vendor header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.gold.opacity(0.2)).frame(width: 44, height: 44)
                            Text(String(vendor.name.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold)).foregroundColor(.goldDark)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vendor.name).font(.system(size: 18, weight: .bold))
                            HStack(spacing: 4) {
                                Circle().fill(vendor.verified ? Color.green : Color.gray).frame(width: 6, height: 6)
                                Text(vendor.verified ? "Verified" : "Non-Verified")
                                    .font(.system(size: 11)).foregroundColor(vendor.verified ? .green : .secondary)
                            }
                        }
                        Spacer()
                    }.padding(14).background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Details card
                    VStack(alignment: .leading, spacing: 0) {
                        detailRow(label: "Contact Person", value: vendor.contactPerson)
                        Divider()
                        detailRow(label: "Email", value: vendor.email)
                        Divider()
                        detailRow(label: "Phone", value: "\(vendor.phone.countryCode) \(vendor.phone.number)")
                        Divider()
                        detailRow(label: "Address", value: vendor.address.formatted.isEmpty ? "—" : vendor.address.formatted)
                        if let vat = vendor.vatNumber, !vat.isEmpty {
                            Divider()
                            detailRow(label: "VAT Number", value: vat)
                        }
                    }.background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Create PO button
                    Button(action: {
                        appState.editingPO = nil
                        appState.resumeDraft = nil
                        appState.prefilledVendorId = vendor.id
                        navigateToCreatePO = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.badge.plus").font(.system(size: 13, weight: .semibold))
                            Text("Create PO for this Vendor").font(.system(size: 14, weight: .bold))
                        }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.gold).cornerRadius(10)
                    }

                    // Delete button
                    Button(action: { showDeleteAlert = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash").font(.system(size: 13))
                            Text("Delete Vendor").font(.system(size: 14, weight: .medium))
                        }.foregroundColor(.red).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.white).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                }.padding(16)
            }

            // Hidden NavigationLink to push Create PO page
            NavigationLink(
                destination: POFormPage(
                    prefilledVendorId: vendor.id
                ).environmentObject(appState),
                isActive: $navigateToCreatePO
            ) { EmptyView() }
            .hidden()
        }
        .navigationBarTitle(Text(vendor.name), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete Vendor?"), message: Text("This cannot be undone."),
                  primaryButton: .destructive(Text("Delete")) {
                      appState.deleteVendor(vendor.id)
                      presentationMode.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 13)).foregroundColor(.primary)
            Spacer()
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Vendor Form Page (Navigation destination)

struct VendorFormPage: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            VendorFormView(onBack: { presentationMode.wrappedValue.dismiss() })
        }
        .navigationBarTitle(Text("New Vendor"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            }
        )
        .onDisappear {
            appState.loadAllData()
        }
    }
}

struct VendorFormView: View {
    @EnvironmentObject var appState: AppState
    var onBack: () -> Void
    @State private var name = ""; @State private var contact = ""; @State private var email = ""
    @State private var phoneCode = "+44"; @State private var phone = ""
    @State private var vat = ""; @State private var departmentId = ""
    @State private var addr1 = ""; @State private var addr2 = ""
    @State private var city = ""; @State private var state = ""
    @State private var postal = ""; @State private var country = ""
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        List {
            // Vendor Details
            Section(header: vendorSectionHeader(icon: "person.crop.square", title: "VENDOR DETAILS", trailing: "All fields required unless noted")) {
                VStack(spacing: 14) {
                    FieldGroup(label: "VENDOR / COMPANY NAME") {
                        InputField(text: $name, placeholder: "e.g. Pinewood Studios Ltd")
                    }
                    FieldGroup(label: "CONTACT PERSON") {
                        InputField(text: $contact, placeholder: "e.g. Margaret Thornton")
                    }
                    FieldGroup(label: "EMAIL") {
                        InputField(text: $email, placeholder: "e.g. bookings@studio.co.uk")
                    }
                    FieldGroup(label: "PHONE") {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                TextField("+44", text: $phoneCode)
                                    .font(.system(size: 13))
                                    .frame(width: 40)
                                Button(action: { phoneCode = "" }) {
                                    Image(systemName: "xmark").font(.system(size: 9)).foregroundColor(.gray.opacity(0.5))
                                }.buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 8).padding(.vertical, 9)
                            .background(Color.white).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))

                            InputField(text: $phone, placeholder: "e.g. 1753 651700")
                        }
                    }
                    FieldGroup(label: "VAT NUMBER", optional: true) {
                        InputField(text: $vat, placeholder: "e.g. GB 123 4567 89")
                    }
                    FieldGroup(label: "DEPARTMENT") {
                        PickerField(selection: $departmentId, placeholder: "Select department...",
                            options: DepartmentsData.sorted.map { DropdownOption($0.identifier, $0.displayName) })
                    }
                }
            }

            // Address
            Section(header: vendorSectionHeader(icon: "mappin.and.ellipse", title: "ADDRESS")) {
                VStack(spacing: 14) {
                    FieldGroup(label: "ADDRESS LINE 1") {
                        InputField(text: $addr1, placeholder: "Street address")
                    }
                    FieldGroup(label: "ADDRESS LINE 2", optional: true) {
                        InputField(text: $addr2, placeholder: "Suite, unit, building...")
                    }
                    FieldGroup(label: "CITY") {
                        InputField(text: $city, placeholder: "e.g. London")
                    }
                    FieldGroup(label: "STATE / COUNTY", optional: true) {
                        InputField(text: $state, placeholder: "e.g. Middlesex")
                    }
                    FieldGroup(label: "POSTAL / ZIP CODE") {
                        InputField(text: $postal, placeholder: "e.g. SL0 0NH")
                    }
                    FieldGroup(label: "COUNTRY") {
                        InputField(text: $country, placeholder: "United Kingdom")
                    }
                }
            }

            // Actions
            Section {
                VStack(spacing: 10) {
                    Button(action: { createVendor() }) {
                        HStack(spacing: 6) {
                            Text("Save Vendor").font(.system(size: 14, weight: .bold))
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                        }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(name.isEmpty ? Color.gold.opacity(0.4) : Color.gold).cornerRadius(8)
                    }.disabled(name.isEmpty)
                }
            }
        }
        .listStyle(GroupedListStyle())
    }

    private func vendorSectionHeader(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.goldDark)
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).lineLimit(1)
            Spacer()
            if let t = trailing {
                Text(t).font(.system(size: 9)).foregroundColor(.gray).italic().lineLimit(1)
            }
        }
    }

    private func createVendor() {
        APIClient.shared.post("/api/v2/vendors", body: [
            "name": name, "contact_person": contact, "email": email,
            "phone": ["country_code": phoneCode, "number": phone],
            "address": ["line1": addr1, "line2": addr2, "city": city, "state": state, "postal_code": postal, "country": country],
            "vat_number": vat, "department_id": departmentId] as [String: Any])
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { c in
                if case .failure(let e) = c { print("❌ Create vendor failed: \(e)") }
            }, receiveValue: { [self] _ in
                print("✅ Vendor created successfully")
                appState.loadAllData()
                onBack()
            })
            .store(in: &cancellables)
    }
}
