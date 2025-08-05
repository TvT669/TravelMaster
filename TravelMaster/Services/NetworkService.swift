//
//  NetworkService.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation
import Combine

protocol NetworkServiceProtocol {
    func sendChatRequest(_ request: ChatRequest) async throws -> ChatCompletionResponse
}

class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let config: AIConfiguration
    
    init(session: URLSession = .shared, config: AIConfiguration = .shared) {
        self.session = session
        self.config = config
    }
    
    func sendChatRequest(_ request: ChatRequest) async throws -> ChatCompletionResponse {
        // 修复调试输出
           print("🔑 API Key: \(config.apiKey.prefix(20))...")  // 显示更多字符
           print("🌐 Base URL: \(config.baseURL)")
           print("📝 Request URL: \(config.baseURL)/chat/completions")
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw AIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 修复调试输出 - 显示完整的Authorization头（除了敏感部分）
        print("📋 Request Headers:")
        urlRequest.allHTTPHeaderFields?.forEach { key, value in
            if key == "Authorization" {
                // 显示 "Bearer sk-xxxxx...后10位"
                let bearerToken = value
                if bearerToken.count > 20 {
                    let prefix = bearerToken.prefix(15)  // "Bearer sk-xxxxx"
                    let suffix = bearerToken.suffix(10)   // "...后10位"
                    print("  \(key): \(prefix)...\(suffix)")
                } else {
                    print("  \(key): \(value)")
                }
            } else {
                print("  \(key): \(value)")
            }
        }
        
        let requestBody = ChatRequestBody(
            model: config.model,
            messages: request.messages.map{ message in
                APIMessageRequest(
                    role: message.role.rawValue,
                    content: message.content,
                    toolCalls: message.toolCalls,
                    toolCallId: message.toolCallId
                )
            },
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            tools: request.tools,
            toolChoice: request.toolChoice
        )
        
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        
        let(data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw AIError.httpError(httpResponse.statusCode)        }
        
        return try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
    }
}

// 用于 API 请求的工具定义结构体
struct ToolDefinition: Codable {
    let type: String
    let function: FunctionDefinition
    
    struct FunctionDefinition: Codable {
        let name: String
        let description: String
        let parameters: ParameterSchema
    }
    
    struct ParameterSchema: Codable {
        let type: String
        let properties: [String: PropertyDefinition]
        let required: [String]
    }
    
    struct PropertyDefinition: Codable {
        let type: String
        let description: String
    }
    
    // 从 Tool 创建 ToolDefinition 的便利方法
    static func from(tool: Tool) -> ToolDefinition {
        let apiFormat = tool.toAPIFormat()
        let function = apiFormat["function"] as! [String: Any]
        let parameters = function["parameters"] as! [String: Any]
        let properties = parameters["properties"] as! [String: [String: String]]
        let required = parameters["required"] as! [String]
        
        return ToolDefinition(
            type: "function",
            function: FunctionDefinition(
                name: function["name"] as! String,
                description: function["description"] as! String,
                parameters: ParameterSchema(
                    type: "object",
                    properties: properties.mapValues { prop in
                        PropertyDefinition(
                            type: prop["type"]!,
                            description: prop["description"]!
                        )
                    },
                    required: required
                )
            )
        )
    }
}

struct ChatRequest {
    let messages: [ChatMessage]
    let tools: [Tool]?
    let toolChoice: String?
}

struct ChatRequestBody: Codable {
    let model: String
    let messages: [APIMessageRequest]
    let maxTokens: Int
    let temperature: Double
    let tools: [ToolDefinition]?
    let toolChoice: String?
    
    private enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
    }
    
    // 从 ChatRequest 创建的便利初始化方法
    init(model: String, messages: [APIMessageRequest], maxTokens: Int, temperature: Double, tools: [Tool]? = nil, toolChoice: String? = nil) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.tools = tools?.map { ToolDefinition.from(tool: $0) }
        self.toolChoice = toolChoice
    }
}

struct APIMessageRequest: Codable {
    let role: String
    let content: String
    let toolCalls:[ToolCall]?
    let toolCallId: String?
    
    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

enum AIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case decodingError(Error)
    case tokenLimitExceeded
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case.decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .tokenLimitExceeded:
            return "Token limit exceeded"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

