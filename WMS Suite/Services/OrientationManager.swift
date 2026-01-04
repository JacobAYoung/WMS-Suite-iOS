//
//  OrientationManager.swift
//  WMS Suite
//
//  Manages device orientation preferences
//

import SwiftUI
import UIKit

/// Helper to manage orientation locking
class OrientationManager: ObservableObject {
    
    /// Lock iPad to landscape orientation only
    static func lockIPadToLandscape() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        
        // Set supported orientations to landscape only for iPad
        if #available(iOS 16.0, *) {
            // iOS 16+ uses different API
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        } else {
            // iOS 15 and earlier
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        }
    }
    
    /// Allow all orientations (used for iPhone)
    static func allowAllOrientations() {
        // Reset to allow all orientations
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
        }
    }
}

/// ViewModifier to lock orientation for a specific view
struct DeviceOrientationViewModifier: ViewModifier {
    let orientation: UIInterfaceOrientationMask
    let isIPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if isIPad && orientation == .landscape {
                    OrientationManager.lockIPadToLandscape()
                }
            }
            .onDisappear {
                if isIPad {
                    OrientationManager.allowAllOrientations()
                }
            }
    }
}

extension View {
    /// Lock the view to a specific orientation (iPad only)
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) -> some View {
        modifier(DeviceOrientationViewModifier(orientation: orientation))
    }
}
