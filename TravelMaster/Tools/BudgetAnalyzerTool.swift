//
//  BudgetAnalyzerTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/16.
//

import Foundation

struct BudgetAnalyzerTool: Tool {
    let name = "budget_analyzer"
    let description = "分析旅行预算分配建议，根据目的地消费水平、天数、旅行类型提供详细的预算分解"
    
    var parameters: [String: Any] {
        [
            "total_budget": [
                "type": "number",
                "description": "总预算（人民币元）"
            ],
            "days": [
                "type": "integer", 
                "description": "旅行天数"
            ],
            "destination": [
                "type": "string",
                "description": "目的地城市或国家"
            ],
            "travel_type": [
                "type": "string",
                "description": "旅行类型：budget/comfort/luxury",
                "default": "comfort"
            ],
            "travelers": [
                "type": "integer",
                "description": "旅行人数",
                "default": 1
            ],
            "departure_city": [
                "type": "string",
                "description": "出发城市",
                "default": "上海"
            ]
        ]
    }
    
    func toAPIFormat() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": parameters,
                    "required": ["total_budget", "days", "destination"]
                ]
            ]
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        let totalBudget = arguments["total_budget"] as? Double ?? 5000
        let days = arguments["days"] as? Int ?? 3
        let destination = arguments["destination"] as? String ?? ""
        let travelType = arguments["travel_type"] as? String ?? "comfort"
        let travelers = arguments["travelers"] as? Int ?? 1
        let departureCity = arguments["departure_city"] as? String ?? "上海"
        
        guard !destination.isEmpty, days > 0, totalBudget > 0 else {
            throw AIError.configurationError("目的地、天数和总预算必填且有效")
        }
        
        // 1. 分析目的地消费水平
        let destinationInfo = analyzeDestination(destination)
        
        // 2. 根据旅行类型调整预算分配
        let baseAllocation = calculateBaseAllocation(
            destination: destination,
            isInternational: destinationInfo.isInternational,
            travelType: travelType,
            departureCity: departureCity
        )
        
        // 3. 计算详细预算分配
        let budgetBreakdown = calculateDetailedBudget(
            totalBudget: totalBudget,
            days: days,
            travelers: travelers,
            allocation: baseAllocation,
            destinationInfo: destinationInfo
        )
        
        // 4. 生成个性化建议
        let recommendations = generateRecommendations(
            budget: totalBudget,
            days: days,
            destination: destination,
            travelType: travelType,
            destinationInfo: destinationInfo
        )
        
        // 5. 风险评估
        let riskAssessment = assessBudgetRisk(
            totalBudget: totalBudget,
            days: days,
            destination: destination,
            destinationInfo: destinationInfo
        )
        
        let result: [String: Any] = [
            "destination_analysis": [
                "destination": destination,
                "cost_level": destinationInfo.costLevel,
                "is_international": destinationInfo.isInternational,
                "currency": destinationInfo.currency,
                "exchange_rate_note": destinationInfo.exchangeNote
            ],
            "budget_breakdown": budgetBreakdown,
            "daily_budget": [
                "per_person": totalBudget / Double(days * travelers),
                "total": totalBudget / Double(days),
                "recommended_cash": calculateCashNeeded(budgetBreakdown),
                "emergency_fund": budgetBreakdown["emergency"] as? Double ?? 0
            ],
            "cost_comparison": generateCostComparison(destinationInfo, totalBudget, days),
            "recommendations": recommendations,
            "risk_assessment": riskAssessment,
            "money_saving_tips": generateMoneySavingTips(destination, travelType)
        ]
        
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - 私有方法
    
    private func analyzeDestination(_ destination: String) -> DestinationInfo {
        let dest = destination.lowercased()
        
        // 国际目的地分析
        let internationalDestinations = [
            "日本": DestinationInfo(costLevel: "高", isInternational: true, currency: "日元", exchangeNote: "建议准备现金，很多地方不支持信用卡"),
            "韩国": DestinationInfo(costLevel: "中高", isInternational: true, currency: "韩元", exchangeNote: "移动支付发达"),
            "泰国": DestinationInfo(costLevel: "低", isInternational: true, currency: "泰铢", exchangeNote: "现金为主，准备小面额"),
            "新加坡": DestinationInfo(costLevel: "高", isInternational: true, currency: "新加坡元", exchangeNote: "移动支付普及"),
            "美国": DestinationInfo(costLevel: "高", isInternational: true, currency: "美元", exchangeNote: "信用卡为主，准备少量现金"),
            "欧洲": DestinationInfo(costLevel: "高", isInternational: true, currency: "欧元", exchangeNote: "信用卡普及，部分地区需现金"),
            "东京": DestinationInfo(costLevel: "高", isInternational: true, currency: "日元", exchangeNote: "建议准备现金"),
            "首尔": DestinationInfo(costLevel: "中高", isInternational: true, currency: "韩元", exchangeNote: "移动支付发达"),
            "曼谷": DestinationInfo(costLevel: "低", isInternational: true, currency: "泰铢", exchangeNote: "现金为主")
        ]
        
        // 国内目的地分析
        let domesticDestinations = [
            "北京": DestinationInfo(costLevel: "中高", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "上海": DestinationInfo(costLevel: "中高", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "深圳": DestinationInfo(costLevel: "中高", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "广州": DestinationInfo(costLevel: "中", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "成都": DestinationInfo(costLevel: "中", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "西安": DestinationInfo(costLevel: "中", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "杭州": DestinationInfo(costLevel: "中", isInternational: false, currency: "人民币", exchangeNote: "移动支付普及"),
            "三亚": DestinationInfo(costLevel: "中高", isInternational: false, currency: "人民币", exchangeNote: "旅游城市，价格较高"),
            "丽江": DestinationInfo(costLevel: "中", isInternational: false, currency: "人民币", exchangeNote: "古城区价格较高")
        ]
        
        // 查找匹配的目的地
        for (key, info) in internationalDestinations {
            if dest.contains(key.lowercased()) {
                return info
            }
        }
        
        for (key, info) in domesticDestinations {
            if dest.contains(key.lowercased()) {
                return info
            }
        }
        
        // 默认分析（基于关键词）
        let isInternational = !["中国", "国内"].contains { dest.contains($0) }
        let costLevel = isInternational ? "中高" : "中"
        
        return DestinationInfo(
            costLevel: costLevel,
            isInternational: isInternational,
            currency: isInternational ? "外币" : "人民币",
            exchangeNote: isInternational ? "建议提前兑换外币" : "移动支付普及"
        )
    }
    
    private func calculateBaseAllocation(destination: String, isInternational: Bool, travelType: String, departureCity: String) -> BudgetAllocation {
        // 基础分配比例
        var flightRatio: Double = isInternational ? 0.40 : 0.25
        var hotelRatio: Double = 0.30
        var foodRatio: Double = 0.20
        var transportRatio: Double = 0.08
        var activityRatio: Double = 0.12
        var emergencyRatio: Double = 0.05
        
        // 根据旅行类型调整
        switch travelType {
        case "budget":
            flightRatio *= 0.8
            hotelRatio *= 0.7
            foodRatio *= 0.8
            emergencyRatio = 0.08
        case "luxury":
            flightRatio *= 0.9  // 豪华旅行机票占比相对小
            hotelRatio *= 1.3
            foodRatio *= 1.4
            activityRatio *= 1.5
            emergencyRatio = 0.03
        default: // comfort
            break
        }
        
        // 归一化比例（确保总和为1）
        let total = flightRatio + hotelRatio + foodRatio + transportRatio + activityRatio + emergencyRatio
        
        return BudgetAllocation(
            flight: flightRatio / total,
            hotel: hotelRatio / total,
            food: foodRatio / total,
            transport: transportRatio / total,
            activities: activityRatio / total,
            emergency: emergencyRatio / total
        )
    }
    
    private func calculateDetailedBudget(totalBudget: Double, days: Int, travelers: Int, allocation: BudgetAllocation, destinationInfo: DestinationInfo) -> [String: Any] {
        let flightBudget = totalBudget * allocation.flight
        let hotelBudget = totalBudget * allocation.hotel
        let foodBudget = totalBudget * allocation.food
        let transportBudget = totalBudget * allocation.transport
        let activityBudget = totalBudget * allocation.activities
        let emergencyBudget = totalBudget * allocation.emergency
        
        return [
            "flight": [
                "amount": flightBudget,
                "percentage": Int(allocation.flight * 100),
                "per_person": flightBudget / Double(travelers),
                "tips": generateFlightTips(budget: flightBudget, isInternational: destinationInfo.isInternational)
            ],
            "accommodation": [
                "amount": hotelBudget,
                "percentage": Int(allocation.hotel * 100),
                "per_night": hotelBudget / Double(days),
                "per_person_per_night": hotelBudget / Double(days * travelers),
                "tips": generateHotelTips(budget: hotelBudget / Double(days), travelers: travelers)
            ],
            "food": [
                "amount": foodBudget,
                "percentage": Int(allocation.food * 100),
                "per_day": foodBudget / Double(days),
                "per_person_per_day": foodBudget / Double(days * travelers),
                "meals": [
                    "breakfast": foodBudget * 0.25 / Double(days * travelers),
                    "lunch": foodBudget * 0.35 / Double(days * travelers),
                    "dinner": foodBudget * 0.40 / Double(days * travelers)
                ]
            ],
            "transport": [
                "amount": transportBudget,
                "percentage": Int(allocation.transport * 100),
                "per_day": transportBudget / Double(days),
                "includes": ["市内交通", "景点间交通", "机场往返"]
            ],
            "activities": [
                "amount": activityBudget,
                "percentage": Int(allocation.activities * 100),
                "per_day": activityBudget / Double(days),
                "includes": ["门票", "娱乐项目", "购物", "体验活动"]
            ],
            "emergency": [
                "amount": emergencyBudget,
                "percentage": Int(allocation.emergency * 100),
                "purpose": "应急资金，建议单独存放"
            ]
        ]
    }
    
    private func generateRecommendations(budget: Double, days: Int, destination: String, travelType: String, destinationInfo: DestinationInfo) -> [String] {
        var tips: [String] = []
        
        // 预算水平建议
        let dailyBudget = budget / Double(days)
        if dailyBudget < 200 {
            tips.append("预算偏紧，建议选择青旅、民宿，多吃当地平价美食")
        } else if dailyBudget < 500 {
            tips.append("预算适中，可选择舒适型酒店，体验当地特色餐厅")
        } else {
            tips.append("预算充裕，可选择高端酒店，尽情享受当地美食和活动")
        }
        
        // 国际旅行特殊建议
        if destinationInfo.isInternational {
            tips.append("建议购买旅行保险，预算中应包含保险费用")
            tips.append("关注汇率变动，可考虑分批兑换外币")
            tips.append("预留签证费用（如需要）")
        }
        
        // 旅行类型建议
        switch travelType {
        case "budget":
            tips.append("多使用公共交通，可以更好体验当地文化")
            tips.append("考虑购买城市通票，通常更划算")
        case "luxury":
            tips.append("可考虑包车服务，更加便利舒适")
            tips.append("建议预订知名餐厅，提前了解消费水平")
        default:
            tips.append("平衡体验和成本，选择性价比高的项目")
        }
        
        return tips
    }
    
    private func assessBudgetRisk(totalBudget: Double, days: Int, destination: String, destinationInfo: DestinationInfo) -> [String: Any] {
        let dailyBudget = totalBudget / Double(days)
        var riskLevel = "低"
        var warnings: [String] = []
        
        // 基于目的地和预算评估风险
        let minDailyBudgets: [String: Double] = [
            "日本": 800, "东京": 900,
            "韩国": 600, "首尔": 650,
            "新加坡": 700,
            "美国": 1000,
            "欧洲": 800,
            "泰国": 300, "曼谷": 350,
            "北京": 400, "上海": 450,
            "深圳": 400, "广州": 350,
            "三亚": 500
        ]
        
        for (dest, minBudget) in minDailyBudgets {
            if destination.contains(dest) && dailyBudget < minBudget {
                riskLevel = dailyBudget < minBudget * 0.7 ? "高" : "中"
                warnings.append("日均预算可能不足，建议增加到¥\(Int(minBudget))以上")
                break
            }
        }
        
        // 通用风险评估
        if destinationInfo.isInternational && dailyBudget < 500 {
            riskLevel = "中"
            warnings.append("国际旅行建议日均预算不低于¥500")
        }
        
        if days <= 3 && totalBudget < 2000 {
            warnings.append("短途旅行固定成本占比高，预算可能偏紧")
        }
        
        return [
            "risk_level": riskLevel,
            "warnings": warnings,
            "suggestions": riskLevel == "高" ? ["考虑延长旅行时间以摊薄成本", "选择更经济的住宿方式", "减少购物和娱乐开支"] : ["预算分配合理", "可适当增加体验项目"]
        ]
    }
    
    // MARK: - 辅助方法
    
    private func calculateCashNeeded(_ budgetBreakdown: [String: Any]) -> Double {
        let food = (budgetBreakdown["food"] as? [String: Any])?["amount"] as? Double ?? 0
        let transport = (budgetBreakdown["transport"] as? [String: Any])?["amount"] as? Double ?? 0
        return (food + transport) * 0.6  // 假设60%需要现金
    }
    
    private func generateCostComparison(_ destinationInfo: DestinationInfo, _ totalBudget: Double, _ days: Int) -> [String: Any] {
        let dailyBudget = totalBudget / Double(days)
        let category = dailyBudget < 300 ? "经济" : dailyBudget < 600 ? "舒适" : "奢华"
        
        return [
            "budget_category": category,
            "cost_level": destinationInfo.costLevel,
            "comparison_note": "与同类目的地相比，您的预算属于\(category)水平"
        ]
    }
    
    private func generateFlightTips(budget: Double, isInternational: Bool) -> [String] {
        var tips: [String] = []
        
        if budget < 1000 && isInternational {
            tips.append("建议关注特价机票，提前预订")
            tips.append("考虑中转航班，通常更便宜")
        } else if budget > 3000 {
            tips.append("可考虑商务舱或直飞航班")
        }
        
        tips.append("建议比较不同航空公司价格")
        tips.append("关注行李额度，避免额外费用")
        
        return tips
    }
    
    private func generateHotelTips(budget: Double, travelers: Int) -> [String] {
        let perPersonBudget = budget / Double(travelers)
        
        if perPersonBudget < 200 {
            return ["建议选择青旅或民宿", "考虑多人间以分担成本"]
        } else if perPersonBudget < 500 {
            return ["可选择快捷酒店或中档酒店", "关注位置是否便利"]
        } else {
            return ["可选择高档酒店", "享受更好的服务和设施"]
        }
    }
    
    private func generateMoneySavingTips(_ destination: String, _ travelType: String) -> [String] {
        var tips = [
            "提前规划行程，避免临时高价预订",
            "下载当地优惠App，寻找折扣信息",
            "选择当地人推荐的餐厅，性价比更高",
            "利用城市旅游卡，景点门票更优惠"
        ]
        
        if destination.contains("日本") {
            tips.append("购买JR Pass，交通费用可节省30%以上")
        } else if destination.contains("欧洲") {
            tips.append("考虑欧铁通票，多城市旅行更划算")
        }
        
        return tips
    }
}

// MARK: - 数据结构

struct DestinationInfo {
    let costLevel: String
    let isInternational: Bool
    let currency: String
    let exchangeNote: String
}

struct BudgetAllocation {
    let flight: Double
    let hotel: Double
    let food: Double
    let transport: Double
    let activities: Double
    let emergency: Double
}
