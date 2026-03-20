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
    @State private var navigateToEdit = false
    @State private var pdfData: Data?
    @State private var isLoadingPDF = false
    @State private var pdfError: String?
    @State private var pdfCancellable: AnyCancellable?

    private var vat: VATResult { VATHelpers.calcVat(po.netAmount, treatment: po.vatTreatment) }
    private var vis: ApprovalVisibility {
        let c = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
            ?? ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId)
        guard let c = c
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
                        HStack {
                            Text("Status").font(.system(size: 12)).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
                            statusValueView
                            Spacer()
                        }
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
                                Button(action: { navigateToEdit = true }) {
                                    HStack { Image(systemName: "pencil"); Text("Edit") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldDark, lineWidth: 1))
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                                Button(action: { appState.deleteTarget = po }) {
                                    HStack { Image(systemName: "trash"); Text("Delete") }.font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                            }
                            Spacer()
                            if vis.canApprove {
                                Button(action: { appState.rejectTarget = po; appState.showRejectSheet = true }) {
                                    Text("Reject").font(.system(size: 13, weight: .bold)).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.vertical, 8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
                                Button(action: { appState.approvePO(po); onClose() }) {
                                    Text("Approve").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8).background(Color.green).cornerRadius(8)
                                        .contentShape(Rectangle())
                                }.buttonStyle(BorderlessButtonStyle())
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

            // Hidden NavigationLink — pushes Edit PO form page
            NavigationLink(
                destination: POEditFormPage(editingPO: po).environmentObject(appState),
                isActive: $navigateToEdit
            ) { EmptyView() }
            .hidden()
        }
    }

    // MARK: - Status Value View

    private var statusValueView: some View {
        let resolvedConfig = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
        let totalTiers = ApprovalHelpers.getTotalTiers(resolvedConfig)
        let approvedCount = po.approvals.count
        let statusColor: Color = {
            if po.poStatus == .rejected { return .red }
            if po.poStatus == .approved || po.poStatus == .posted { return .green }
            if po.poStatus == .pending || po.poStatus == .acctEntered { return .goldDark }
            if po.poStatus == .draft { return .orange }
            return .gray
        }()
        let label: String = {
            if po.poStatus == .pending && totalTiers > 0 {
                return "Pending (\(approvedCount)/\(totalTiers))"
            }
            return po.poStatus.displayName
        }()
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(statusColor.opacity(0.1)).cornerRadius(4)
    }

    // MARK: - Approval Flow Section

    private var approvalFlowSection: some View {
        let cfgA = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId, amount: po.totalAmount)
        let cfgB = ApprovalHelpers.resolveConfig(appState.tierConfigRows, deptId: po.departmentId)
        let cfg = (ApprovalHelpers.getTotalTiers(cfgA) >= ApprovalHelpers.getTotalTiers(cfgB)) ? cfgA : cfgB
        let totalTiers = ApprovalHelpers.getTotalTiers(cfg)
        let approvedSet = Dictionary(grouping: po.approvals, by: { $0.tierNumber })

        return Group {
            if totalTiers > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with pending count
                    HStack {
                        Image(systemName: "person.3.fill").font(.system(size: 12)).foregroundColor(.goldDark)
                        Text("APPROVAL FLOW").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        if po.poStatus == .pending {
                            Text("\(po.approvals.count)/\(totalTiers) Approved")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.goldDark)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.gold.opacity(0.15)).cornerRadius(4)
                        } else if po.poStatus == .approved || po.poStatus == .acctEntered || po.poStatus == .posted {
                            Text("Fully Approved")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.green.opacity(0.1)).cornerRadius(4)
                        } else if po.poStatus == .rejected {
                            Text("Rejected")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.red.opacity(0.1)).cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

                    // Tier rows
                    if let config = cfg {
                        ForEach(1...totalTiers, id: \.self) { tierNum in
                            tierRow(tierNum: tierNum, totalTiers: totalTiers, config: config, approvedSet: approvedSet)
                        }
                    }

                    // Raised by
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.goldDark).frame(width: 22, height: 22)
                            Text(String((UsersData.byId[po.userId]?.firstName ?? "?").prefix(1)))
                                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Raised by").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(UsersData.byId[po.userId]?.fullName ?? po.userId)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        if po.createdAt > 0 {
                            Text(FormatUtils.formatTimestamp(po.raisedAt ?? po.createdAt)).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6).opacity(0.5))
                }
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func tierRow(tierNum: Int, totalTiers: Int, config: LegacyTierConfig, approvedSet: [Int: [Approval]]) -> some View {
        let entries = config[String(tierNum)] ?? []
        let tierApprovals = approvedSet[tierNum] ?? []
        let isApproved = !tierApprovals.isEmpty
        let nextTier = ApprovalHelpers.getNextTier(po: po, config: config)
        let isCurrentTier = (nextTier == tierNum) && po.poStatus == .pending
        let isRejected = po.poStatus == .rejected && !isApproved && (nextTier == nil || tierNum >= (nextTier ?? 0))

        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.horizontal, 14)

            HStack(alignment: .top, spacing: 10) {
                // Status indicator
                VStack(spacing: 0) {
                    if tierNum > 1 {
                        Rectangle().fill(isApproved ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                            .frame(width: 2, height: 8)
                    }
                    ZStack {
                        Circle()
                            .fill(isApproved ? Color.green : isRejected ? Color.red : isCurrentTier ? Color.goldDark : Color.gray.opacity(0.3))
                            .frame(width: 22, height: 22)
                        if isApproved {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        } else if isRejected {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        } else if isCurrentTier {
                            Image(systemName: "clock").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        } else {
                            Text("\(tierNum)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    if tierNum < totalTiers {
                        Rectangle().fill(isApproved ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                            .frame(width: 2, height: 8)
                    }
                }

                // Tier info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tier \(tierNum)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isCurrentTier ? .goldDark : .primary)
                        if isApproved {
                            Text("Approved").font(.system(size: 9, weight: .semibold)).foregroundColor(.green)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.green.opacity(0.1)).cornerRadius(3)
                        } else if isCurrentTier {
                            Text("Awaiting").font(.system(size: 9, weight: .semibold)).foregroundColor(.goldDark)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gold.opacity(0.15)).cornerRadius(3)
                        } else if isRejected {
                            Text("Rejected").font(.system(size: 9, weight: .semibold)).foregroundColor(.red)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.red.opacity(0.1)).cornerRadius(3)
                        }
                        Spacer()
                    }

                    // Approver names
                    ForEach(entries, id: \.userId) { entry in
                        let user = UsersData.byId[entry.userId]
                        let name = user?.fullName ?? entry.userId
                        let approved = tierApprovals.first { $0.userId == entry.userId }
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(approved != nil ? Color.green.opacity(0.15) : isCurrentTier ? Color.gold.opacity(0.15) : Color.gray.opacity(0.1))
                                    .frame(width: 20, height: 20)
                                Text(String(name.prefix(1)))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(approved != nil ? .green : isCurrentTier ? .goldDark : .secondary)
                            }
                            Text(name).font(.system(size: 11)).foregroundColor(.primary).lineLimit(1)
                            if let a = approved {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(.green)
                                Text(FormatUtils.formatTimestamp(a.approvedAt)).font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }
                    }
                }.padding(.vertical, 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
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

// MARK: - Edit PO Form Page (pushed from detail page)

struct POEditFormPage: View {
    let editingPO: PurchaseOrder
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            POFormView(
                editingPO: editingPO,
                resumeDraft: nil,
                prefilledVendorId: nil,
                onBack: {
                    // Pop back to the PO list (root) after update
                    appState.popToRoot = true
                }
            )
        }
        .navigationBarTitle(Text("Edit PO"), displayMode: .inline)
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
