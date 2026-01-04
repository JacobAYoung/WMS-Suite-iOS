//
//  LoadingView.swift
//  WMS Suite
//
//  Reusable loading overlay component for async operations
//

import SwiftUI

/// A reusable loading overlay that can be displayed during async operations
struct LoadingView: View {
    let message: String
    let isPresented: Bool
    
    init(message: String = "Loading...", isPresented: Bool = true) {
        self.message = message
        self.isPresented = isPresented
    }
    
    var body: some View {
        Group {
            if isPresented {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    // Loading card
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(radius: 10)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isPresented)
            }
        }
    }
}

/// View modifier for adding a loading overlay
struct LoadingModifier: ViewModifier {
    let message: String
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                LoadingView(message: message, isPresented: isLoading)
            }
    }
}

extension View {
    /// Add a loading overlay to any view
    /// - Parameters:
    ///   - isLoading: Whether to show the loading overlay
    ///   - message: The message to display (default: "Loading...")
    func loading(_ isLoading: Bool, message: String = "Loading...") -> some View {
        modifier(LoadingModifier(message: message, isLoading: isLoading))
    }
}

// MARK: - Preview

#Preview("Loading View") {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack(spacing: 40) {
            Text("Sample Content")
                .font(.title)
            
            Button("Test Button") { }
                .buttonStyle(.borderedProminent)
        }
        
        LoadingView(message: "Syncing data...")
    }
}

#Preview("Loading Modifier") {
    NavigationView {
        List {
            ForEach(0..<5) { i in
                Text("Item \(i)")
            }
        }
        .navigationTitle("Test View")
        .loading(true, message: "Loading items...")
    }
}
