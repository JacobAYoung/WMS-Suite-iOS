//
//  QuickActionsBar.swift
//  WMS Suite
//
//  Prominent action bar for inventory operations
//  Replaces hidden floating menu for better discoverability
//

import SwiftUI

/// Prominent action bar for quick inventory operations
/// Shows: Scan, Put Away, Take Out, Print Labels
struct QuickActionsBar: View {
    let onQuickScan: () -> Void
    let onPutAway: () -> Void
    let onTakeOut: () -> Void
    let onPrintLabel: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        if isIPad {
            // iPad: Horizontal layout with more space
            iPadLayout
        } else {
            // iPhone: Compact grid layout
            iPhoneLayout
        }
    }
    
    private var iPadLayout: some View {
        HStack(spacing: 16) {
            QuickActionBarButton(
                icon: "barcode.viewfinder",
                title: "Quick Scan",
                subtitle: "View details",
                color: .blue,
                action: onQuickScan
            )
            
            QuickActionBarButton(
                icon: "arrow.down.to.line.compact",
                title: "Put Away",
                subtitle: "Receive inventory",
                color: .green,
                action: onPutAway
            )
            
            QuickActionBarButton(
                icon: "arrow.up.circle",
                title: "Take Out",
                subtitle: "Remove inventory",
                color: .orange,
                action: onTakeOut
            )
            
            QuickActionBarButton(
                icon: "printer.fill",
                title: "Print Labels",
                subtitle: "Generate barcodes",
                color: .purple,
                action: onPrintLabel
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var iPhoneLayout: some View {
        VStack(spacing: 12) {
            // Top row
            HStack(spacing: 12) {
                CompactActionButton(
                    icon: "barcode.viewfinder",
                    title: "Scan",
                    color: .blue,
                    action: onQuickScan
                )
                
                CompactActionButton(
                    icon: "arrow.down.to.line.compact",
                    title: "Put Away",
                    color: .green,
                    action: onPutAway
                )
            }
            
            // Bottom row
            HStack(spacing: 12) {
                CompactActionButton(
                    icon: "arrow.up.circle",
                    title: "Take Out",
                    color: .orange,
                    action: onTakeOut
                )
                
                CompactActionButton(
                    icon: "printer.fill",
                    title: "Labels",
                    color: .purple,
                    action: onPrintLabel
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// MARK: - Quick Action Bar Button (iPad)

struct QuickActionBarButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Compact Action Button (iPhone)

struct CompactActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                // Icon in circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Label
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview

#Preview("iPhone Layout") {
    VStack {
        QuickActionsBar(
            onQuickScan: { print("Quick Scan") },
            onPutAway: { print("Put Away") },
            onTakeOut: { print("Take Out") },
            onPrintLabel: { print("Print Label") }
        )
        .environment(\.horizontalSizeClass, .compact)
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("iPad Layout") {
    VStack {
        QuickActionsBar(
            onQuickScan: { print("Quick Scan") },
            onPutAway: { print("Put Away") },
            onTakeOut: { print("Take Out") },
            onPrintLabel: { print("Print Label") }
        )
        .environment(\.horizontalSizeClass, .regular)
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
