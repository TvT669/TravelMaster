//
//  Item.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
