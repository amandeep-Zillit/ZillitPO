//
//  AccountantView.swift
//  ZillitPO
//
//  Accountant-only intermediate hub. From the home screen, accountants
//  see a single "AccountHub" tile that pushes this view, which then
//  shows the same three tiles (Purchase Orders / Card Expenses /
//  Cash & Expenses) that non-accountant users see directly on the
//  home screen.
//

import SwiftUI

struct AccountantView: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var navigateToPurchaseOrders = false
    @State private var navigateToCardExpenses = false
    @State private var navigateToCashExpenses = false

    @available(iOS, deprecated: 16.0, message: "iOS 13 compat — uses legacy NavigationLink(destination:isActive:label:)")
    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                // Purchase Orders tile
                NavigationLink(destination: POHubPage().environmentObject(appState), isActive: $navigateToPurchaseOrders) { EmptyView() }.hidden()
                Button(action: { navigateToPurchaseOrders = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "cart.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.gold).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Purchase Orders").font(.system(size: 15, weight: .semibold))
                            Text("Create, track, and manage POs").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.goldDark)
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                // Card Expenses tile
                NavigationLink(destination: CardExpenseView().environmentObject(appState), isActive: $navigateToCardExpenses) { EmptyView() }.hidden()
                Button(action: { navigateToCardExpenses = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color(red: 0.56, green: 0.27, blue: 0.68)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Card Expenses").font(.system(size: 15, weight: .semibold))
                            Text("Track and manage card expenses").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.56, green: 0.27, blue: 0.68))
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.56, green: 0.27, blue: 0.68).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                // Cash & Expenses tile
                NavigationLink(destination: CashExpenseView().environmentObject(appState), isActive: $navigateToCashExpenses) { EmptyView() }.hidden()
                Button(action: { navigateToCashExpenses = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "sterlingsign.circle.fill").font(.system(size: 20)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color(red: 0.2, green: 0.7, blue: 0.45)).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cash & Expenses").font(.system(size: 15, weight: .semibold))
                            Text("Petty cash & out-of-pocket claims").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.45))
                    }.padding(14).background(Color.bgSurface).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.2, green: 0.7, blue: 0.45).opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationBarTitle(Text("AccountHub"), displayMode: .inline)
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
