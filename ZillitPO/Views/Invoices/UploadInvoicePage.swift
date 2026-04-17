import SwiftUI
import UIKit

// MARK: - Upload Invoice Page

struct UploadInvoicePage: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    // Step tracking: 1 = pick file, 2 = preview + extract, 3 = type select
    @State private var step: Int = 1

    // File selection
    @State private var selectedImage: UIImage?
    @State private var selectedFileName: String?
    @State private var selectedFileURL: URL?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    // Upload / extraction
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var extraction: InvoiceExtraction?

    // Type selection
    @State private var selectedType: String? = nil // "po", "cheque", "wire"
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage: String?

    private var hasFile: Bool { selectedImage != nil || selectedFileName != nil }

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 20) {
                    if step == 1 { filePickerStep }
                    else if step == 2 { previewStep }
                    else if step == 3 { typeSelectStep }
                }
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Upload Invoice"), displayMode: .inline)
        .sheet(isPresented: $showImagePicker) {
            InvoiceImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage, isPresented: $showImagePicker)
                .onDisappear {
                    if selectedImage != nil { selectedFileName = nil; selectedFileURL = nil; startUpload() }
                }
        }
        // UIImagePickerController with .camera must be presented modally
        // (pushing it via NavigationLink causes a crash when the user taps
        // "Use Photo" because the picker's internal dismiss fights the
        // nav-stack pop). Present it as a full-screen sheet.
        .sheet(isPresented: $showCamera) {
            InvoiceCameraPage(selectedImage: $selectedImage, isActive: $showCamera, onCapture: {
                selectedFileName = nil; selectedFileURL = nil; startUpload()
            })
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showDocumentPicker) {
            InvoiceDocumentPicker(selectedFileName: $selectedFileName, selectedFileURL: $selectedFileURL, isPresented: $showDocumentPicker, errorMessage: $uploadError)
                .onDisappear {
                    if selectedFileName != nil { selectedImage = nil; startUpload() }
                }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
    }

    // ── Step 1: File Picker ──

    private var filePickerStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.up.doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                Text("Upload Invoice").font(.system(size: 20, weight: .bold))
                Text("Select a file to upload your invoice").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.bgSurface).cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8])).foregroundColor(Color.gold.opacity(0.4)))
            )

            VStack(spacing: 12) {
                uploadOptionButton(icon: "camera.fill", title: "Take Photo", subtitle: "Capture invoice with camera") {
                    showCamera = true
                }
                uploadOptionButton(icon: "photo.fill", title: "Photo Library", subtitle: "Choose from saved photos") {
                    imagePickerSource = .photoLibrary; showImagePicker = true
                }
                uploadOptionButton(icon: "doc.fill", title: "Choose File", subtitle: "Upload PDF or document") {
                    showDocumentPicker = true
                }
            }
        }
    }

    // ── Step 2: Preview + Extraction ──

    private var previewStep: some View {
        VStack(spacing: 16) {
            // File preview
            VStack(spacing: 12) {
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 240).cornerRadius(8)
                } else if let name = selectedFileName {
                    Image(systemName: "doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                    Text(name).font(.system(size: 14, weight: .medium)).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 24).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))

            // Extraction status
            if isUploading {
                HStack(spacing: 8) {
                    ActivityIndicator(isAnimating: true).frame(width: 18, height: 18)
                    Text("Extracting invoice data...").font(.system(size: 13)).foregroundColor(.goldDark)
                }
                .padding(12).frame(maxWidth: .infinity)
                .background(Color.gold.opacity(0.08)).cornerRadius(8)
            } else if let error = uploadError {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(error).font(.system(size: 12)).foregroundColor(.red)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.06)).cornerRadius(8)

                Button("Try Again") { startUpload() }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.goldDark)
            } else if extraction != nil {
                // Extraction complete — ready to send
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Invoice data extracted — ready to send").font(.system(size: 12)).foregroundColor(.green)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.06)).cornerRadius(8)
            }

            Spacer().frame(height: 4)

            // Actions
            HStack(spacing: 12) {
                Button("Change File") {
                    extraction = nil; uploadError = nil; isUploading = false
                    selectedImage = nil; selectedFileName = nil; selectedFileURL = nil
                    step = 1
                }
                .font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                Button("Send to Accounts") { step = 3 }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(!isUploading ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .disabled(isUploading)
            }
        }
    }

    // ── Step 3: Type Selection ──

    private var typeSelectStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send to Accounts").font(.system(size: 18, weight: .bold))
                Text("How should this invoice be processed?").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            typeOption(
                value: "po",
                icon: "cart.fill",
                title: "Against Purchase Order",
                subtitle: "Standard invoice matched to an existing PO"
            )
            typeOption(
                value: "cheque",
                icon: "banknote.fill",
                title: "Cheque Request",
                subtitle: "Payment via cheque — no PO required"
            )
            typeOption(
                value: "wire",
                icon: "bolt.fill",
                title: "Wire Request",
                subtitle: "Urgent wire transfer — requires override approval"
            )

            Spacer().frame(height: 4)

            HStack(spacing: 12) {
                Button("Back") { step = 2; selectedType = nil }
                    .font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1))

                Button(action: submitInvoice) {
                    HStack(spacing: 6) {
                        if isSubmitting { ActivityIndicator(isAnimating: true).frame(width: 16, height: 16) }
                        Text(isSubmitting ? "Sending..." : "Confirm & Send")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(selectedType != nil && !isSubmitting ? Color.gold : Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .disabled(selectedType == nil || isSubmitting)
            }
        }
    }

    private func typeOption(value: String, icon: String, title: String, subtitle: String) -> some View {
        Button { selectedType = value } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedType == value ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundColor(selectedType == value ? .gold : .gray)
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(.goldDark)
                    .frame(width: 32, height: 32).background(Color.gold.opacity(0.12)).cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedType == value ? Color.gold : Color.borderColor, lineWidth: selectedType == value ? 1.5 : 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // ── Helpers ──

    private func uploadOptionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }
            .padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }

    private func extractionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }
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

    private func startUpload() {
        step = 2; isUploading = true; uploadError = nil; extraction = nil

        // Build file data
        var fileData: Data?
        var fileName = "invoice"
        var mimeType = "application/octet-stream"

        if let img = selectedImage {
            // Resize large camera photos to max 1600px and compress to stay under server limit
            let resized = resizeImage(img, maxDimension: 2400)
            if let data = resized.jpegData(compressionQuality: 0.8) {
                fileData = data
            }
            fileName = "invoice.jpg"; mimeType = "image/jpeg"
        } else if let url = selectedFileURL {
            let ext = url.pathExtension.lowercased()
            let allowed = ["pdf", "jpg", "jpeg", "png", "heic", "heif"]
            guard allowed.contains(ext) else {
                uploadError = "Only JPEG, PNG and PDF are acceptable"; isUploading = false; step = 1; return
            }
            _ = url.startAccessingSecurityScopedResource()
            if ext == "heic" || ext == "heif" {
                // Convert HEIC/HEIF to JPEG for server compatibility
                if let rawData = try? Data(contentsOf: url), let img = UIImage(data: rawData) {
                    let resized = resizeImage(img, maxDimension: 2400)
                    fileData = resized.jpegData(compressionQuality: 0.8)
                }
                fileName = url.deletingPathExtension().lastPathComponent + ".jpg"
                mimeType = "image/jpeg"
            } else {
                fileData = try? Data(contentsOf: url)
                fileName = url.lastPathComponent
                mimeType = ext == "pdf" ? "application/pdf" : ext == "png" ? "image/png" : "image/jpeg"
            }
            url.stopAccessingSecurityScopedResource()
        }

        guard let data = fileData else {
            uploadError = "Failed to read file"; isUploading = false; return
        }

        // Upload for extraction
        guard let req = APIClient.shared.buildMultipartRequest(
            "/api/v2/invoices/upload", fileData: data, fileName: fileName, mimeType: mimeType, fieldName: "file"
        ) else {
            uploadError = "Failed to build request"; isUploading = false; return
        }

        let task: URLSessionDataTask = APIClient.shared.codableResultTask(with: req) { (result: Result<APIResponse<InvoiceExtraction>?, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.extraction = response?.data
                case .failure(let error):
                    self.uploadError = error.localizedDescription
                }
                self.isUploading = false
            }
        }
        task.resume()
    }

    private func submitInvoice() {
        guard let type = selectedType, let user = appState.currentUser else { return }
        isSubmitting = true

        let ext = extraction
        let payMethod: String = {
            switch type {
            case "wire": return "wire"
            case "cheque": return "cheque"
            default: return "bacs"
            }
        }()

        let supplierName = ext?.supplier?.name ?? selectedFileName ?? "Uploaded invoice"
        var body: [String: Any] = [
            "description": selectedFileName ?? "Uploaded invoice",
            "supplier_name": supplierName,
            "pay_method": payMethod,
            "currency": ext?.currency ?? "GBP",
            "department_id": user.departmentId ?? "",
            "status": "inbox",
            "gross_amount": ext?.grossValue ?? 0,
        ]
        if let ext = ext {
            if ext.netValue > 0 { body["net_amount"] = ext.netValue }
            if ext.vatValue > 0 { body["vat_amount"] = ext.vatValue }
            if let d = ext.invoiceDate, !d.isEmpty { body["invoice_date"] = d }
            if let d = ext.dueDate, !d.isEmpty { body["due_date"] = d }
            if let n = ext.invoiceNumber, !n.isEmpty { body["invoice_number"] = n }
            if let p = ext.poNumber, !p.isEmpty { body["po_number"] = p }
            if let uid = ext.uploadId { body["upload_id"] = uid }
            if let items = ext.lineItems, !items.isEmpty {
                body["line_items"] = items.map { item -> [String: Any] in
                    var li: [String: Any] = [:]
                    if let d = item.description, !d.isEmpty { li["description"] = d }
                    if item.quantityValue > 0 { li["quantity"] = item.quantityValue }
                    if item.unitPriceValue > 0 { li["unit_price"] = item.unitPriceValue }
                    if item.amountValue > 0 { li["amount"] = item.amountValue }
                    return li
                }
            }
        }

        appState.submitInvoice(body) { success, error in
            isSubmitting = false
            if success {
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = error ?? "Submission failed"
                showError = true
            }
        }
    }
}

