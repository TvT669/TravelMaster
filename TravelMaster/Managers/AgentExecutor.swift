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
                
                let raw = try await toolManager.executeTool(
                    name: toolCall.function.name,
                    arguments: arguments
                )
                let normalized = normalizeToolResult(raw, toolName: toolCall.function.name) // 使用包装
                print("工具执行成功: \(normalized)")
                results.append((toolCall.id, normalized))
            } catch {
                print("工具执行失败: \(error)")
                let errorMessage = "工具执行失败: \(error.localizedDescription)"
                results.append((toolCall.id, errorMessage))
            }
        }
        return results
    }
    
    // 将非JSON结果包装为JSON，减少直接复述。
    // 形如：{"ok":true,"tool":"calculator","data":{"text":"计算结果：24"}}
    private func normalizeToolResult(_ raw: String, toolName: String) -> String {
        if let data = raw.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return raw // 已是JSON，直接返回
        }
        let wrapper: [String: Any] = [
            "ok": true,
            "tool": toolName,
            "data": ["text": raw]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: wrapper, options: []) {
            return String(data: data, encoding: .utf8) ?? raw
        }
        return raw
    }
    
    func getFinalResponse(with messages: [ ChatMessage]) async throws -> String? {
        print("获取最终响应...")
        
        // 去除重复的系统指令
        let dedupSystem = ChatMessage(
            role: .system,
            content: """
你将看到若干 role=tool 的JSON结果。请：
- 使用这些结构化数据进行推理与表述；
- 禁止直接粘贴JSON或逐字复述工具返回文本；
- 不要重复你在本轮思考阶段已生成的任何句子；
- 以自然、简洁的中文给出结论，必要时列要点，并给出清晰的下一步建议。
"""
        )
        
        //仅保留本轮相关消息：最后一条用户消息 + 随后的assistant(toolCalls) + 相应tool消息
        var finalMessages = buildFinalMessageForSyntheis(messages)
        
        // 将去重复系统消息置顶
        finalMessages.insert(dedupSystem, at:0)
        
        //  用裁剪后的 finalMessages 发起最终回复请求
        let request = ChatRequest (
            messages: finalMessages,
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
    
    // 仅保留“最后一条 user + 紧随其后的 assistant(含toolCalls) + tool 消息”；
    // 对包含toolCalls的assistant消息，清空其content，避免助手草稿被再次复述。
    private func buildFinalMessageForSyntheis(_ all: [ChatMessage]) -> [ChatMessage] {
        guard let lastUserIdx = all.lastIndex(where: { $0.role == .user}) else {return all}
        var slice = Array(all[lastUserIdx...])
        slice = slice.map { msg in
            if msg.role == .assistant, msg.toolCalls != nil {
                return ChatMessage(role: .assistant, content: nil, toolCalls: msg.toolCalls, toolCallId: msg.toolCallId)
            }
            return msg
        }
        return slice
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
