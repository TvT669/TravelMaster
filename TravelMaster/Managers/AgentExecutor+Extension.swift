//
//  AgentExecutor+Extension.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/15.
//

import Foundation

// 扩展 AgentExecutor 以增加发送聊天请求的便捷方法
extension AgentExecutor {
    // 发送聊天请求并返回响应
    func sendChatRequest(_ messages: [ChatMessage]) async throws -> String {
        let request = ChatRequest(
            messages: messages,
            tools: nil,
            toolChoice: nil
        )
        
        let response = try await networkService.sendChatRequest(request)
        if let choice = response.choices.first, let content = choice.message.content {
            return content
        }
        
        throw AIError.invalidResponse
    }
    
    // 发送工具调用类型的请求
    func sendToolRequest(_ messages: [ChatMessage], tools: [[String: Any]]) async throws -> (String?, [ToolCall]?) {
        let request = ChatRequest(
            messages: messages,
            tools: tools,
            toolChoice: "auto"
        )
        
        let response = try await networkService.sendChatRequest(request)
        if let choice = response.choices.first {
            return (choice.message.content, choice.message.toolCalls)
        }
        
        throw AIError.invalidResponse
    }
    
    // 运行一轮完整的对话（包括思考、工具调用和最终响应）
    func run(messages: [ChatMessage], tools: [[String: Any]]) async throws -> String {
        // 1. 思考阶段
        let (thinking, toolCalls) = try await sendToolRequest(messages, tools: tools)
        
        // 2. 如果没有工具调用，直接返回思考结果
        guard let toolCalls = toolCalls, !toolCalls.isEmpty else {
            return thinking ?? "抱歉，我无法处理这个请求。"
        }
        
        // 3. 执行工具调用
        var updatedMessages = messages
        
        // 添加助理思考消息（包含工具调用）
        updatedMessages.append(ChatMessage(
            role: .assistant,
            content: thinking,
            toolCalls: toolCalls
        ))
        
        // 执行工具并添加结果
        let results = await executeTools(toolCalls)
        for (id, result) in results {
            updatedMessages.append(ChatMessage(
                role: .tool,
                content: result,
                toolCallId: id
            ))
        }
        
        // 4. 获取最终响应
        if let finalResponse = try await getFinalResponse(with: updatedMessages) {
            return finalResponse
        }
        
        return "抱歉，处理您的请求时遇到了问题。"
    }
}
