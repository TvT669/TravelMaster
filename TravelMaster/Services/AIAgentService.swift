//
//  AIAgentService.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation
import Combine

@MainActor
class AIAgentService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentState: AgentState = .idle
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let networkService: NetworkServiceProtocol
    private let storageService: StorageServiceProtocol
    private let toolManager: ToolManager
    
    private var currentStep: Int = 0
    private let maxSteps: Int = 10
    
    init(
        networkService: NetworkServiceProtocol = NetworkService(),
        storageService: StorageServiceProtocol = StorageService(),
        toolManager: ToolManager = ToolManager()
    ) {
        self.networkService = networkService
        self.storageService = storageService
        self.toolManager = toolManager
        
        Task {
            await loadConversationHistory()
        }
    }
    
    func sendMessage(_ content: String) async {
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        print("📝 发送消息: \(content)")
           print("🔄 当前状态: \(currentState)")
           print("📊 当前消息数量: \(messages.count)")
        
        if currentState == .finished || currentState == .error {
            currentState = .idle
            print("🔄 状态已重置为 idle")
        }
        let userMessage = ChatMessage(role: .user, content: content)
            messages.append(userMessage)
        await runAgent()
    }
    
    func clearConversation() async {
        messages.removeAll()
        try? await storageService.clearConversations()
        currentState = .idle
        currentStep = 0
        errorMessage = nil
    }
    
    func loadConversationHistory() async {
        do {
            let conversations = try await storageService.loadConversations()
            if let lastConversation = conversations.last {
                messages = lastConversation
            }
        } catch {
            print("Failed to load conversation history: \(error)")
        }
    }
    
    private func runAgent() async {
        
        print("🤖 runAgent 开始，当前状态: \(currentState)")
        guard currentState == .idle else {
            print("Agent is already running")
            return
        }
        
        isLoading = true
        currentState = .thinking
        currentStep = 0
        errorMessage = nil
        
        do {
            while currentStep < maxSteps && currentState != .finished {
                currentStep += 1
                
                let stepResult = await  executeStep()
                print("📊 Step \(currentStep) result: \(stepResult)")
                
                if stepResult {
                    if shouldFinish() {
                        print("🏁 Should finish - 代理决定结束")
                        currentState = .finished
                        break
                    }
                } else {
                    print("❌ Step failed - 步骤失败")
                    break
                }
            }
            try await storageService.saveConversation(messages)
        } catch {
            errorMessage = error.localizedDescription
            currentState = .error
        }
       /* if currentState != .error && currentState != .finished {
            currentState = .idle
        }*/
        isLoading = false
        print("✅ runAgent 完成，最终状态: \(currentState)")    }
    
    private func executeStep() async -> Bool {
        print("🧠 开始思考...")
        let shouldAct = await think()
        print("🤔 思考结果 - 需要行动: \(shouldAct)")
        
        if !shouldAct {
            print("🏁 不需要行动，设置为完成状态")
            currentState = .finished
            return true
        }
        
        print("🎬 开始行动...")
        currentState = .acting
       // return await act()
        let actResult = await act()
          print("🎭 行动结果: \(actResult)")
          return actResult
    }
    
    private func think() async -> Bool {
        do {
            print("💭 构建请求...")
            let request = ChatRequest(
                messages: messages,
                tools: toolManager.getAllTools(),
                toolChoice: "auto")
            
            print("🌐 发送网络请求...")
            let response = try await networkService.sendChatRequest(request)
            
            guard let choice = response.choices.first else {
                print("❌ 没有收到有效响应")
                throw AIError.invalidResponse
            }
            
            let apiMessage = choice.message
            print("📨 收到响应 - 内容长度: \(apiMessage.content?.count ?? 0)")
            print("🔧 工具调用数量: \(apiMessage.toolCalls?.count ?? 0)")
            
            
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: apiMessage.content ?? "",
                toolCalls: apiMessage.toolCalls
            )
            
            messages.append(assistantMessage)
            //return apiMessage.toolCalls != nil && !apiMessage.toolCalls!.isEmpty
            let hasToolCalls = apiMessage.toolCalls != nil && !apiMessage.toolCalls!.isEmpty
            print("🛠️ 是否有工具调用: \(hasToolCalls)")
            return hasToolCalls
            
        } catch {
            print("💥 Think error: \(error)")
            errorMessage = error.localizedDescription
            currentState = .error
            return false
            
        }
    }
    
    private func act() async -> Bool {
        guard let lastMessage = messages.last,
              let toolCalls = lastMessage.toolCalls,
              !toolCalls.isEmpty else {
            print("❌ 没有找到工具调用")
            return false
        }
        
        print("🔧 开始执行 \(toolCalls.count) 个工具调用")
        var allSuccessful = true
        
     //   for toolCall in toolCalls {
        for (index, toolCall) in toolCalls.enumerated() {
               print("🛠️ 执行工具 \(index + 1): \(toolCall.function.name)")
            do {
                let arguments = try parseToolArguments(toolCall.function.arguments)
                print("📝 工具参数: \(arguments)")
                let result = try await toolManager.executeTool(
                    name: toolCall.function.name,
                    arguments: arguments
                )
                print("✅ 工具执行成功: \(result)")
                
                let toolMessage = ChatMessage(
                    role: .tool,
                    content: result,
                    toolCallId: toolCall.id
                )
                messages.append(toolMessage)
                
            } catch {
                print("❌ 工具执行失败: \(error)")
                let errorMessage = "工具执行失败：\(error.localizedDescription)"
                let toolMessage = ChatMessage (
                    role: .tool,
                    content: errorMessage,
                    toolCallId: toolCall.id
                )
                messages.append(toolMessage)
                allSuccessful = false
            }
        }
        if allSuccessful {
            print("🎯 所有工具执行成功，获取最终响应...")
            await getFinalResponse()
        }
        print("🎭 Act 完成，成功: \(allSuccessful)")
        return allSuccessful
    }
    
    private func getFinalResponse() async {
        do {
            let request = ChatRequest (
                messages: messages,
                tools: nil,
                toolChoice: nil
            )
            
            let response = try await networkService.sendChatRequest(request)
            
            if let choice = response.choices.first,
               let content = choice.message.content {
                print("📝 收到最终响应: \(content)")
                let finalMessage = ChatMessage(role: .assistant, content: content)
                messages.append(finalMessage)
            }
        } catch {
            print("💥 获取最终响应失败: \(error)")
            let errorMessage = ChatMessage(
                role: .assistant,
                content:"抱歉，我在处理您的请求时遇到了问题：\(error.localizedDescription)"
            )
            messages.append(errorMessage)
        }
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
    
    private func shouldFinish() -> Bool {
        guard let lastMessage = messages.last else {return true}
        
        return lastMessage.role == .assistant && (lastMessage.toolCalls == nil || lastMessage.toolCalls!.isEmpty)
    }

}
