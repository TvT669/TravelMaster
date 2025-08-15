//
//  ToolService.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation

// 工具协议和具体实现已移至 /Tools 目录
// 此文件仅保留 ToolManager

class ToolManager {
    private var tools: [String: Tool] = [:]
    
    init() {
        registerDefaultTools()
    }
    
    private func registerDefaultTools() {
        Tools.registerAll(into: self)
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
        return tools.values.map { $0.toAPIFormat() }
    }
    
    func executeTool(name: String, arguments: [String: Any]) async throws -> String {
        guard let tool = tools[name] else {
            throw AIError.configurationError("Tool \(name) not found")
        }
        return try await tool.execute(arguments: arguments)
    }
}
