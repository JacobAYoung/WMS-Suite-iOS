//
//  ShopifyOAuthView.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/23/25.
//

import SwiftUI
import WebKit

struct ShopifyOAuthView: View {
    let storeUrl: String
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    
    var onSuccess: ((String) -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                if let authURL = ShopifyOAuthManager.shared.getAuthorizationURL(storeUrl: storeUrl) {
                    ShopifyWebView(
                        url: authURL,
                        storeUrl: storeUrl,
                        isLoading: $isLoading,
                        onSuccess: { token in
                            onSuccess?(token)
                            dismiss()
                        },
                        onError: { error in
                            errorMessage = error
                            showError = true
                        }
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("OAuth Not Configured")
                            .font(.headline)
                        
                        Text("Please configure your Shopify Client ID in Settings first.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Go Back") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("Connect to Shopify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Authorization Error", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
        }
    }
}

// MARK: - WebView Wrapper

struct ShopifyWebView: UIViewRepresentable {
    let url: URL
    let storeUrl: String
    @Binding var isLoading: Bool
    let onSuccess: (String) -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ShopifyWebView
        
        init(_ parent: ShopifyWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Check if this is the redirect URL
            if url.absoluteString.starts(with: "wmssuite://shopify/callback") {
                // Parse the URL components
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    parent.onError("Failed to parse redirect URL")
                    decisionHandler(.cancel)
                    return
                }
                
                // Check for error
                if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    let errorDescription = components.queryItems?.first(where: { $0.name == "error_description" })?.value ?? error
                    parent.onError("Authorization failed: \(errorDescription)")
                    decisionHandler(.cancel)
                    return
                }
                
                // Extract code and state
                guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                      let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                    parent.onError("Missing authorization code or state")
                    decisionHandler(.cancel)
                    return
                }
                
                // Exchange code for token
                Task {
                    do {
                        let token = try await ShopifyOAuthManager.shared.exchangeCodeForToken(
                            code: code,
                            storeUrl: parent.storeUrl,
                            state: state
                        )
                        
                        await MainActor.run {
                            parent.onSuccess(token)
                        }
                    } catch {
                        await MainActor.run {
                            parent.onError(error.localizedDescription)
                        }
                    }
                }
                
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Preview

struct ShopifyOAuthView_Previews: PreviewProvider {
    static var previews: some View {
        ShopifyOAuthView(storeUrl: "your-store.myshopify.com")
    }
}
