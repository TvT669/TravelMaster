//
//  ChatView.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/5.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var agentService = AIAgentService()
    @State private var inputText = ""
    @State private var showingSettings = false
    
    private func filteredMessages() -> [ChatMessage] {
        return agentService.messages.filter { message in
            // 1) 隐藏纯 tool 消息
            if message.role == .tool {
                return false
            }
            
            // 2) 隐藏 assistant 且仅用于触发工具的消息
            if message.role == .assistant {
                let hasToolCalls = message.toolCalls?.isEmpty == false
                let contentIsEmpty = (message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if hasToolCalls && contentIsEmpty {
                    return false
                }
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 对话列表
                ScrollViewReader { proxy in
                                   ScrollView {
                                       LazyVStack(alignment: .leading, spacing: 12) {
                                           // 使用拆分后的方法
                                           ForEach(filteredMessages(), id: \.id) { message in
                                               MessageBubble(message: message)
                                                   .id(message.id)
                                           }
                                           
                                           if agentService.isLoading {
                                               LoadingBubble()
                                           }
                                       }
                                       .padding()
                                       
                                       // 自动滚动到最新消息
                                       .onChange(of: agentService.messages.count) {
                                           withAnimation {
                                               if let lastID = agentService.messages.last?.id {
                                                   proxy.scrollTo(lastID, anchor: .bottom)
                                               }
                                           }
                                       }
                                   }
                               }
                
                // 工作流进度视图 - 仅在有活跃工作流时显示
                if let workflowId = agentService.activeWorkflowId {
                    WorkflowProgressView(workflowId: workflowId, workflowManager: agentService.workflowManager)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: agentService.activeWorkflowId != nil)
                }
                
                // 错误提示
                if let errorMessage = agentService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                // 输入区域
                HStack {
                    TextField("输入旅行需求...", text: $inputText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(agentService.isLoading)
                        .placeholder(when: inputText.isEmpty) {
                            Text("询问行程规划、酒店和机票比价...")
                                .foregroundColor(.gray)
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(inputText.isEmpty || agentService.isLoading ? .gray : .blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentService.isLoading)
                }
                .padding()
            }
            .navigationTitle("旅行助手")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清除") {
                        Task {
                            await agentService.clearConversation()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("设置") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        
        Task {
            await agentService.sendMessage(text)
        }
    }
}

// 消息气泡组件保持不变
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content ?? "")
                    .padding()
                    .background(
                        message.role == .user ? Color.blue : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(
                        message.role == .user ? .white : .primary
                    )
                    .cornerRadius(12)
                // 工具调用显示
                if false, let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    ForEach(toolCalls, id: \.id) { toolCall in
                        Text("调用工具: \(toolCall.function.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if message.role != .user {
                Spacer()
            }
        }
    }
}




// 工作流进度视图
struct WorkflowProgressView: View {
    let workflowId: UUID
    @ObservedObject var workflowManager: WorkflowManager
    
    @State private var progress: Double = 0
    @State private var status: String = "准备中..."
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 6)
            
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onReceive(timer) { _ in
            updateStatus()
        }
    }
    
    private func updateStatus() {
        if let currentStatus = workflowManager.workflowStatus[workflowId] {
            status = currentStatus
            
            // 根据状态更新进度
            if currentStatus.contains("开始分析") {
                progress = 0.1
            } else if currentStatus.contains("分解任务") {
                progress = 0.2
            } else if currentStatus.contains("选择了工具") {
                progress = 0.4
            } else if currentStatus.contains("执行") {
                progress = 0.6
            } else if currentStatus.contains("整合") {
                progress = 0.8
            } else if currentStatus == "完成" {
                progress = 1.0
            }
        }
    }
}

// 加载指示器保持不变
struct LoadingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.async {
                animating = true
            }
            
        }
        .onDisappear {
            animating = false
        }
    }
}

// 设置页面保持不变
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            Form {
                Section("AI配置") {
                    HStack {
                        Text("模型")
                        Spacer()
                        Text(AIConfiguration.shared.model)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("最大Token")
                        Spacer()
                        Text("\(AIConfiguration.shared.maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("温度")
                        Spacer()
                        Text(String(format: "%.1f", AIConfiguration.shared.temperature))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 添加工作流相关设置
                Section("工作流配置") {
                    Toggle("启用复杂工作流", isOn: .constant(true))
                    
                    HStack {
                        Text("默认任务分解方式")
                        Spacer()
                        Text("AI辅助")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("关于") {
                    Text("基于OpenManus架构的iOS智能体")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 为TextField添加placeholder扩展
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ChatView()
}