// MARK: - Camera Page (Navigation push)

struct InvoiceCameraPage: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isActive: Bool
    var onCapture: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Guard the source type — UIImagePickerController crashes with
        // NSInvalidArgumentException "Source type N not available" if we set
        // an unavailable source (e.g. .camera on the Simulator or a
        // camera-less iPad). Fall back to .photoLibrary in that case.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: InvoiceCameraPage
        init(_ parent: InvoiceCameraPage) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.isActive = false
            parent.onCapture()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isActive = false
        }
    }
}


// MARK: - Image Picker (UIKit wrapper)

struct InvoiceImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: InvoiceImagePicker
        init(_ parent: InvoiceImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Document Picker (UIKit wrapper)

struct InvoiceDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileName: String?
    @Binding var selectedFileURL: URL?
    @Binding var isPresented: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png", "public.image"], in: .import)
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: InvoiceDocumentPicker
        init(_ parent: InvoiceDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                let ext = url.pathExtension.lowercased()
                let allowed = ["pdf", "jpg", "jpeg", "png", "heic", "heif"]
                guard allowed.contains(ext) else {
                    parent.errorMessage = "Only JPEG, PNG and PDF are acceptable"
                    parent.isPresented = false
                    return
                }
                parent.selectedFileURL = url
                parent.selectedFileName = url.lastPathComponent
            }
            parent.isPresented = false
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
