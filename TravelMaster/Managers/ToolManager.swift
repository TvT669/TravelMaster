//
//  ToolManager.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/26.
//

import Foundation

class ToolManager {
    private var tools: [String: Tool] = [:]
    
    func register(tool: Tool) {
        tools[tool.name] = tool
    }
    
    func executeTool(name: String, arguments: [String: Any]) async throws -> String {
        guard let tool = tools[name] else {
            throw ToolError.notFound(name: name)
        }
        
        return try await tool.execute(arguments: arguments)
    }
    
    func getAllTools() -> [[String: Any]] {
        return tools.values.map { $0.toAPIFormat() }
    }
    
    func getTool(byName name: String) -> Tool? {
        return tools[name]
    }
}

