//
//  CameraManager.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation
import AVFoundation
import Vision
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    func processImage(_ image: UIImage, completion: @escaping (Int) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(0)
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let observations = request.results as? [VNRectangleObservation] else {
                completion(0)
                return
            }
            
            let count = observations.count
            DispatchQueue.main.async {
                completion(count)
            }
        }
        
        request.minimumSize = 0.1
        request.maximumObservations = 100
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform detection: \(error)")
                DispatchQueue.main.async {
                    completion(0)
                }
            }
        }
    }
}
