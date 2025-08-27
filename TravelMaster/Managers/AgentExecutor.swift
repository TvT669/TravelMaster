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
    
    func run(messages: [ChatMessage], tools: [[String: Any]]?) async throws -> String {
        // 1. 思考步骤 - 获取AI初步回复和工具调用
        let (initialResponse, toolCalls) = try await think(with: messages)
        
        // 如果没有工具调用，直接返回初始响应
        if toolCalls == nil || toolCalls!.isEmpty {
            return initialResponse
        }
        
        // 2. 执行工具调用
        let toolResults = await executeTools(toolCalls!)
        
        // 3. 将工具结果转换为消息
        var updatedMessages = messages
        
        // 3.1 添加AI的工具调用消息(不包含初始文本，避免重复)
        updatedMessages.append(ChatMessage(
            role: .assistant,
            content: nil,
            toolCalls: toolCalls
        ))
        
        // 3.2 添加工具响应消息
        for (callId, result) in toolResults {
            updatedMessages.append(ChatMessage(
                role: .tool,
                content: result,
                toolCallId: callId
            ))
        }
        
        // 4. 获取最终响应
        if let finalResponse = try await getFinalResponse(with: updatedMessages) {
            return finalResponse
        }
        
        // 如果无法获取最终响应，返回一个合理的默认回复
        return "我已找到相关信息，但在组织回复时遇到了问题。请问您需要了解哪方面的详细信息？"
    }

    // 修改 execute 方法解决所有问题
    func execute(_ userMessage: String) async throws -> String {
        // 1. 更新对话状态 - 使用正确的方法
        var state = await conversationManager.state  // 修改 getState() 为 state 属性
        let userInput = ChatMessage(role: .user, content: userMessage)
        state.userMessages.append(userInput)
        await conversationManager.update(state: state)  // 修改 updateState 为 update(state:)
        
        // 2. 获取完整的消息历史
        let messages = state.allMessages
        
        // 3. 获取工具配置 - 修复类型不匹配
        let toolsConfig = toolManager.getToolsConfig()  // 获取正确格式的工具配置
        
        // 4. 执行完整流程
        let response = try await run(messages: messages, tools: toolsConfig)
        
        // 5. 更新对话状态 - 使用正确的方法
        state = await conversationManager.state  // 修改 getState() 为 state 属性
        state.assistantMessages.append(ChatMessage(role: .assistant, content: response))
        await conversationManager.update(state: state)  // 修改 updateState 为 update(state:)
        
        return response
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
    
    // 修改 getFinalResponse 方法
    func getFinalResponse(with messages: [ChatMessage]) async throws -> String? {
        print("获取最终响应...")
        
        // 更强的系统指令
        let enhancedSystemPrompt = ChatMessage(
            role: .system,
            content: """
    你将看到若干 role=tool 的JSON结果。请：
    - 使用这些结构化数据进行推理与表述；
    - 禁止直接粘贴JSON或逐字复述工具返回文本；
    - 不要重复你在本轮思考阶段已生成的任何句子；
    - 严禁返回<|tool_calls_begin|>等工具调用格式标记；
    - 只需要生成自然语言回复，不要再调用任何工具；
    - 以自然、简洁的中文给出结论，必要时列要点，并给出清晰的下一步建议。
    """
        )
        
        // 仅保留本轮相关消息
        var finalMessages = buildFinalMessageForSyntheis(messages)
        
        // 将强化系统消息置顶
        finalMessages.insert(enhancedSystemPrompt, at: 0)
        
        // 添加明确的用户指令作为最后一条消息
        finalMessages.append(ChatMessage(
            role: .user,
            content: "请根据以上工具返回的结果，生成一个简洁清晰的回复。不要返回工具调用语法，直接用自然语言总结信息。"
        ))
        
        // 发起最终回复请求
        let request = ChatRequest(
            messages: finalMessages,
            tools: nil,
            toolChoice: nil
        )
        
        let response = try await networkService.sendChatRequest(request)
        if let choices = response.choices.first,
           let content = choices.message.content {
            // 清理可能的工具调用标记
            let cleanedContent = cleanToolCallMarkers(content)
            print("收到的最终响应：\(cleanedContent)")
            return cleanedContent
        }
        return nil
    }

    // 添加清理工具调用标记的函数
    private func cleanToolCallMarkers(_ response: String) -> String {
        // 检测并清理工具调用标记
        let patterns = [
            "<\\|tool_calls_begin\\|>.*?<\\|tool_calls_end\\|>",
            "<\\|tool▁calls▁begin\\|>.*?<\\|tool▁calls▁end\\|>"
        ]
        
        var cleaned = response
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: "我已收到以下信息："
                )
            }
        }
        return cleaned
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
