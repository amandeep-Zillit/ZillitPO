import SwiftUI
import UIKit
import WebKit

struct UploadReceiptPage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var drafts: [ReceiptDraft] = [ReceiptDraft()]
    @State private var activeDraftIdx: Int = 0
    @State private var navigateToFilePicker = false
    @State private var showCategorySheet = false
    @State private var showCodeSheet = false

    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showError = false

    private var canSubmit: Bool {
        drafts.allSatisfy { d in
            d.hasFile && !d.amount.isEmpty && !d.description.isEmpty && (Double(d.amount) ?? 0) > 0 && d.date != nil
        }
    }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Your Receipts").font(.system(size: 18, weight: .bold))
                        Text("Upload receipts for your card expenses").font(.system(size: 12)).foregroundColor(.secondary)
                    }

                    // Receipt cards
                    ForEach(drafts.indices, id: \.self) { idx in
                        receiptCard(idx: idx)
                    }

                    // Add Another Receipt
                    Button(action: { drafts.append(ReceiptDraft()) }) {
                        Text("+ Add Another Receipt")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.bgSurface).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundColor(Color.borderColor))
                    }.buttonStyle(BorderlessButtonStyle())

                    // Submit
                    Button(action: submitAll) {
                        HStack(spacing: 6) {
                            if isUploading { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                            Text(isUploading ? "Uploading..." : "Submit Receipts")
                        }
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(canSubmit && !isUploading ? Color.gold : Color.gold.opacity(0.4))
                        .cornerRadius(10)
                    }
                    .disabled(!canSubmit || isUploading)
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 30)
            }
        }
        .navigationBarTitle(Text("Add Your Receipts"), displayMode: .inline)
        .background(
            NavigationLink(destination: ClaimFilePickerPage(onFilePicked: { name, data in
                if drafts.indices.contains(activeDraftIdx) {
                    drafts[activeDraftIdx].fileName = name
                    drafts[activeDraftIdx].fileData = data
                }
            }), isActive: $navigateToFilePicker) { EmptyView() }.frame(width: 0, height: 0).hidden()
        )
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(uploadError ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .appActionSheet(title: "Category", isPresented: $showCategorySheet, items:
            claimCategories.map { c in
                .action(c.1) {
                    if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].category = c.0 }
                }
            }
        )
        .appActionSheet(title: "Budget Code", isPresented: $showCodeSheet, items:
            [.action("None") {
                if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].budgetCode = "" }
            }] + costCodeOptions.map { c in
                .action(c.1) {
                    if drafts.indices.contains(activeDraftIdx) { drafts[activeDraftIdx].budgetCode = c.0 }
                }
            }
        )
    }

    @ViewBuilder
    private func receiptCard(idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("RECEIPT \(idx + 1)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.5)
                Spacer()
                if drafts.count > 1 {
                    Button(action: { drafts.remove(at: idx) }) {
                        Text("Remove").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }

            // File upload
            if drafts[idx].hasFile {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip").font(.system(size: 11)).foregroundColor(.green)
                    Text(drafts[idx].displayFileName).font(.system(size: 12)).foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3)).lineLimit(1)
                    Spacer()
                    Button(action: {
                        drafts[idx].fileName = ""
                        drafts[idx].fileData = nil
                    }) {
                        Text("Remove").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Color.red).cornerRadius(4)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
            } else {
                Button(action: { activeDraftIdx = idx; navigateToFilePicker = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc").font(.system(size: 22)).foregroundColor(.gray.opacity(0.4))
                        Text("Upload receipt image or PDF").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                        Text("Tap to browse · JPG, PNG, PDF").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.bgRaised).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(Color.borderColor))
                }.buttonStyle(PlainButtonStyle())
            }

            // Date + Amount
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date of Purchase *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    DateField(
                        date: Binding(
                            get: { drafts[idx].date },
                            set: { drafts[idx].date = $0 }
                        ),
                        placeholder: "Select date",
                        // Receipts can't be dated in the future — cap at
                        // today so the calendar prevents invalid picks.
                        maxDate: Date(),
                        navigationTitle: "Date of Purchase"
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    TextField("£0.00", text: Binding(get: { drafts[idx].amount }, set: { drafts[idx].amount = $0 }))
                        .font(.system(size: 13, design: .monospaced)).keyboardType(.decimalPad)
                        .padding(8).background(Color.bgRaised).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                }
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Description *").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                TextField("What did you purchase?", text: Binding(get: { drafts[idx].description }, set: { drafts[idx].description = $0 }))
                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
            }

            // Category
            VStack(alignment: .leading, spacing: 4) {
                Text("Category").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                Button(action: { activeDraftIdx = idx; showCategorySheet = true }) {
                    HStack {
                        Text(claimCategories.first { $0.0 == drafts[idx].category }?.1 ?? "Materials")
                            .font(.system(size: 13)).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                    }
                    .padding(8).background(Color.bgRaised).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                    .contentShape(Rectangle())
                }.buttonStyle(BorderlessButtonStyle())
            }

            // Mark as urgent / Request top-up
            HStack(spacing: 18) {
                Toggle(isOn: Binding(get: { drafts[idx].isUrgent }, set: { drafts[idx].isUrgent = $0 })) {
                    Text("Mark as urgent").font(.system(size: 12))
                }.toggleStyle(CheckboxToggleStyle())
                Toggle(isOn: Binding(get: { drafts[idx].requestTopUp }, set: { drafts[idx].requestTopUp = $0 })) {
                    Text("Request top-up").font(.system(size: 12))
                }.toggleStyle(CheckboxToggleStyle())
                Spacer()
            }

            // Budget Coding (collapsible)
            VStack(spacing: 0) {
                Button(action: { drafts[idx].budgetCodingExpanded.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: drafts[idx].budgetCodingExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8)).foregroundColor(.gray)
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Budget Coding").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundColor(.secondary)
                        Text("Optional — leave blank if unsure").font(.system(size: 10)).foregroundColor(.gray)
                        Spacer()
                        if !drafts[idx].budgetCode.isEmpty {
                            Text(drafts[idx].budgetCode).font(.system(size: 10, design: .monospaced)).foregroundColor(.green)
                        }
                    }
                    .padding(10).background(Color.bgRaised).contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())

                if drafts[idx].budgetCodingExpanded {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COST CODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                            Button(action: { activeDraftIdx = idx; showCodeSheet = true }) {
                                HStack {
                                    Text(drafts[idx].budgetCode.isEmpty ? "Select code" : (costCodeOptions.first { $0.0 == drafts[idx].budgetCode }?.1 ?? drafts[idx].budgetCode))
                                        .font(.system(size: 13)).foregroundColor(drafts[idx].budgetCode.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 10)).foregroundColor(.gray)
                                }
                                .padding(8).background(Color.bgRaised).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EPISODE").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("e.g. Ep.3", text: Binding(get: { drafts[idx].episode }, set: { drafts[idx].episode = $0 }))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DESCRIPTION").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary).tracking(0.4)
                                TextField("Coding description (optional)", text: Binding(get: { drafts[idx].codedDescription }, set: { drafts[idx].codedDescription = $0 }))
                                    .font(.system(size: 13)).padding(8).background(Color.bgRaised).cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 1))
                            }
                        }
                    }
                    .padding(10)
                    .overlay(Rectangle().fill(Color.borderColor).frame(height: 1), alignment: .top)
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 1))
        }
        .padding(12).background(Color.bgSurface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))
    }

    private func submitAll() {
        guard canSubmit else { return }
        isUploading = true
        let group = DispatchGroup()
        var firstError: String?
        for d in drafts {
            group.enter()
            uploadOne(d) { err in
                if let e = err, firstError == nil { firstError = e }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            isUploading = false
            if let e = firstError { uploadError = e; showError = true; return }
            appState.loadCardTransactions()
            appState.loadCardExpenseReceipts()
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func uploadOne(_ d: ReceiptDraft, completion: @escaping (String?) -> Void) {
        guard let user = appState.currentUser else { completion("No user"); return }
        guard let data = d.fileData else { completion("Failed to read file"); return }
        let fileName = d.fileName.isEmpty ? "receipt.jpg" : d.fileName
        let ext = (fileName as NSString).pathExtension.lowercased()
        let mimeType: String = {
            switch ext {
            case "pdf": return "application/pdf"
            case "png": return "image/png"
            case "heic", "heif": return "image/heic"
            default: return "image/jpeg"
            }
        }()

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(CardExpenseRequest.baseURL)/api/v2/card-expenses/receipts/upload") else {
            completion("Invalid URL"); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data); body.append("\r\n".data(using: .utf8)!)
        addField("userId", user.id ?? "")
        addField("uploaderName", user.fullName ?? "")
        addField("uploaderDepartment", user.displayDepartment)
        addField("amount", d.amount)
        addField("description", d.description)
        addField("category", d.category)
        if let dt = d.date {
            addField("date", String(Int64(dt.timeIntervalSince1970 * 1000)))
        }
        if !d.budgetCode.isEmpty { addField("nominal_code", d.budgetCode) }
        if !d.episode.isEmpty { addField("episode", d.episode) }
        if !d.codedDescription.isEmpty { addField("coded_description", d.codedDescription) }
        if d.isUrgent { addField("uploadType", "urgent") }
        if d.requestTopUp { addField("uploadType", "topup") }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(error.localizedDescription); return }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    completion("Upload failed (\(http.statusCode))"); return
                }
                completion(nil)
            }
        }.resume()
    }

    private func resizeImage(_ img: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = img.size.width, h = img.size.height
        guard max(w, h) > maxDimension else { return img }
        let scale = maxDimension / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        img.draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? img
    }
}

