//
//  AgentExecutor.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/7.
//

import Foundation

@MainActor
class AgentExecutor {
    private let networkService: NetworkServiceProtocol
    private let toolManager: ToolManager
    
    init(
        networkService: NetworkServiceProtocol = NetworkService(),
         toolManager: ToolManager
    ) {
        self.networkService = networkService
        self.toolManager = toolManager
    }
    
    func think(with messages: [ChatMessage]) async throws -> (String, [ToolCall]?) {
        print("开始思考...")
        
        let request = ChatRequest(
            messages: messages,
            tools: toolManager.getAllTools(),
            toolChoice: "auto"
        )
        print("发送网络请求...")
        let response = try await networkService.sendChatRequest(request)
        
        guard let choice = response.choices.first else {
            print("没有收到有效响应")
            throw AIError.invalidResponse
        }
        
        let apiMessage = choice.message
        print("收到响应 - 内容长度: \(apiMessage.content?.count ?? 0)")
        print("工具调用数量: \(apiMessage.toolCalls?.count ?? 0)")
        return (apiMessage.content ?? "", apiMessage.toolCalls)
        }
    
    func executeTools(_ toolCalls: [ToolCall]) async -> [(String, String)] {
        print("开始执行\(toolCalls.count) 个工具调用")
        var results: [(String, String)] = []
        
        for(index, toolCall) in toolCalls.enumerated() {
            print(" 执行工具 \(index + 1): \(toolCall.function.name)")
            
            do{
                let arguments = try parseToolArguments(toolCall.function.arguments)
                print("工具参数: \(arguments)")
                
                let result = try await toolManager.executeTool(
                    name: toolCall.function.name,
                    arguments: arguments
                )
                print("工具执行成功: \(result)")
                results.append((toolCall.id, result))
            } catch {
                print("工具执行失败: \(error)")
                let errorMessage = "工具执行失败: \(error.localizedDescription)"
                results.append((toolCall.id, errorMessage))
            }
        }
        return results
    }
    
    func getFinalResponse(with messages: [ ChatMessage]) async throws -> String? {
        print("获取最终响应...")
        
        let request = ChatRequest (
            messages: messages,
            tools: nil ,
            toolChoice: nil
        )
        let response = try await networkService.sendChatRequest(request)
        if let  choices = response.choices.first,
           let content = choices.message.content{
            print("收到的最终响应：\(content)")
            return content
        }
        return nil
    }
    
    private func parseToolArguments(_ argumentsString: String) throws -> [String: Any] {
        guard let data = argumentsString.data(using: .utf8) else {
            throw AIError.decodingError(NSError(domain: "Invalid UTF-8", code: 0))
        }
        let json = try JSONSerialization.jsonObject(with: data)
        guard let arguments = json as? [String: Any] else {
            throw AIError.decodingError(NSError(domain: "Invalid JSON format", code: 0))
        }
        return arguments
    }
}
