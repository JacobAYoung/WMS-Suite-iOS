//
//  BarcodeServiceProtocol.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation
import UIKit

protocol BarcodeServiceProtocol {
    func generateBarcode(data: String, label: String?) -> UIImage
    func printBarcode(_ image: UIImage)
}
