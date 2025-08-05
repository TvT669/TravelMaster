//
//  ToolService.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation

protocol Tool {
    var name: String { get }
    var description: String { get }
    var parameters: [String: Any] { get }
    
    func execute(arguments: [String: Any]) async throws -> String
    func toAPIFormat() -> [String: Any]
}

class BaseTool: Tool {
    let name: String
    let description: String
    let parameters: [String : Any]
    
    init(name: String, description: String, parameters: [String : Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
    
    func execute(arguments: [String : Any]) async throws -> String {
        fatalError("Subclasses must implement execute method")
    }
    
    func toAPIFormat() -> [String : Any] {
        return[
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "Object",
                    "properties": parameters,
                    "required": Array(parameters.keys)
                ]
            ]
        ]
    }
}

class CalculatorTool: BaseTool {
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
    
    override func execute(arguments: [String : Any]) async throws -> String {
        guard let expression = arguments["expression"] as? String else {
            throw AIError.configurationError("Missing expression parameter")
        }
        
        let mathExpression = NSExpression(format: expression)
        if let result = mathExpression.expressionValue(with: nil, context: nil) as? NSNumber {
            return "计算结果：\(result)"
        } else {
            throw AIError.configurationError("Invalid math expression")
        }
    }
}

class CurrentTimeTool: BaseTool {
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
        return "当前时间：\(formatter.string(from: Date()))"
    }
}

class ToolManager {
    private var tools: [String: Tool] = [:]
    
    init() {
        registerDefaultTools()
    }
    
    private func registerDefaultTools() {
        register(tool: CalculatorTool())
        register(tool: CurrentTimeTool())
    }
    
    func register(tool: Tool) {
        tools[tool.name] = tool
    }
    
    func getTool(named name: String) -> Tool? {
        return tools[name]
    }
    
    func getAllTools() -> [Tool] {
        return Array(tools.values)
    }
    
    func getToolsForAPI() -> [[String: Any]] {
        return tools.values.map { $0.toAPIFormat()}
    }
    
    func executeTool(name: String, arguments: [String: Any]) async throws -> String {
        guard let tool = tools[name] else {
            throw AIError.configurationError("Tool \(name) not found")
        }
        
        return try await tool.execute(arguments: arguments)
    }
    
    
}
