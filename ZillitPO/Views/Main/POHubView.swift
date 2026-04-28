//
//  POHubView.swift
//  ZillitPO
//

import SwiftUI

// MARK: - PO Hub Page (3 tiles: All POs, Vendors, Invoices)

struct POHubPage: View {
    @EnvironmentObject var appState: POViewModel
    @State private var navigateToAllPOs = false
    @State private var navigateToVendors = false
    @State private var navigateToInvoices = false

    @Environment(\.presentationMode) var presentationMode

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                NavigationLink(destination: DepartmentPOModule(), isActive: $navigateToAllPOs) { Text("") }.hidden()
                Button(action: { navigateToAllPOs = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.gold).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Purchase Orders").font(.system(size: 15, weight: .semibold))
                            Text("View, create and manage POs").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                NavigationLink(destination: VendorsModuleView().environmentObject(appState), isActive: $navigateToVendors) { Text("") }.hidden()
                Button(action: { navigateToVendors = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color(red: 0.35, green: 0.72, blue: 0.36)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vendors").font(.system(size: 15, weight: .semibold))
                            Text("Manage vendor contacts").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.35, green: 0.72, blue: 0.36))
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.35, green: 0.72, blue: 0.36).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                NavigationLink(destination: InvoicesModuleView().environmentObject(appState), isActive: $navigateToInvoices) { Text("") }.hidden()
                Button(action: { navigateToInvoices = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.6, blue: 0.86)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invoices").font(.system(size: 15, weight: .semibold))
                            Text("View and manage invoices").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.86))
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.6, blue: 0.86).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationBarTitle(Text("Account Hub"), displayMode: .inline)
        // `.toolbar { ToolbarItem(placement: .navigationBarLeading) }` is iOS 14+;
        // ZillitPO targets iOS 13, so we use the legacy `.navigationBarItems`
        // modifier to render the same back-chevron in the leading slot.
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .foregroundColor(.goldDark)
            }
        )
    }
}
