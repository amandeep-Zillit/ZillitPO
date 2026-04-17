import SwiftUI
import UIKit

struct ClaimFilePickerPage: View {
    var onFilePicked: (String, Data) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showDocPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedFileName: String?
    @State private var selectedFileURL: URL?

    var body: some View {
        ZStack {
            Color.bgBase.edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.up.doc.fill").font(.system(size: 48)).foregroundColor(.gold)
                        Text("Upload Receipt").font(.system(size: 20, weight: .bold))
                        Text("Select a receipt photo or PDF").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.bgSurface).cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.gold.opacity(0.3), lineWidth: 1)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8])).foregroundColor(Color.gold.opacity(0.4)))
                    )

                    VStack(spacing: 12) {
                        pickerBtn(icon: "camera.fill", title: "Take Photo", sub: "Capture receipt with camera") { showCamera = true }
                        pickerBtn(icon: "photo.fill", title: "Photo Library", sub: "Choose from saved photos") { showImagePicker = true }
                        pickerBtn(icon: "doc.fill", title: "Choose File", sub: "Upload PDF or document") { showDocPicker = true }
                    }

                    HStack(spacing: 8) {
                        ForEach(["JPG", "PNG", "HEIC", "PDF"], id: \.self) { f in
                            Text(f).font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray).padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.bgRaised).cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.borderColor, lineWidth: 1))
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 20)
            }
        }
        .navigationBarTitle(Text("Upload Receipt"), displayMode: .inline)
        .sheet(isPresented: $showImagePicker) {
            ClaimImagePickerView { img, name in
                if let data = img.jpegData(compressionQuality: 0.8) {
                    onFilePicked(name, data); presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .sheet(isPresented: $showDocPicker) {
            ClaimDocPickerView { name, data in
                onFilePicked(name, data); presentationMode.wrappedValue.dismiss()
            }
        }
        // UIImagePickerController (.camera) must be presented modally — pushing
        // it via NavigationLink crashes on "Use Photo" because the picker's
        // internal dismiss fights the nav-stack pop.
        .sheet(isPresented: $showCamera) {
            ClaimCameraView(isPresented: $showCamera) { img, name in
                if let data = img.jpegData(compressionQuality: 0.8) {
                    onFilePicked(name, data)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }

    private func pickerBtn(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.goldDark)
                    .frame(width: 36, height: 36).background(Color.gold.opacity(0.15)).cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(sub).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.gray)
            }.padding(14).background(Color.bgSurface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(BorderlessButtonStyle())
    }
}

// MARK: - UIKit Wrappers for Claim File Picker

struct ClaimCameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (UIImage, String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        // Fall back to photoLibrary on devices without a camera (Simulator,
        // camera-less iPad). Without this check the picker crashes with
        // NSInvalidArgumentException "Source type 1 not available".
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ClaimCameraView; init(_ p: ClaimCameraView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Flip the sheet binding first (SwiftUI dismisses the modal) then
            // hand the image back. Don't call picker.dismiss(animated:) — in a
            // sheet it fights the binding's own dismissal and can crash.
            parent.isPresented = false
            if let img = info[.originalImage] as? UIImage { parent.onPick(img, "photo.jpg") }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

struct ClaimImagePickerView: UIViewControllerRepresentable {
    var onPick: (UIImage, String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .photoLibrary; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ClaimImagePickerView; init(_ p: ClaimImagePickerView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPick(img, (info[.imageURL] as? URL)?.lastPathComponent ?? "receipt.jpg") }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

struct ClaimDocPickerView: UIViewControllerRepresentable {
    var onPick: (String, Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            p = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png, .image], asCopy: true)
        } else {
            p = UIDocumentPickerViewController(documentTypes: ["public.pdf", "public.jpeg", "public.png"], in: .import)
        }
        p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ClaimDocPickerView; init(_ p: ClaimDocPickerView) { parent = p }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            if let data = try? Data(contentsOf: url) { parent.onPick(url.lastPathComponent, data) }
            url.stopAccessingSecurityScopedResource()
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}


