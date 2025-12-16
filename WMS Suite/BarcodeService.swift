//
//  BarcodeService.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation
import CoreImage
import UIKit

class BarcodeService: BarcodeServiceProtocol {
    func generateBarcode(data: String, label: String? = nil) -> UIImage {
        let filter = CIFilter(name: "CICode128BarcodeGenerator")!
        filter.setValue(data.data(using: .utf8), forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return UIImage() }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let size = scaledImage.extent.size
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.width, height: size.height + 30))
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height + 30)))
            
            if let cgImage = CIContext().createCGImage(scaledImage, from: scaledImage.extent) {
                cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
            
            if let label = label {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor.black
                ]
                let textSize = label.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: size.height + 5,
                    width: textSize.width,
                    height: textSize.height
                )
                label.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
    
    func printBarcode(_ image: UIImage) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Barcode Print"
        
        printController.printInfo = printInfo
        printController.printingItem = image
        
        printController.present(animated: true) { _, completed, error in
            if completed {
                print("Barcode printed successfully")
            } else if let error = error {
                print("Print error: \(error.localizedDescription)")
            }
        }
    }
}
