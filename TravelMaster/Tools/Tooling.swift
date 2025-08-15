//
//  Tooling.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/14.
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
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": parameters
                ]
            ]
        ]
    }
}
