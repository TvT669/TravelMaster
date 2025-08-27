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
    // 跟踪当前活跃的工作流
    @Published var activeWorkflowId: UUID?
    @Published var workflowProgress: Double = 0
    
    
    private let stateMachine: AgentStateMachine
    private let conversationManager: ConversationManager
    private let executor: AgentExecutor
    // 新增的工作流管理器
    public let workflowManager: WorkflowManager
      
      
    
    init(
        networkService: NetworkServiceProtocol = NetworkService(),
        storageService: StorageServiceProtocol = StorageService(),
        toolManager: ToolManager =  ToolManager()
    ) {
        self.stateMachine = AgentStateMachine()
        self.conversationManager = ConversationManager(storageService: storageService)
        self.executor = AgentExecutor(networkService: networkService, toolManager: toolManager)
        self.workflowManager = WorkflowManager()
            
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
        
        // 新增的工作流绑定
        workflowManager.$progress.assign(to: &$workflowProgress)
    }
    
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        print("发送消息: \(content)")
        print("当前状态: \(currentState)")
        print("当前消息数量: \(messages.count)")
              
        stateMachine.reset()
        conversationManager.addUserMessage(content)
        // 判断是否需要工作流处理
        if needsWorkflow(content) {
            await handleWithWorkflow(content)
        } else {
            await runAgent()
        }
    }

    // 判断消息是否需要工作流处理
    private func needsWorkflow(_ message: String) -> Bool {
        // 分析消息内容，判断是否是复杂任务需要工作流
        // 简单示例：检查是否包含特定关键词和长度
        let keywords = ["旅行", "规划", "行程", "比较", "搜索", "酒店", "机票"]
        let containsKeywords = keywords.contains { message.contains($0) }
        return containsKeywords && message.count > 15
    }
    
    // 检查 handleWithWorkflow 方法
    private func handleWithWorkflow(_ message: String) async {
        // 日志输出用于调试
        print("开始工作流处理: \(message)")
        
        // 先给用户反馈，表明开始处理
        conversationManager.addAssistantMessage("我正在分析您的请求并安排最佳的处理方式...")
        stateMachine.startThinking()
        
        do {
            // 创建上下文
            let context = WorkflowContext(userRequest: message)
            
            // 启动工作流并获取ID
            let id = await workflowManager.executeRequest(message)
            activeWorkflowId = id
            print("工作流已启动，ID: \(id)")
            
            // 等待工作流完成
            for _ in 1...30 { // 最多等待30次
                let status = workflowManager.workflowStatus[id] ?? "处理中..."
                print("工作流状态: \(status)")
                
                if status == "完成" {
                    if let result = workflowManager.getWorkflowResult(id: id) {
                        print("工作流完成，获取到结果")
                        conversationManager.addAssistantMessage(result)
                        stateMachine.finish()
                        activeWorkflowId = nil
                        return
                    }
                }
                
                // 等待一秒
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            // 超时处理
            print("工作流超时")
            conversationManager.addAssistantMessage("处理您的请求花费了太长时间，可能需要进一步交流。")
            stateMachine.finish()
            activeWorkflowId = nil
        } catch {
            print("工作流处理错误: \(error.localizedDescription)")
            conversationManager.addAssistantMessage("处理您的请求时出现了错误：\(error.localizedDescription)")
            stateMachine.finish()
            activeWorkflowId = nil
        }
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
