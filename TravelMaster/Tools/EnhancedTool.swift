//
//  EnhancedTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/27.
//

import Foundation

/// 工具参数定义
struct ToolParameter {
    let name: String
    let description: String
    let required: Bool
}
/// 增强的工具协议，支持上下文
protocol EnhancedTool {
    /// 工具名称
    var name: String { get }
    
    /// 工具描述
    var description: String { get }
    
    /// 工具参数
    var parameters: [ToolParameter] { get }
    
    /// 执行工具，传入上下文并可能修改上下文
    func execute(with context: WorkflowContext) async throws -> String
    
    /// 工具是否可以处理特定类型的请求
    func canHandle(request: String) -> Bool
}

/// 基础工具适配器，将现有Tool适配为EnhancedTool
class ToolAdapter: EnhancedTool {
    private let baseTool: Tool
    
    init(_ tool: Tool) {
        self.baseTool = tool
    }
    
    var name: String {
        return baseTool.name
    }
    
    var description: String {
        return baseTool.description
    }
    
    var parameters:[ToolParameter] {
        // 将 baseTool 的参数字典转换为 ToolParameter 数组
        var result: [ToolParameter] = []
        
        for (paramName, paramInfo) in baseTool.parameters {
            // 从参数信息中提取描述和是否必需
            var description = paramName
            var required = false
            
            // 尝试从参数信息中提取更多细节
            if let paramDict = paramInfo as? [String: Any] {
                if let desc = paramDict["description"] as? String {
                    description = desc
                }
                if let req = paramDict["required"] as? Bool {
                    required = req
                }
            }
            
            // 创建一个 ToolParameter 并添加到结果数组
            let parameter = ToolParameter(
                name: paramName,
                description: description,
                required: required
            )
            result.append(parameter)
        }
        
        return result
    }
    func execute(with context: WorkflowContext) async throws -> String {
        // 从上下文中获取参数
        var params: [String: Any] = [:]
        let request = context.userRequest
        
        // 提取常见参数
        if name == "flight_search" {
            // 提取出发地和目的地
            if request.contains("从") && request.contains("到") {
                if let range = request.range(of: "从([^到]+)到([^的，,。；;]+)", options: .regularExpression) {
                    let matched = String(request[range])
                    let parts = matched.components(separatedBy: "到")
                    if parts.count >= 2 {
                        let origin = parts[0].replacingOccurrences(of: "从", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let destination = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        params["origin"] = origin
                        params["destination"] = destination
                    }
                }
            }
            
            // 添加日期参数
            params["departure_date"] = "2025-09-03" // 默认为下周
        }
        
        else if name == "hotel_near_metro" {
            // 提取城市和地铁站
            if request.contains("到") {
                if let range = request.range(of: "到([^的，,。；;]+)", options: .regularExpression) {
                    let matched = request[range]
                    let city = String(matched.dropFirst()) // 去掉"到"字
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "的.*$", with: "", options: .regularExpression)
                    
                    params["city"] = city
                    params["station"] = "人民广场" // 默认站点
                }
            } else {
                params["city"] = "上海" // 默认城市
                params["station"] = "人民广场" // 默认站点
            }
        }
        
        else if name == "route_planner" {
            // 提取城市
            if request.contains("到") {
                if let range = request.range(of: "到([^的，,。；;]+)", options: .regularExpression) {
                    let matched = request[range]
                    let city = String(matched.dropFirst()) // 去掉"到"字
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "的.*$", with: "", options: .regularExpression)
                    
                    params["city"] = city
                }
            } else {
                params["city"] = "上海" // 默认城市
            }
            
            // 添加默认景点
            params["attractions"] = ["外滩", "南京路", "豫园"]
        }
        
        else if name == "budget_analyzer" {
            // 提取预算金额
            if let range = request.range(of: "预算(\\d+)元", options: .regularExpression) {
                let matched = request[range]
                let budget = matched.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                params["total_budget"] = Double(budget) ?? 3000.0
            } else {
                params["total_budget"] = 3000.0 // 默认预算
            }
            
            // 提取天数
            if let range = request.range(of: "(\\d+)天", options: .regularExpression) {
                let matched = request[range]
                let days = matched.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                params["days"] = Int(days) ?? 3
            } else {
                params["days"] = 3 // 默认天数
            }
            
            // 提取目的地
            if request.contains("到") {
                if let range = request.range(of: "到([^的，,。；;]+)", options: .regularExpression) {
                    let matched = request[range]
                    let city = String(matched.dropFirst()) // 去掉"到"字
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "的.*$", with: "", options: .regularExpression)
                    
                    params["destination"] = city
                }
            } else {
                params["destination"] = "上海" // 默认城市
            }
        }
        
        // 从上下文中获取明确设置的参数，会覆盖上面提取的
        for param in parameters {
             if let value = context.getValue(param.name) as? String {
                params[param.name] = value
            }
        }
        
        // 打印使用的参数
        print("执行工具 \(name) 使用参数: \(params)")
        
        // 执行原始工具
        let result = try await baseTool.execute(arguments: params)
        
        // 将结果存入上下文
        context.set("result_\(name)", value: result)
        
        return result
    }
    
    func canHandle(request: String) -> Bool {
        // 使工具更容易匹配请求
        let lowercasedRequest = request.lowercased()
        
        // 根据工具类型匹配关键词
        if name == "flight_search" || name.contains("flight") {
            return lowercasedRequest.contains("机票") ||
                   lowercasedRequest.contains("航班") ||
                   lowercasedRequest.contains("飞机") ||
                   lowercasedRequest.contains("航空") ||
                   lowercasedRequest.contains("从") && lowercasedRequest.contains("到")
        }
        
        if name == "hotel_near_metro" || name.contains("hotel") {
            return lowercasedRequest.contains("酒店") ||
                   lowercasedRequest.contains("住宿") ||
                   lowercasedRequest.contains("旅馆") ||
                   lowercasedRequest.contains("宾馆")
        }
        
        if name == "route_planner" || name.contains("route") {
            return lowercasedRequest.contains("路线") ||
                   lowercasedRequest.contains("行程") ||
                   lowercasedRequest.contains("规划") ||
                   lowercasedRequest.contains("景点") ||
                   lowercasedRequest.contains("游览")
        }
        
        if name == "budget_analyzer" || name.contains("budget") {
            return lowercasedRequest.contains("预算") ||
                   lowercasedRequest.contains("花费") ||
                   lowercasedRequest.contains("费用") ||
                   lowercasedRequest.contains("元") ||
                   lowercasedRequest.contains("价格")
        }
        
        if name == "calculator" {
            return lowercasedRequest.contains("计算") ||
                   lowercasedRequest.contains("加") ||
                   lowercasedRequest.contains("减") ||
                   lowercasedRequest.contains("乘") ||
                   lowercasedRequest.contains("除")
        }
        
        if name == "current_time" {
            return lowercasedRequest.contains("时间") ||
                   lowercasedRequest.contains("几点")
        }
        
        // 基本匹配：检查请求中是否包含工具名称
        return lowercasedRequest.contains(name.lowercased())
    }
}
