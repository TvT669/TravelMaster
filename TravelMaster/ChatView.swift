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
    
    var body: some View {
        NavigationView {
            VStack {
                //对话列表
                ScrollViewReader { proxy in
                    ScrollView{
                        LazyVStack(alignment: .leading,spacing: 12){
                            ForEach(agentService.messages){ message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if agentService.isLoading {
                                LoadingBubble()
                            }
                        }
                        .padding()
                    }
                   
                }
                //错误提示
                if let errorMessage = agentService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                }
                
                //输入区域
                HStack {
                    TextField("输入消息...",text:  $inputText,axis:.vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(agentService.isLoading)
                    Button("发送"){
                        Task {
                            await agentService.sendMessage(inputText)
                            inputText = ""
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentService.isLoading)
                }
                .padding()
            }
            .navigationTitle("AI智能体")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing){
                    Button("清除") {
                        Task{
                            await agentService.clearConversation()
                        }
                    }
                }
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button("设置") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings){
                SettingsView()
            }
          
        }
        
    }
}

//消息气泡组件
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack{
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4){
                Text(message.content.isEmpty ? "" : message.content)
                    .padding()
                    .background(
                        message.role == .user ? Color.blue : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(
                        message.role == .user ? .white : .primary
                    )
                    .cornerRadius(12)
                //工具调用显示
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty{
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

//加载指示器
struct LoadingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3){ index in
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
        .onAppear{
            DispatchQueue.main.async {
                animating = true
            }
            
        }
        .onDisappear(){
            animating = false
        }
    }
}

//设置页面
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView{
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

#Preview {
    ChatView()
}
