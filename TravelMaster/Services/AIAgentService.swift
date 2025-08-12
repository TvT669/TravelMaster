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
    // 发布的属性通过子组件暴露
    @Published var messages: [ChatMessage] = []
    @Published var currentState: AgentState = .idle
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let stateMachine: AgentStateMachine
    private let conversationManager: ConversationManager
    private let executor: AgentExecutor
    
    init(
        networkService: NetworkServiceProtocol = NetworkService(),
        storageService: StorageServiceProtocol = StorageService(),
        toolManager: ToolManager =  ToolManager()
    ) {
        self.stateMachine = AgentStateMachine()
        self.conversationManager = ConversationManager(storageService: storageService)
        self.executor = AgentExecutor(networkService: networkService, toolManager: toolManager)
        
        // 绑定子组件的状态到主组件
        setupBindings()
        
        Task {
            await conversationManager.loadHistory()
        }
    }
    
    private func setupBindings() {
        // 绑定状态
        stateMachine.$currentState.assign(to: &$currentState)
        stateMachine.$isLoading.assign(to: &$isLoading)
        stateMachine.$errorMessage.assign(to: &$errorMessage)
        
        //绑定消息
        conversationManager.$messages.assign(to: &$messages)
    }
    
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        print("发送消息: \(content)")
        print("当前状态: \(currentState)")
        print("当前消息数量: \(messages.count)")
              
        stateMachine.reset()
        conversationManager.addUserMessage(content)
        await runAgent()
    }
    
    func clearConversation() async {
        await conversationManager.clearHistory()
        stateMachine.reset()
    }
    
    private func runAgent() async {
        guard stateMachine.canStartNewConversation() else {
            print("智能体正在运行")
            return
        }
        stateMachine.startThinking()
        do{
            while stateMachine.shouldContinue(){
                stateMachine.nextStep()
                
                let stepResult = await executeStep()
                print("步骤结果：\(stepResult)")
                
                if stepResult {
                    if shouldFinish(){
                        stateMachine.finish()
                        break
                    }
                } else {
                    print("❌ Step failed")
                    break
                }
            }
            try await conversationManager.saveHistory()
        } catch {
            stateMachine.error(error.localizedDescription)
            
        }
        print("runAgent 完成，最终状态: \(currentState)")
    }
    
    private func executeStep() async -> Bool {
        do {
            //思考阶段
            let (content, toolCalls) = try await executor.think(with: messages)
            conversationManager.addAssistantMessage(content, toolCalls: toolCalls)
            
            //检查工具是否需要执行
            guard let toolCalls = toolCalls, !toolCalls.isEmpty else {
                print("不需要行动，设置为完成状态")
                return true
            }
            
            //执行工具
            stateMachine.startActing()
            let toolResults = await executor.executeTools(toolCalls)
            
            //添加工具结果消息
            for(toolCallId, result) in toolResults {
                conversationManager.addToolMessage(result, toolCallId: toolCallId)
            }
            
            //获取最终响应
            if let finalResponse = try await executor.getFinalResponse(with: messages) {
                conversationManager.addAssistantMessage(finalResponse)
            }
            
            return true
            
        } catch {
            stateMachine.error(error.localizedDescription)
            return false
        }
    }
    
    private func shouldFinish() -> Bool {
        guard let lastMessage = conversationManager.lastMessage else { return true}
        return lastMessage.role == .assistant && (lastMessage.toolCalls  == nil || lastMessage.toolCalls!.isEmpty)
    }
}
