//
//  CalculatorTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/14.
//

import Foundation

final class CalculatorTool: BaseTool {
    init() {
        super.init(
            name: "calculator",
            description: "执行数学计算",
            parameters: [
                "expression": [
                    "type": "string",
                    "description": "要计算的数学表达式"
                ]
            ]
        )
    }
    
    override func toAPIFormat() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": parameters,
                    "required": ["expression"]
                ]
            ]
        ]
    }
    
    override func execute(arguments: [String : Any]) async throws -> String {
        guard let expression = arguments["expression"] as? String else {
            throw AIError.configurationError("Missing expression parameter")
        }
        
        let mathExpression = NSExpression(format: expression)
        guard let result = mathExpression.expressionValue(with: nil, context: nil) else {
            throw AIError.configurationError("Invalid math expression")
        }
        
        // 返回结构化 JSON 避免模型复述
        let payload: [String: Any] = [
            "ok": true,
            "tool": name,
            "expression": expression,
            "value": result
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
