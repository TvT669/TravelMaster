//
//  ConversationManager.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/7.
//

import Foundation

@MainActor
class ConversationManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    
    private let storageService: StorageServiceProtocol
    
    init(storageService: StorageServiceProtocol = StorageService()) {
        self.storageService = storageService
    }
    
    func addUserMessage(_ content: String) {
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        print("添加用户消息: \(content)")
    }
    
    func addAssistantMessage(_ content: String, toolCalls: [ToolCall]? = nil) {
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: content,
            toolCalls: toolCalls
        )
        messages.append(assistantMessage)
        print("添加助手消息: \(content)")
    }
    
    func addToolMessage(_ content: String, toolCallId: String) {
        let toolMessage = ChatMessage(
            role: .tool ,
            content: content,
            toolCallId: toolCallId
        )
        messages.append(toolMessage)
        print("添加工具消息: \(content)")
    }
    
    func clearMessages() {
        messages.removeAll()
        print("清除所有消息")
    }
    
    func loadHistory() async {
        do {
            let conversations = try await storageService.loadConversations()
            if let lastConversation = conversations.last {
                messages = lastConversation
                print("加载历史对话: \(messages.count) 条消息")
            }
        } catch {
            print("加载历史对话失败: \(error)")
        }
    }
    
    func saveHistory() async throws {
        try await storageService.saveConversation(messages)
        print("保存历史对话")
    }
    
    func clearHistory() async {
        clearMessages()
        do {
            try await storageService.clearConversations()
            print("清除历史记录")
        } catch {
            print("清除历史记录失败：\(error)")
        }
    }
    
    var lastMessage: ChatMessage? {
        return messages.last
    }

}
