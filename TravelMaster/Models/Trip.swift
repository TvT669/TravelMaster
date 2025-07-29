//
//  Trip.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/7/29.
//

import Foundation
import SwiftData

@Model
class Trip {
    var departureLocation: String
    var destination: String
    var departureDate: Date
    var returnDate: Date
    var budget: Double
    var budgetTypeRawValue: String // 存储枚举的原始值
    var id: UUID
    
    init(departureLocation: String, destination: String, departureDate: Date, returnDate: Date, budget: Double, budgetType: BudgetType) {
        self.departureLocation = departureLocation
        self.destination = destination
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.budget = budget
        self.budgetTypeRawValue = budgetType.rawValue
        self.id = UUID()
    }
    
    // 计算属性来获取和设置budgetType
    var budgetType: BudgetType {
        get {
            return BudgetType(rawValue: budgetTypeRawValue) ?? .comfortable
        }
        set {
            budgetTypeRawValue = newValue.rawValue
        }
    }
    
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: departureDate, to: returnDate).day ?? 0
    }
}

enum BudgetType: String, CaseIterable, Codable {
    case economic = "经济型"
    case comfortable = "舒适型"
    case highQuality = "高品质"
    case luxury = "豪华型"
    case superLuxury = "至豪型"
    case ultraLuxury = "超豪型"
    
    var amount: Double {
        switch self {
        case .economic: return 5000
        case .comfortable: return 10000
        case .highQuality: return 15000
        case .luxury: return 20000
        case .superLuxury: return 30000
        case .ultraLuxury: return 50000
        }
    }
}
