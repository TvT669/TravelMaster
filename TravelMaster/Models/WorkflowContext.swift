//
//  WorkflowContext.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/27.
//

import Foundation

/// 工作流上下文，用于在工具链中传递数据
class WorkflowContext {
    /// 存储任意类型的数据
    private var storage: [String: Any] = [:]
    
    /// 任务ID
    let taskId: UUID
    
    /// 用户原始请求
    let userRequest: String
    
    /// 任务状态
    enum TaskState {
        case pending, inProgress, completed, failed
    }
    
    /// 当前状态
    var state: TaskState = .pending
    
    /// 错误信息
    var error: Error?
    
    init(userRequest: String) {
        self.taskId = UUID()
        self.userRequest = userRequest
    }
    
    /// 存储数据
    func set<T>(_ key: String, value: T) {
        storage[key] = value
    }
    
    /// 获取数据
    func get<T>(_ key: String) -> T? {
        return storage[key] as? T
    }
    
    /// 合并另一个上下文的数据
    func merge(with context: WorkflowContext) {
        for (key, value) in context.storage {
            storage[key] = value
        }
    }
    
    /// 获取所有存储的内容
    func getAllStorage() -> [String: Any]? {
        return storage
    }
    
    /// 获取任意类型的数据
    func getValue(_ key: String) -> Any? {
        return storage[key]
    }
    
    /// 获取所有数据的描述
    var description: String {
        var result = "任务ID: \(taskId)\n"
        result += "用户请求: \(userRequest)\n"
        result += "状态: \(state)\n"
        result += "数据:\n"
        
        for (key, value) in storage {
            result += "- \(key): \(value)\n"
        }
        
        return result
    }
}
