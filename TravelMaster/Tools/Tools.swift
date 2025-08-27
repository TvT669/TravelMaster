//
//  Tools.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/14.
//

import Foundation

enum Tools {
    static func all() -> [Tool] {
        return [
            CalculatorTool(),
            CurrentTimeTool(),
            HotelNearMetroTool(),
            RoutePlannerTool(),
            BudgetAnalyzerTool(),
            FlightSearchTool()
           
            // 在此添加新工具
        ]
    }
    
    static func registerAll(into manager: ToolManager) {
        all().forEach { manager.register(tool: $0) }
    }
}
