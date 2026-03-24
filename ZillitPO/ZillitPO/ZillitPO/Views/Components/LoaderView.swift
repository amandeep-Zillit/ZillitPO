import SwiftUI

struct LoaderView: View {
    var message = "Loading..."
    var body: some View {
        VStack(spacing: 12) {
            #if canImport(UIKit)
            ActivityIndicator(isAnimating: true)
            #else
            Text("⟳").font(.system(size: 24))
            #endif
            Text(message).font(.system(size: 12)).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

#if canImport(UIKit)
import UIKit

struct ActivityIndicator: UIViewRepresentable {
    var isAnimating: Bool
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: .medium); v.hidesWhenStopped = true; return v
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if isAnimating { uiView.startAnimating() } else { uiView.stopAnimating() }
    }
}
#endif
