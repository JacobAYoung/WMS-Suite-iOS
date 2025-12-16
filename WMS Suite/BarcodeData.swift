//
//  BarcodeData.swift
//  WMS Suite
//
//  Created by Jacob Young on 12/13/25.
//

import Foundation
import UIKit

struct BarcodeData: Identifiable {
    let id = UUID()
    let item: InventoryItem
    let image: UIImage
    let data: String
}
