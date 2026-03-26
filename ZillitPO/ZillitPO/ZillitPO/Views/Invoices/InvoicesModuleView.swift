import SwiftUI

struct InvoicesModuleView: View {
    @EnvironmentObject var appState: POViewModel
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var navigateToUpload = false

    enum InvoiceFilter: String, CaseIterable {
        case all = "All", pending = "Pending", approved = "Approved", rejected = "Rejected"
    }

    var filteredInvoices: [Invoice] {
        var list = appState.invoices
        switch selectedFilter {
        case .pending: list = list.filter { $0.status == "PENDING" }
        case .approved: list = list.filter { $0.status == "APPROVED" }
        case .rejected: list = list.filter { $0.status == "REJECTED" }
        case .all: break
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.invoiceNumber.lowercased().contains(q) ||
                $0.vendor.lowercased().contains(q) ||
                ($0.description ?? "").lowercased().contains(q)
            }
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Filter bar
                HStack(spacing: 8) {
                    ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            Text(filter.rawValue)
                                .font(.system(size: 12, weight: selectedFilter == filter ? .bold : .medium))
                                .foregroundColor(selectedFilter == filter ? .white : .secondary)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(selectedFilter == filter ? Color.gold : Color.white)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderColor, lineWidth: selectedFilter == filter ? 0 : 1))
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }.padding(.horizontal, 16).padding(.top, 12)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                    TextField("Search invoices…", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 10)

                // Stats
                statsCards.padding(.horizontal, 16).padding(.top, 12)

                // Invoice list
                ScrollView {
                    if appState.isLoading {
                        LoaderView().padding(.top, 40)
                    } else if filteredInvoices.isEmpty {
                        emptyState.padding(.top, 20)
                    } else {
                        invoiceList.padding(.top, 8)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 80)
            }

            // Floating Upload Invoice button
            Button(action: {
                navigateToUpload = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Upload Invoice").font(.system(size: 14, weight: .bold))
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
        .background(
            NavigationLink(
                destination: UploadInvoicePage().environmentObject(appState),
                isActive: $navigateToUpload
            ) { EmptyView() }
            .frame(width: 0, height: 0).hidden()
        )
        .navigationBarTitle(Text("Invoices"), displayMode: .inline)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        let total = appState.invoices.count
        let pending = appState.invoices.filter { $0.status == "PENDING" }.count
        let approved = appState.invoices.filter { $0.status == "APPROVED" }.count
        let totalValue = appState.invoices.reduce(0.0) { $0 + VATHelpers.calcVat($1.totalAmount, treatment: $1.vatTreatment).gross }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatCard(title: "Total", value: "\(total)", color: .blue)
                StatCard(title: "Pending", value: "\(pending)", color: .orange)
            }
            HStack(spacing: 10) {
                StatCard(title: "Approved", value: "\(approved)", color: .green)
                StatCard(title: "Value", value: FormatUtils.formatGBP(totalValue), color: .goldDark)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
            Text("No invoices found").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    // MARK: - Invoice List

    private var invoiceList: some View {
        VStack(spacing: 0) {
            ForEach(filteredInvoices, id: \.id) { invoice in
                InvoiceRow(invoice: invoice)
                Divider().padding(.horizontal, 12)
            }
        }
        .background(Color.white).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }
}

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.invoiceNumber.isEmpty ? "—" : invoice.invoiceNumber)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.goldDark)
                Text(invoice.vendor.isEmpty ? "—" : invoice.vendor)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black).lineLimit(1)
                if let desc = invoice.description, !desc.isEmpty {
                    Text(desc).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                }
                if let poNum = invoice.poNumber, !poNum.isEmpty {
                    Text("PO: \(poNum)").font(.system(size: 9, weight: .medium)).foregroundColor(.blue.opacity(0.7))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormatUtils.formatCurrency(VATHelpers.calcVat(invoice.totalAmount, treatment: invoice.vatTreatment).gross, code: invoice.currency))
                    .font(.system(size: 13, design: .monospaced))
                invoiceStatusBadge
                if let due = invoice.dueDate, due > 0 {
                    Text("Due: \(FormatUtils.formatTimestamp(due))")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private var invoiceStatusBadge: some View {
        let label = invoice.invoiceStatus.displayName
        let colors: (Color, Color) = {
            switch invoice.invoiceStatus {
            case .rejected: return (.red, Color.red.opacity(0.1))
            case .posted: return (.blue, Color.blue.opacity(0.1))
            case .closed: return (.gray, Color.gray.opacity(0.1))
            case .approved: return (.green, Color.green.opacity(0.1))
            case .draft: return (.orange, Color.orange.opacity(0.1))
            default: return (.goldDark, Color.gold.opacity(0.15))
            }
        }()
        return Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(colors.0)
            .padding(.horizontal, 8).padding(.vertical, 3).background(colors.1).cornerRadius(4)
    }
}

// MARK: - Upload Invoice Page

struct UploadInvoicePage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Upload area
                VStack(spacing: 16) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gold)

                    Text("Upload Invoice")
                        .font(.system(size: 20, weight: .bold))

                    Text("Select a file to upload your invoice")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8]))
                                .foregroundColor(Color.gold.opacity(0.4))
                        )
                )

                // Upload options
                VStack(spacing: 12) {
                    uploadOptionButton(icon: "camera.fill", title: "Take Photo", subtitle: "Capture invoice with camera")
                    uploadOptionButton(icon: "photo.fill", title: "Photo Library", subtitle: "Choose from saved photos")
                    uploadOptionButton(icon: "doc.fill", title: "Choose File", subtitle: "Upload PDF or document")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationBarTitle(Text("Upload Invoice"), displayMode: .inline)
    }

    private func uploadOptionButton(icon: String, title: String, subtitle: String) -> some View {
        Button(action: {
            // TODO: Implement upload action
            print("📤 Upload action: \(title)")
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.black)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }
}
