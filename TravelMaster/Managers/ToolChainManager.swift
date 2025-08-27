//
//  ToolChainManager.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/26.
//

import Foundation

/// 运行时工具调用结果封装
struct ToolExecutionResult {
    let name: String
    let ok: Bool
    let raw: String
    let data: [String: Any]
    let error: String?
}

/// 工作流管理器：处理工具链执行、上下文传递与并发控制
class ToolChainManager {
    private let toolManager: ToolManager
    
    init(toolManager: ToolManager) {
        self.toolManager = toolManager
    }
    
    // MARK: - 旅行规划工作流
    
    /// 执行旅行规划工作流
    /// - Parameter initialArgs: 初始参数
    /// - Returns: 汇总结果
    func executeTravelPlan(initialArgs: [String: Any]) async -> [String: Any] {
        print("开始执行旅行规划工作流，初始参数：\(initialArgs)")
        
        var context: [String: Any] = ["user_query": initialArgs]
        var results: [String: ToolExecutionResult] = [:]
        
        // 1) 并发执行航班搜索和预算分析（互不依赖的任务）
        await withTaskGroup(of: (String, ToolExecutionResult?).self) { group in
            // 航班搜索
            group.addTask {
                let flightArgs: [String: Any] = [
                    "origin": initialArgs["origin"] ?? initialArgs["departure_city"] ?? "北京",
                    "destination": initialArgs["destination"] ?? initialArgs["destination_city"] ?? "上海",
                    "departure_date": initialArgs["departure_date"] ?? "",
                    "return_date": initialArgs["return_date"] ?? "",
                    "adults": initialArgs["adults"] ?? 1,
                    "travel_class": initialArgs["travel_class"] ?? "ECONOMY"
                ]
                
                print("执行航班搜索：\(flightArgs)")
                let res = await self.runTool(name: "flight_search", arguments: flightArgs)
                return ("flight_search", res)
            }
            
            // 预算分析
            group.addTask {
                let budgetArgs: [String: Any] = [
                    "destination": initialArgs["destination"] ?? initialArgs["destination_city"] ?? "上海",
                    "days": initialArgs["days"] ?? 3,
                    "total_budget": initialArgs["budget"] ?? 5000
                ]
                
                print("执行预算分析：\(budgetArgs)")
                let res = await self.runTool(name: "budget_analyzer", arguments: budgetArgs)
                return ("budget_analyzer", res)
            }
            
            for await (name, res) in group {
                if let r = res {
                    results[name] = r
                    // 将成功工具的数据放入上下文供后继工具使用
                    if r.ok {
                        context[name] = r.data
                        print("工具 \(name) 执行成功，结果已加入上下文")
                    } else {
                        context[name] = ["error": r.error ?? "unknown"]
                        print("工具 \(name) 执行失败: \(r.error ?? "未知错误")")
                    }
                }
            }
        }
        
        // 2) 从航班结果提取城市和日期，为酒店搜索准备参数
        var hotelArgs: [String: Any] = [:]
        let destination = initialArgs["destination"] as? String ?? initialArgs["destination_city"] as? String ?? "上海"
        
        if let flightRes = results["flight_search"], flightRes.ok {
            // 从航班查询提取入住日期
            if let query = flightRes.data["query"] as? [String: Any],
               let departureDate = query["departure_date"] as? String {
                hotelArgs["check_in"] = departureDate
                
                // 计算退房日期（入住日期+停留天数）
                let days = initialArgs["days"] as? Int ?? 3
                if let date = parseDate(departureDate) {
                    let checkOutDate = Calendar.current.date(byAdding: .day, value: days, to: date)
                    hotelArgs["check_out"] = formatDate(checkOutDate ?? Date())
                }
            }
        } else {
            // 如果航班搜索失败，使用原始参数
            hotelArgs["check_in"] = initialArgs["departure_date"] ?? ""
            
            // 尝试计算退房日期
            if let departureDate = initialArgs["departure_date"] as? String,
               let days = initialArgs["days"] as? Int,
               let date = parseDate(departureDate) {
                let checkOutDate = Calendar.current.date(byAdding: .day, value: days, to: date)
                hotelArgs["check_out"] = formatDate(checkOutDate ?? Date())
            }
        }
        
        // 添加目的地和其他参数
        hotelArgs["city"] = destination
        hotelArgs["location"] = initialArgs["location"] // 可选的位置要求
        hotelArgs["max_results"] = 5
        
        // 3) 执行酒店搜索
        print("执行酒店搜索：\(hotelArgs)")
        let hotelRes = await runTool(name: "hotel_near_metro", arguments: hotelArgs)
        if let r = hotelRes {
            results["hotel_search"] = r
            if r.ok {
                context["hotel_search"] = r.data
                print("酒店搜索完成，结果已加入上下文")
            } else {
                context["hotel_search"] = ["error": r.error ?? "unknown"]
                print("酒店搜索失败: \(r.error ?? "未知错误")")
            }
        }
        
        // 4) 基于酒店位置准备路线规划参数
        var routeArgs: [String: Any] = [
            "city": destination,
            "days": initialArgs["days"] ?? 3
        ]
        
        // 尝试从酒店结果中提取位置作为起始点
        if let hotelResult = results["hotel_search"],
           hotelResult.ok,
           let hotels = hotelResult.data["pois"] as? [[String: Any]],
           let firstHotel = hotels.first {
            
            // 使用第一个酒店的名称或地址作为起点
            if let hotelName = firstHotel["name"] as? String {
                routeArgs["start_location"] = hotelName
            } else if let hotelAddress = firstHotel["address"] as? String {
                routeArgs["start_location"] = hotelAddress
            }
        }
        
        // 5) 执行路线规划
        print("执行路线规划：\(routeArgs)")
        let routeRes = await runTool(name: "route_planner", arguments: routeArgs)
        if let r = routeRes {
            results["route_planner"] = r
            if r.ok {
                context["route_planner"] = r.data
                print("路线规划完成，结果已加入上下文")
            } else {
                context["route_planner"] = ["error": r.error ?? "unknown"]
                print("路线规划失败: \(r.error ?? "未知错误")")
            }
        }
        
        // 6) 汇总所有工具执行结果，创建最终旅行计划
        var finalPlan: [String: Any] = [
            "ok": true,
            "workflow": "travel_plan",
            "query": initialArgs
        ]
        
        // 提取各工具的核心结果
        if let flightResult = results["flight_search"], flightResult.ok {
            finalPlan["flight"] = flightResult.data
        }
        
        if let hotelResult = results["hotel_search"], hotelResult.ok {
            finalPlan["hotel"] = hotelResult.data
        }
        
        if let routeResult = results["route_planner"], routeResult.ok {
            finalPlan["itinerary"] = routeResult.data
        }
        
        if let budgetResult = results["budget_analyzer"], budgetResult.ok {
            finalPlan["budget"] = budgetResult.data
        }
        
        // 添加工具执行统计
        let toolStats = results.mapValues { result in
            return ["ok": result.ok, "error": result.error as Any? ?? NSNull()]
        }
        finalPlan["tool_stats"] = toolStats
        
        return finalPlan
    }
    
