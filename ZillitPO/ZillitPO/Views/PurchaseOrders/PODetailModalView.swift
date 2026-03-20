import SwiftUI
import WebKit
import Combine

// MARK: - PO Detail Page (Navigation push destination)

struct PODetailPage: View {
    let po: PurchaseOrder
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        PODetailContentView(po: po, onClose: { presentationMode.wrappedValue.dismiss() })
            .environmentObject(appState)
            .navigationBarTitle(Text(po.poNumber), displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading:
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Back").font(.system(size: 16))
                    }.foregroundColor(.goldDark)
                }
            )
    }
}

// MARK: - PO Detail Content View (shared content)

struct PODetailContentView: View {
    let po: PurchaseOrder
    var onClose: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var navigateToPDF = false
    @State private var pdfData: Data?
    @State private var isLoadingPDF = false
    @State private var pdfError: String?
    @State private var pdfCancellable: AnyCancellable?

    private var vat: VATResult { VATHelpers.calcVat(po.netAmount, treatment: po.vatTreatment) }
    private var vis: ApprovalVisibility {
        guard let c = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
        else { return ApprovalVisibility(visible: true, canApprove: false, nextTier: nil, totalTiers: 0, approvedCount: 0, isCreator: false) }
        return ApprovalHelpers.getVisibility(po: po, config: c, userId: appState.userId)
    }
    private var isCreator: Bool { po.userId == appState.userId }
    private var canEdit: Bool { isCreator && ![.approved, .posted, .acctEntered].contains(po.poStatus) }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(po.poNumber).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(.goldDark)
                        Text((po.description ?? "").isEmpty ? "No description" : po.description ?? "").font(.system(size: 17, weight: .semibold))
                    }

                    // Details card
                    VStack(alignment: .leading, spacing: 0) {
                        DetailRow(label: "Vendor", value: po.vendor.isEmpty ? "—" : po.vendor)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Department", value: po.department.isEmpty ? "—" : po.department)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Amount (Gross)", value: FormatUtils.formatCurrency(vat.gross, code: po.currency))
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Currency", value: po.currency)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Eff. Date", value: FormatUtils.formatTimestamp(po.effectiveDate))
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "VAT", value: VATHelpers.vatLabel(po.vatTreatment))
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Created By", value: UsersData.byId[po.userId]?.fullName ?? po.userId)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Status", value: po.poStatus.displayName)
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                    // Notes
                    if !(po.notes ?? "").isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                            Text(po.notes ?? "").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // Rejection reason
                    if po.poStatus == .rejected, let reason = po.rejectionReason, !reason.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red)
                            Text(reason).font(.system(size: 12)).foregroundColor(.red)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }

                    // Line Items
                    if !po.lineItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("LINE ITEMS").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

                            ForEach(po.lineItems, id: \.id) { li in
                                HStack {
                                    Text(li.description).font(.system(size: 12)).lineLimit(1)
                                    Spacer()
                                    Text("×\(Int(li.quantity))").font(.system(size: 11)).foregroundColor(.secondary)
                                    Text(FormatUtils.formatCurrency(li.total, code: po.currency)).font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                Divider().padding(.horizontal, 14)
                            }

                            HStack {
                                Spacer()
                                Text("Gross: ").font(.system(size: 14, weight: .semibold))
                                Text(FormatUtils.formatCurrency(vat.gross, code: po.currency)).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.goldDark)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
                    }

                    // View PDF button
                    Button(action: { downloadPDF() }) {
                        HStack(spacing: 8) {
                            if isLoadingPDF {
                                ActivityIndicatorView()
                            } else {
                                Image(systemName: "doc.richtext").font(.system(size: 14, weight: .semibold))
                            }
                            Text(isLoadingPDF ? "Generating PDF..." : "View PDF")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(isLoadingPDF ? Color.goldDark.opacity(0.6) : Color.goldDark)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingPDF)

                    if let error = pdfError {
                        Text(error).font(.system(size: 11)).foregroundColor(.red)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05)).cornerRadius(8)
                    }

                    // Actions
                    if canEdit || vis.canApprove {
                        Divider()
                        HStack(spacing: 12) {
                            if canEdit {
                                Button(action: { onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { appState.editingPO = po } }) {
                                    HStack { Image(systemName: "pencil"); Text("Edit") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark, lineWidth: 1))
                                }
                                Button(action: { onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { appState.deleteTarget = po } }) {
                                    HStack { Image(systemName: "trash"); Text("Delete") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                }
                            }
                            Spacer()
                            if vis.canApprove {
                                Button(action: { onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { appState.rejectTarget = po; appState.showRejectSheet = true } }) {
                                    Text("Reject").font(.system(size: 13, weight: .bold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                }
                                Button(action: { appState.approvePO(po); onClose() }) {
                                    Text("Approve").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8).background(Color.green).cornerRadius(8)
                                }
                            }
                        }
                    }
                }.padding()
            }

            // Hidden NavigationLink — pushes PDF viewer page
            NavigationLink(
                destination: PDFViewerPage(
                    pdfData: pdfData ?? Data(),
                    fileName: "\(po.poNumber.isEmpty ? "PO" : po.poNumber).pdf"
                ),
                isActive: $navigateToPDF
            ) { EmptyView() }
            .hidden()
        }
    }

    // MARK: - PDF Download

    private func downloadPDF() {
        guard !isLoadingPDF else { return }
        isLoadingPDF = true
        pdfError = nil

        let deptMap: [String: String] = po.lineItems.reduce(into: [:]) { map, li in
            if !li.department.isEmpty, map[li.department] == nil {
                let dept = DepartmentsData.sorted.first { $0.id == li.department || $0.identifier == li.department }
                map[li.department] = dept?.displayName ?? li.department
            }
        }

        let displayNames: [String: Any] = [
            "vendor": po.vendor,
            "vendorAddress": po.vendorAddress,
            "department": po.department,
            "raised_by_name": UsersData.byId[po.userId]?.fullName ?? "",
            "departmentMap": deptMap
        ]

        pdfCancellable = APIClient.shared.post("/api/v2/purchase-orders/\(po.id)/pdf", body: displayNames)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoadingPDF = false
                if case .failure(let error) = completion {
                    self.pdfError = "Failed to generate PDF: \(error.localizedDescription)"
                    print("❌ PDF generation failed: \(error)")
                }
            }, receiveValue: { data in
                self.isLoadingPDF = false
                self.pdfData = data
                self.navigateToPDF = true
                print("✅ PDF generated: \(data.count) bytes")
            })
    }
}

