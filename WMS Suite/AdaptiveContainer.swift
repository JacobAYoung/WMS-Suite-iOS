//
//  AdaptiveContainer.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/20/25.
//

import SwiftUI

// MARK: - Adaptive Container

/// Use this to wrap content that should be centered/limited on iPad
struct AdaptiveContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(maxWidth: geometry.size.width > 800 ? 800 : .infinity)
                    .frame(maxWidth: .infinity) // Center it
            }
        }
    }
}

// MARK: - Adaptive Grid

/// Automatically adjusts columns based on screen size
struct AdaptiveGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    private var columns: [GridItem] {
        let columnCount = sizeClass == .regular ? 2 : 1 // 2 columns on iPad, 1 on iPhone
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                content(item)
            }
        }
        .padding()
    }
}

// MARK: - Device Type Helper

extension UIDevice {
    var isiPad: Bool {
        userInterfaceIdiom == .pad
    }
    
    var isiPhone: Bool {
        userInterfaceIdiom == .phone
    }
}

// MARK: - Adaptive Font Sizes

extension Font {
    static func adaptiveTitle() -> Font {
        UIDevice.current.isiPad ? .largeTitle : .title
    }
    
    static func adaptiveHeadline() -> Font {
        UIDevice.current.isiPad ? .title2 : .headline
    }
    
    static func adaptiveBody() -> Font {
        UIDevice.current.isiPad ? .title3 : .body
    }
}