    // MARK: - 工具执行辅助方法
    
    /// 执行单个工具并解析结果
    /// - Parameters:
    ///   - name: 工具名称
    ///   - arguments: 工具参数
    /// - Returns: 执行结果
    private func runTool(name: String, arguments: [String: Any]) async -> ToolExecutionResult? {
        do {
            print("开始执行工具: \(name)")
            
            // 1. 使用与 AgentExecutor 相同的方式执行工具
            let raw = try await toolManager.executeTool(name: name, arguments: arguments)
            
            // 2. 使用 normalizeToolResult 对结果进行规范化处理
            let normalizedResult = normalizeToolResult(raw, toolName: name)
            print("工具 \(name) 执行成功")
            
            // 3. 解析JSON结果
            if let data = normalizedResult.data(using: .utf8),
               let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return ToolExecutionResult(name: name, ok: true, raw: normalizedResult, data: jsonObj, error: nil)
            } else {
                // 非JSON结果也视为成功，但包装为简单结构
                return ToolExecutionResult(name: name, ok: true, raw: normalizedResult, data: ["text": raw], error: nil)
            }
        } catch {
            let errorStr = error.localizedDescription
            print("工具 \(name) 执行失败: \(errorStr)")
            
            // 4. 规范化错误响应
            let errorData: [String: Any] = [
                "ok": false,
                "tool": name,
                "error": errorStr,
                "query": arguments
            ]
            
            // 转换为JSON字符串
            if let errorJson = try? JSONSerialization.data(withJSONObject: errorData),
               let errorJsonStr = String(data: errorJson, encoding: .utf8) {
                return ToolExecutionResult(name: name, ok: false, raw: errorJsonStr, data: errorData, error: errorStr)
            }
            
            return ToolExecutionResult(name: name, ok: false, raw: "{}", data: [:], error: errorStr)
        }
    }

    // 添加 normalizeToolResult 方法（从AgentExecutor中复制）
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
        if let data = try? JSONSerialization.data(withJSONObject: wrapper) {
            return String(data: data, encoding: .utf8) ?? raw
        }
        return raw
    }
    
    // MARK: - 辅助方法
    
    /// 解析日期字符串为Date对象
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    /// 格式化Date为字符串
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
