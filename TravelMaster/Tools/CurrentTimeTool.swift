//
//  CurrentTimeTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/14.
//

import Foundation

final class CurrentTimeTool: BaseTool {
    init() {
        super.init(
            name: "get_current_time",
            description: "获取当前时间",
            parameters: [:]
        )
    }
    
    override func execute(arguments: [String : Any]) async throws -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.locale = Locale(identifier: "zh_CN")
        
        let payload: [String: Any] = [
            "ok": true,
            "tool": name,
            "display": formatter.string(from: Date()),
            "iso8601": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
