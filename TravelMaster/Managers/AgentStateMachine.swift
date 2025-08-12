//
//  AgentStateMachine.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/7.
//

import Foundation

@MainActor
class AgentStateMachine: ObservableObject{
    @Published var currentState: AgentState = .idle
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var currentStep: Int = 0
    private let maxSteps: Int = 10
    
    func canStartNewConversation() -> Bool {
        return currentState == .idle || currentState == .finished || currentState == .error
    }
    
    func startThinking() {
        guard canStartNewConversation() else { return }
        currentState = .thinking
        isLoading = true
        currentStep = 0
        errorMessage = nil
        print("状态变为思考中...")
    }
    
    func startActing() {
        currentState = .acting
        print(" 状态变为行动中...")
    }
    
    func finish() {
        currentState = .finished
        isLoading = false
        print("状态变为完成")
    }
    
    func error(_ message: String){
        currentState = .error
        isLoading = false
        errorMessage = message
        print("状态变为错误: \(message)")
    }
    
    func reset() {
        if currentState == .finished || currentState == .error {
            currentState = .idle
            print("状态已重置为 idle")
        }
    }
    
    func nextStep() {
        currentStep += 1
        print(" Step \(currentStep)/\(maxSteps)")
    }
    
    func shouldContinue() -> Bool {
        return currentStep < maxSteps && currentState != .finished
    }
    
    
}
