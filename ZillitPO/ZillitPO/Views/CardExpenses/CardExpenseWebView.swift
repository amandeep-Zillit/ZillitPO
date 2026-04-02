//
//  CardExpenseWebView.swift
//  ZillitPO
//

import SwiftUI
import WebKit

struct CardExpenseWebView: View {
    @EnvironmentObject var appState: POViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        CardExpenseWKWebView(
            url: URL(string: "http://localhost:5173/card-expenses/my-receipts")!,
            projectId: appState.projectId,
            userId: appState.userId,
            isAccountant: appState.currentUser?.isAccountant ?? false
        )
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle(Text("Card Expenses"), displayMode: .inline)
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

struct CardExpenseWKWebView: UIViewRepresentable {
    let url: URL
    let projectId: String
    let userId: String
    let isAccountant: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .systemGroupedBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        var request = URLRequest(url: url)
        request.setValue(projectId, forHTTPHeaderField: "x-project-id")
        request.setValue(userId, forHTTPHeaderField: "x-user-id")
        request.setValue(String(isAccountant), forHTTPHeaderField: "x-is-accountant")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
