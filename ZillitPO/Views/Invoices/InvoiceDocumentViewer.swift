import SwiftUI
import UIKit
import WebKit

// MARK: - Invoice Document Viewer

struct InvoiceDocumentViewer: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode

    // Detected kind: nil until HEAD/initial load resolves the Content-Type.
    // Fallbacks to the URL extension so we display immediately when possible.
    @State private var resolvedKind: DocKind? = nil

    enum DocKind { case image, pdf, web }

    private var ext: String { url.pathExtension.lowercased() }
    private var guessedKind: DocKind {
        if ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"].contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        // Unknown — render in WKWebView which handles most types, or probe later.
        return .web
    }

    var body: some View {
        NavigationView {
            Group {
                switch resolvedKind ?? guessedKind {
                case .image:
                    // Zoomable image view for PNG/JPG/HEIC/WebP/etc.
                    InvoiceImageView(url: url)
                case .pdf:
                    // PDFs render natively via WKWebView
                    InvoiceWebView(url: url)
                case .web:
                    // Generic fallback — WKWebView also handles images/PDFs/plain HTML
                    InvoiceWebView(url: url)
                }
            }
            .background(Color.bgBase.edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text(url.lastPathComponent.isEmpty ? "Document" : url.lastPathComponent), displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.goldDark))
            .onAppear { probeContentTypeIfNeeded() }
        }
    }

    /// If the URL has no extension (e.g. /uploads/<upload_id>), probe the
    /// server with a HEAD request to learn whether this is an image or PDF.
    private func probeContentTypeIfNeeded() {
        guard resolvedKind == nil, guessedKind == .web else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        let client = APIClient.shared
        req.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        req.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        req.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            guard let http = resp as? HTTPURLResponse,
                  let type = (http.value(forHTTPHeaderField: "Content-Type")
                              ?? http.value(forHTTPHeaderField: "content-type"))?.lowercased()
            else { return }
            DispatchQueue.main.async {
                if type.contains("image/") { self.resolvedKind = .image }
                else if type.contains("pdf") { self.resolvedKind = .pdf }
                else { self.resolvedKind = .web }
            }
        }.resume()
    }
}

/// Loads an image via URLSession with the same auth headers APIClient uses.
/// Supports pinch-to-zoom via a UIScrollView + UIImageView.
struct InvoiceImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        // Loading spinner
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        spinner.startAnimating()

        // Build authenticated request
        var request = URLRequest(url: url)
        let client = APIClient.shared
        request.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        request.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                spinner.stopAnimating()
                spinner.removeFromSuperview()
                if let data = data, let img = UIImage(data: data) {
                    imageView.image = img
                } else {
                    let label = UILabel()
                    label.text = error?.localizedDescription ?? "Unable to load image"
                    label.textColor = .lightGray
                    label.font = .systemFont(ofSize: 13)
                    label.textAlignment = .center
                    label.numberOfLines = 0
                    label.translatesAutoresizingMaskIntoConstraints = false
                    scrollView.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
                        label.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
                        label.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -32),
                    ])
                }
            }
        }.resume()

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

struct InvoiceWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        webView.isOpaque = false

        // Build request with same headers APIClient uses
        var request = URLRequest(url: url)
        let client = APIClient.shared
        request.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        request.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