// MARK: - PDF Viewer Page (Navigation push destination)

struct PDFViewerPage: View {
    let pdfData: Data
    let fileName: String
    @Environment(\.presentationMode) var presentationMode
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            PDFWebView(pdfData: pdfData)
                .edgesIgnoringSafeArea(.bottom)
        }
        .navigationBarTitle(Text(fileName), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }.foregroundColor(.goldDark)
            },
            trailing: Button(action: { showShareSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.goldDark)
            }
        )
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [PDFDataItem(data: pdfData, fileName: fileName)])
        }
    }
}

// MARK: - WKWebView wrapper for PDF rendering

struct PDFWebView: UIViewRepresentable {
    let pdfData: Data

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(pdfData, mimeType: "application/pdf", characterEncodingName: "utf-8", baseURL: URL(fileURLWithPath: "/"))
    }
}

// MARK: - Share Sheet (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

class PDFDataItem: NSObject, UIActivityItemSource {
    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        return data
    }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        return tempURL
    }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileName.replacingOccurrences(of: ".pdf", with: "")
    }

    func activityViewController(_ controller: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.adobe.pdf"
    }
}

// MARK: - Activity Indicator (iOS 13 compatible)

struct ActivityIndicatorView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.startAnimating()
        return indicator
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 13))
            Spacer()
        }
    }
}
