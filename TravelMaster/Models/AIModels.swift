//
//  AIModels.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation

enum MessageRole: String, CaseIterable, Codable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
}

struct ChatMessage: Codable, Identifiable {
    var id = UUID()
    let role: MessageRole
    let content: String?
    let timestamp: Date
    let toolCalls: [ToolCall]?
    let toolCallId: String?
    
    init(role: MessageRole, content: String? = nil, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

struct ToolCall: Codable, Identifiable {
    let id: String
    let type: String
    let function: ToolFunction
}

struct ToolFunction: Codable {
    let name: String
    let arguments: String
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let message: APIMessage
        let finishReason: String?
        
        private enum CodingKeys: String, CodingKey{
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct APIMessage: Codable {
        let role: String
        let content: String?
        let toolCalls: [ToolCall]?
        
        private enum CodingKeys: String, CodingKey{
            case role,content
            case toolCalls = "tool_calls"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

enum AgentState: String, CaseIterable {
    case idle = "idle"
    case thinking = "thinking"
    case acting = "acting"
    case finished = "finished"
    case error = "error"
}