// MARK: - Receipt Document Picker

struct ReceiptDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileName: String?
    @Binding var selectedFileURL: URL?
    @Binding var isPresented: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            p = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            p = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png", "public.image"], in: .import)
        }
        p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ReceiptDocumentPicker
        init(_ parent: ReceiptDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                guard ["pdf", "jpg", "jpeg", "png", "heic", "heif"].contains(url.pathExtension.lowercased()) else { parent.isPresented = false; return }
                parent.selectedFileURL = url; parent.selectedFileName = url.lastPathComponent
            }
            parent.isPresented = false
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.isPresented = false }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Receipt Thumbnail (async image loader, iOS 13 compatible)
// ═══════════════════════════════════════════════════════════════════

struct ReceiptDocumentViewerSheet: View {
    let url: URL
    var fileName: String = "Receipt"
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ReceiptWebViewContent(url: url)
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle(Text(fileName), displayMode: .inline)
                .navigationBarItems(trailing:
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark)
                )
        }
    }
}

class ReceiptImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var failed = false

    func load(url: URL) {
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let data = data, let img = UIImage(data: data) {
                    self?.image = img
                } else {
                    self?.failed = true
                }
            }
        }.resume()
    }
}

struct ReceiptWebViewContent: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(APIClient.shared.userId, forHTTPHeaderField: "x-user-id")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Multiline text input (iOS 13 compatible replacement for TextEditor)

struct ReceiptDraft: Identifiable {
    let id = UUID()
    var fileName: String = ""
    var fileData: Data?
    var date: Date? = nil
    var amount: String = ""
    var description: String = ""
    var category: String = "materials"
    var isUrgent: Bool = false
    var requestTopUp: Bool = false
    var budgetCode: String = ""
    var episode: String = ""
    var codedDescription: String = ""
    var budgetCodingExpanded: Bool = false

    var hasFile: Bool { fileData != nil && !fileName.isEmpty }
    var displayFileName: String { fileName }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14)).foregroundColor(configuration.isOn ? .goldDark : .gray)
                configuration.label
            }
        }.buttonStyle(BorderlessButtonStyle())
    }
}
