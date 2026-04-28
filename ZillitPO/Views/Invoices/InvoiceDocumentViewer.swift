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

/// PDF / generic document viewer.
///
/// We deliberately **don't** call `webView.load(request:)` directly
/// any more. That path has two problems on iOS:
///   1. WKWebView strips custom headers (`x-project-id` etc.) from
///      the first-party request in many iOS 16+ builds, so auth
///      fails silently and the user sees a blank screen.
///   2. Any 30x redirect (e.g. `/api/v2/invoices/{id}/file` → real
///      uploads URL) starts a fresh navigation that WKWebView
///      handles WITHOUT the headers, producing a 403 with no signal.
///
/// Instead we download the bytes ourselves via URLSession (same
/// headers the rest of the app uses), write to a tmp file, and load
/// the local URL via `webView.loadFileURL(...)`. PDF rendering works,
/// status/headers are visible to us, and we can surface a proper
/// error message inside the web view when something goes wrong.
struct InvoiceWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        webView.isOpaque = false

        let client = APIClient.shared
        var request = URLRequest(url: url)
        request.setValue(client.projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(client.userId, forHTTPHeaderField: "x-user-id")
        request.setValue(String(client.isAccountant), forHTTPHeaderField: "x-is-accountant")

        debugPrint("🧾 InvoiceDocumentViewer → \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { [weak webView] data, response, error in
            guard let webView = webView else { return }
            DispatchQueue.main.async {
                // 1) Network-level failure (no response).
                if let err = error {
                    renderError(in: webView, title: "Couldn't load document", body: err.localizedDescription)
                    return
                }
                let http = response as? HTTPURLResponse
                let status = http?.statusCode ?? 0

                // 2) Non-2xx HTTP status → show explanatory placeholder.
                guard (200...299).contains(status), let data = data, !data.isEmpty else {
                    let body: String = {
                        if status == 404 { return "This invoice doesn't have an uploaded document." }
                        if status == 401 || status == 403 { return "You don't have access to this document." }
                        if status == 0 { return "The server returned no response." }
                        return "The server responded with HTTP \(status)."
                    }()
                    renderError(in: webView, title: "Unable to show document", body: body)
                    return
                }

                // 3) Good bytes — infer extension from the response's
                //    Content-Type so WKWebView picks the right renderer
                //    (PDF viewer vs. plain text vs. image).
                let ext: String = {
                    let ct = (http?.value(forHTTPHeaderField: "Content-Type")
                              ?? http?.value(forHTTPHeaderField: "content-type") ?? "").lowercased()
                    if ct.contains("pdf") { return "pdf" }
                    if ct.contains("png") { return "png" }
                    if ct.contains("jpeg") || ct.contains("jpg") { return "jpg" }
                    if ct.contains("html") { return "html" }
                    // Fall back to the URL's own extension
                    return URL(string: url.absoluteString)?.pathExtension.lowercased() ?? "bin"
                }()

                // 4) Write to tmp, load via file URL so WKWebView reads
                //    the bytes directly — no header dance, no redirects.
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("invoice-\(UUID().uuidString).\(ext)")
                do {
                    try data.write(to: tmp)
                    webView.loadFileURL(tmp, allowingReadAccessTo: tmp.deletingLastPathComponent())
                } catch {
                    renderError(in: webView, title: "Couldn't save document", body: error.localizedDescription)
                }
            }
        }.resume()

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Render a lightweight branded error screen inside the WKWebView
    /// so the viewer never sits on an empty/blank surface.
    private func renderError(in webView: WKWebView, title: String, body: String) {
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>
        body { font-family: -apple-system, system-ui; padding: 32px; text-align: center; color: #6b6f76;
               background: #f5f6f8; }
        .title { font-size: 16px; font-weight: 600; color: #1a1a1a; margin-bottom: 8px; }
        .body  { font-size: 13px; line-height: 1.45; }
        .icon  { font-size: 40px; margin-bottom: 14px; opacity: 0.4; }
        </style></head>
        <body><div class="icon">📄</div><div class="title">\(escape(title))</div><div class="body">\(escape(body))</div></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
