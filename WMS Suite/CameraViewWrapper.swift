//
//  CameraViewWrapper.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import SwiftUI
import UIKit

struct CameraViewWrapper: UIViewControllerRepresentable {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isProcessing: Bool
    @Binding var detectedCount: Int
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraViewWrapper
        
        init(_ parent: CameraViewWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.cameraManager.capturedImage = image
                parent.isProcessing = true
                
                parent.cameraManager.processImage(image) { count in
                    self.parent.detectedCount = count
                    self.parent.isProcessing = false
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
