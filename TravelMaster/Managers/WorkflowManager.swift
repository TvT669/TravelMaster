//
//  WorkflowManager.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/27.
//

import Foundation
import Combine

@MainActor
class WorkflowManager: ObservableObject {
    /// 可用工具列表
    private var tools: [EnhancedTool] = []
    
    /// 当前活跃的工作流
    @Published var activeWorkflows: [UUID: WorkflowContext] = [:]
    
    /// 工作流执行状态
    @Published var workflowStatus: [UUID: String] = [:]
    
    // 添加进度属性
    @Published var progress: Double = 0
    
    /// AI服务，用于任务分解和理解
    //private let aiService: AIAgentService
    
    init() {
        registerTools()
    }
    
    /// 注册所有可用工具
    private func registerTools() {
        print("正在注册工具...")
        
        // 清除现有工具
        tools = []
        
        // 创建工具实例并注册
        let flightTool = FlightSearchTool()
        tools.append(ToolAdapter(flightTool))
        
        let hotelTool = HotelNearMetroTool()
        tools.append(ToolAdapter(hotelTool))
        
        let routeTool = RoutePlannerTool()
        tools.append(ToolAdapter(routeTool))
        
        let budgetTool = BudgetAnalyzerTool()
        tools.append(ToolAdapter(budgetTool))
        
        let calculatorTool = CalculatorTool()
        tools.append(ToolAdapter(calculatorTool))
        
        print("成功注册了 \(tools.count) 个工具:")
        for tool in tools {
            print(" - \(tool.name): \(String(describing: type(of: tool)))")
        }
    }
    
    /// 执行用户请求
    func executeRequest(_ request: String) async -> UUID {
        // 创建新的工作流上下文
        let context = WorkflowContext(userRequest: request)
        
        // 记录工作流
        activeWorkflows[context.taskId] = context
        workflowStatus[context.taskId] = "开始分析请求..."
        print("创建工作流: \(context.taskId), 请求: \(request)")
        
        // 异步执行工作流
        Task {
            do {
                print("开始处理工作流: \(context.taskId)")
                await processWorkflow(context)
                print("工作流处理完成: \(context.taskId)")
            } catch {
                print("工作流处理错误: \(error.localizedDescription)")
                context.state = .failed
                context.error = error
                workflowStatus[context.taskId] = "失败: \(error.localizedDescription)"
            }
        }
        
        return context.taskId
    }
    
    /// 处理工作流
    private func processWorkflow(_ context: WorkflowContext) async {
        print("工作流处理步骤1: 任务分解")
        // 更新工作流状态
        context.state = .inProgress
        workflowStatus[context.taskId] = "正在分解任务..."
        
        // 进行任务分解
        do {
            let subtasks = try await decomposeTask(context.userRequest)
            print("分解出 \(subtasks.count) 个子任务")
            
            // 更新工作流状态
            workflowStatus[context.taskId] = "已分解为\(subtasks.count)个子任务"
            
            // 记录子任务
            for (index, task) in subtasks.enumerated() {
                context.set("subtask_\(index)", value: task)
            }
            
            // 找到合适的工具执行子任务
            var toolAssignments: [(String, EnhancedTool)] = []
            
            for task in subtasks {
                if let tool = findBestTool(for: task) {
                    print("为任务 '\(task)' 选择了工具: \(tool.name)")
                    toolAssignments.append((task, tool))
                } else {
                    print("没有找到适合任务 '\(task)' 的工具")
                }
            }
            
            workflowStatus[context.taskId] = "选择了\(toolAssignments.count)个工具执行任务"
            
            // 执行工具调用
            print("工作流处理步骤3: 工具执行")
            workflowStatus[context.taskId] = "正在执行工具..."
            
            for (index, (task, tool)) in toolAssignments.enumerated() {
                print("执行工具 \(index+1)/\(toolAssignments.count): \(tool.name)")
                workflowStatus[context.taskId] = "正在执行: \(tool.name) (\(index+1)/\(toolAssignments.count))"
                
                do {
                    // 创建子任务上下文
                    let subContext = WorkflowContext(userRequest: task)
                    
                    // 执行工具
                    let result = try await tool.execute(with: subContext)
                    print("工具 \(tool.name) 执行结果: \(result.prefix(50))...")
                    
                    // 保存结果
                    context.set("result_\(task)", value: result)
                } catch {
                    print("工具 \(tool.name) 执行失败: \(error.localizedDescription)")
                    context.set("error_\(task)", value: error.localizedDescription)
                }
            }
            
            // 整合结果
            print("工作流处理步骤4: 整合结果")
            workflowStatus[context.taskId] = "正在整合结果..."
            
            do {
                let finalResult = try await integrateResults(context)
                context.set("finalResult", value: finalResult)
                
                // 更新状态
                context.state = .completed
                workflowStatus[context.taskId] = "完成"
                print("工作流处理完成，结果长度: \(finalResult.count)")
            } catch {
                print("整合结果失败: \(error.localizedDescription)")
                context.state = .failed
                context.error = error
                workflowStatus[context.taskId] = "结果整合失败"
                
                // 设置一个错误结果
                let errorResult = "很抱歉，在整合结果时遇到了问题: \(error.localizedDescription)"
                context.set("finalResult", value: errorResult)
            }
            
        } catch {
            print("任务分解失败: \(error.localizedDescription)")
            context.state = .failed
            context.error = error
            workflowStatus[context.taskId] = "任务分解失败"
            
            // 设置一个错误结果
            let errorResult = "很抱歉，无法理解您的请求: \(error.localizedDescription)"
            context.set("finalResult", value: errorResult)
        }
    }
    
    /// 使用AI分解任务
    private func decomposeTask(_ request: String) async throws -> [String] {
        print("分解任务: \(request)")
        
        // 根据关键词匹配分解
        let lowercasedRequest = request.lowercased()
        
        // 提取目的地城市
        var destination = "上海"
        if lowercasedRequest.contains("到") {
            if let range = request.range(of: "到([^的，,。；;]+)", options: .regularExpression) {
                let matched = request[range]
                destination = String(matched.dropFirst()) // 去掉"到"字
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "的.*$", with: "", options: .regularExpression)
            }
        }
        
        // 通用分解模板
        if lowercasedRequest.contains("旅行") || lowercasedRequest.contains("行程") || lowercasedRequest.contains("规划") {
            print("匹配到旅行规划模板")
            var tasks: [String] = []
            
            // 1. 机票搜索
            if lowercasedRequest.contains("从") && lowercasedRequest.contains("到") {
                var origin = "北京"
                if let range = request.range(of: "从([^到]+)到", options: .regularExpression) {
                    let matched = request[range]
                    origin = String(matched.dropFirst().dropLast(1)) // 去掉"从"和"到"
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                tasks.append("搜索从\(origin)到\(destination)的机票")
            } else {
                tasks.append("搜索机票信息")
            }
            
            // 2. 酒店搜索
            if lowercasedRequest.contains("酒店") || lowercasedRequest.contains("住宿") {
                if lowercasedRequest.contains("地铁") || lowercasedRequest.contains("附近") {
                    tasks.append("查找\(destination)地铁站附近的酒店")
                } else {
                    tasks.append("查找\(destination)的酒店")
                }
            }
            
            // 3. 路线规划
            if lowercasedRequest.contains("景点") || lowercasedRequest.contains("游览") || lowercasedRequest.contains("路线") {
                tasks.append("规划\(destination)的旅游路线")
            }
            
            // 4. 预算分析
            if lowercasedRequest.contains("预算") || lowercasedRequest.contains("元") {
                // 尝试提取预算金额
                var budget = "3000"
                if let range = request.range(of: "预算(\\d+)元", options: .regularExpression) {
                    let matched = request[range]
                    budget = matched.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                }
                tasks.append("分析\(budget)元旅行预算")
            }
            
            return tasks.isEmpty ? ["搜索机票", "查找酒店", "规划行程"] : tasks
        }
        
        // 针对比价的请求
        if lowercasedRequest.contains("比较") || lowercasedRequest.contains("比价") {
            if lowercasedRequest.contains("机票") {
                return ["比较不同航空公司的机票价格"]
            }
            if lowercasedRequest.contains("酒店") {
                return ["比较不同酒店的价格和位置"]
            }
            return ["比较旅行方案"]
        }
        
        // 默认分解
        print("使用默认任务分解")
        return [
            "搜索机票信息",
            "查找酒店信息",
            "规划旅游路线"
        ]
    }
    
    /// 为任务找到最合适的工具
    private func findBestTool(for task: String) -> EnhancedTool? {
        let lowercasedTask = task.lowercased()
        print("尝试为任务匹配工具: \(task)")
        
        // 1. 直接通过 canHandle 匹配
        for tool in tools {
            if tool.canHandle(request: task) {
                print("工具 \(tool.name) 通过 canHandle 方法匹配成功")
                return tool
            }
        }
        
        // 2. 关键词匹配（备用方案）
        if lowercasedTask.contains("机票") || lowercasedTask.contains("航班") || lowercasedTask.contains("飞机") {
            print("通过关键词'机票/航班/飞机'匹配")
            return tools.first { $0.name.lowercased().contains("flight") }
        }
        
        if lowercasedTask.contains("酒店") || lowercasedTask.contains("住宿") || lowercasedTask.contains("宾馆") {
            print("通过关键词'酒店/住宿/宾馆'匹配")
            return tools.first { $0.name.lowercased().contains("hotel") }
        }
        
        if lowercasedTask.contains("路线") || lowercasedTask.contains("行程") || lowercasedTask.contains("规划") || lowercasedTask.contains("景点") {
            print("通过关键词'路线/行程/规划/景点'匹配")
            return tools.first { $0.name.lowercased().contains("route") }
        }
        
        if lowercasedTask.contains("预算") || lowercasedTask.contains("费用") || lowercasedTask.contains("元") {
            print("通过关键词'预算/费用/元'匹配")
            return tools.first { $0.name.lowercased().contains("budget") }
        }
        
        print("没有找到匹配工具")
        return nil
    }
    private func extractDestination(from request: String) -> String? {
        if let range = request.range(of: "到([^的，,。；;\\s]+)", options: .regularExpression) {
            return String(request[range].dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractBudget(from request: String) -> String? {
        if let range = request.range(of: "(\\d+)元", options: .regularExpression) {
            return String(request[range]).replacingOccurrences(of: "元", with: "")
        }
        return nil
    }

    private func extractDays(from request: String) -> String? {
        if let range = request.range(of: "(\\d+)天", options: .regularExpression) {
            return String(request[range]).replacingOccurrences(of: "天", with: "")
        }
        return nil
    }
    
    /// 整合所有结果（容错：解析成功的部分格式化，解析失败记录错误并继续）
    private func integrateResults(_ context: WorkflowContext) async throws -> String {
        let userRequest = context.userRequest
        let destination = extractDestination(from: userRequest) ?? "目的地"
        let daysInt = Int(extractDays(from: userRequest) ?? "3") ?? 3
        let nights = max(daysInt - 1, 1)
        let budget = extractBudget(from: userRequest) ?? "3000"
        
        guard let storage = context.getAllStorage() else {
            throw NSError(domain: "WorkflowManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "工作流没有返回任何数据"])
        }
        
        var sections: [String] = []
        var failures: [(key: String, reason: String, raw: String?)] = []
        
        for (key, value) in storage {
            guard key.starts(with: "result_"), let raw = value as? String else { continue }
            
            // 先尝试解析 JSON
            if let dict = jsonToDict(raw) {
                // 根据结构判断类型并格式化
                if dict["flights"] != nil || findFlightsArray(in: dict) != nil || (dict["flight_count"] as? Int) != nil {
                    if let s = formatFlightSection(from: dict) {
                        sections.append(s)
                    } else {
                        failures.append((key, "航班字段不完整或未知结构", raw.prefix(1000).description))
                    }
                } else if dict["hotels"] != nil || dict["station"] != nil {
                    if let s = formatHotelSection(from: dict) {
                        sections.append(s)
                    } else {
                        failures.append((key, "酒店字段不完整或未知结构", raw.prefix(1000).description))
                    }
                } else if dict["detailed_itinerary"] != nil || dict["optimized_route"] != nil || dict["days"] != nil {
                    if let s = formatRouteSection(from: dict, maxDays: daysInt) {
                        sections.append(s)
                    } else {
                        failures.append((key, "行程字段不完整或未知结构", raw.prefix(1000).description))
                    }
                } else if dict["budget_breakdown"] != nil || dict["daily_budget"] != nil || dict["allocations"] != nil {
                    if let s = formatBudgetSection(from: dict, totalBudget: budget) {
                        sections.append(s)
                    } else {
                        failures.append((key, "预算字段不完整或未知结构", raw.prefix(1000).description))
                    }
                } else {
                    // 未识别类型：把可读键值对加入“其他”部分
                    let pretty = dict.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                    sections.append("【其他: \(String(key.dropFirst(7)))】\n\(pretty)")
                }
            } else {
                // 非 JSON 或 JSON 解析失败
                failures.append((key, "不是有效的 JSON", raw.prefix(1000).description))
            }
        }
        
        if sections.isEmpty && !failures.isEmpty {
            // 没有任何可读部分，返回错误（或抛错，按需求此处抛错）
            throw NSError(domain: "WorkflowManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "无法解析任何工具返回的结构化结果，请检查工具输出。示例失败项：\(failures.first?.key ?? "")"] )
        }
        
        // 生成最终文本
        var final = "为您生成的\(destination)\(daysInt)天\(nights)夜旅行计划（预算：\(budget)元）\n\n"
        final += sections.joined(separator: "\n\n")
        
        // 如果有失败项，附加简短报错和提示（不把原始 JSON 直接展示到前端，便于排查用）
        if !failures.isEmpty {
            final += "\n\n---\n\n提示：部分子任务解析失败：\n"
            for f in failures {
                final += "• \(String(f.key.dropFirst(7))): \(f.reason)\n"
            }
            final += "\n（如需调试，请查看工具原始返回或在日志中查找相应 raw JSON）"
        }
        
        return final
    }
    
    // 简单 JSON 解析为字典
    private func jsonToDict(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    }
    
    // 递归查找可能的航班数组（容错）
    private func findFlightsArray(in any: Any) -> [[String: Any]]? {
        if let arr = any as? [[String: Any]], !arr.isEmpty { return arr }
        if let dict = any as? [String: Any] {
            for k in ["flights","data","itineraries","results","items"] {
                if let v = dict[k], let found = findFlightsArray(in: v) { return found }
            }
            for (_, v) in dict { if let found = findFlightsArray(in: v) { return found } }
        }
        if let arrAny = any as? [Any] {
            for v in arrAny { if let found = findFlightsArray(in: v) { return found } }
        }
        return nil
    }
    
    // 航班段格式化（容错提取 segments / price 等）
    private func formatFlightSection(from dict: [String: Any]) -> String? {
        guard let flights = (dict["flights"] as? [[String: Any]]) ?? findFlightsArray(in: dict) else { return nil }
        var out = "## ✈️ 往返交通（推荐选择）：\n"
        for (i, f) in flights.prefix(2).enumerated() {
            let tag = i == 0 ? "去程" : "返程"
            // 支持多种字段名
            let priceAny = (f["price"] as? [String: Any])?["total"] ?? f["price"] ?? f["fare"] ?? f["amount"]
            let price = toDouble(priceAny)
            // 尝试从 segments 提取航班号/时间/机场
            var segInfo = ""
            if let segments = f["segments"] as? [[String: Any]], let seg = segments.first {
                let flightNo = (seg["flight_number"] as? String) ?? (seg["number"] as? String) ?? (seg["flight_number"] as? String) ?? "—"
                let depAirport = (seg["departure"] as? [String: Any])?["airport"] as? String ?? ""
                let depTime = (seg["departure"] as? [String: Any])?["time"] as? String ?? ""
                let arrAirport = (seg["arrival"] as? [String: Any])?["airport"] as? String ?? ""
                let arrTime = (seg["arrival"] as? [String: Any])?["time"] as? String ?? ""
                segInfo = "\(flightNo) (\(depTime) \(depAirport) - \(arrTime) \(arrAirport))"
            } else {
                // 兼容 flat fields
                let flightNo = f["flightNumber"] as? String ?? f["flight_number"] as? String ?? f["number"] as? String ?? "—"
                let dep = f["departureTime"] as? String ?? f["departure"] as? String ?? ""
                let arr = f["arrivalTime"] as? String ?? f["arrival"] as? String ?? ""
                let origin = f["origin"] as? String ?? f["originCode"] as? String ?? ""
                let dest = f["destination"] as? String ?? f["destinationCode"] as? String ?? ""
                if !flightNo.isEmpty { segInfo = "\(flightNo) (\(dep) \(origin) - \(arr) \(dest))" }
            }
            var line = "• \(tag)："
            if !segInfo.isEmpty { line += segInfo }
            if price > 0 { line += "，票价 ¥\(Int(price))" }
            out += line + "\n"
        }
        // 预算提示
        if let first = flights.first, let pAny = (first["price"] as? [String: Any])?["total"] ?? first["price"], toDouble(pAny) > 1500 {
            out += "• （注：机票占比较大，建议考虑高铁等更经济的选项以平衡预算）"
        }
        return out
    }
    
    // 酒店格式化
    private func formatHotelSection(from dict: [String: Any]) -> String? {
        guard let hotels = dict["hotels"] as? [[String: Any]], !hotels.isEmpty else { return nil }
        var out = "## 🏨 住宿推荐（靠近地铁站）：\n"
        for (i, h) in hotels.prefix(3).enumerated() {
            let name = h["name"] as? String ?? "酒店\(i+1)"
            if let metro = (h["metroExit"] as? String) {
                if let dAny = h["walkMinutes"] ?? h["walkMinutes"], let mins = dAny as? Int {
                    out += "\(i+1). \(name) - 距\(metro)约\(mins)分钟\n"
                } else if let distAny = h["approxDistanceM"] ?? h["distanceToMetro"], toDouble(distAny) > 0 {
                    let meters = Int(toDouble(distAny))
                    out += "\(i+1). \(name) - 距\(metro)约\(meters)米\n"
                } else {
                    out += "\(i+1). \(name) - 距\(metro)\n"
                }
            } else {
                out += "\(i+1). \(name)\n"
            }
        }
        return out
    }
    
    // 行程格式化
    private func formatRouteSection(from dict: [String: Any], maxDays: Int) -> String? {
        // 支持 detailed_itinerary 或 days 数组
        if let detailed = dict["detailed_itinerary"] as? [[String: Any]], !detailed.isEmpty {
            var out = "## 🗺️ 推荐行程路线：\n"
            for (i, step) in detailed.prefix(maxDays).enumerated() {
                let loc = step["location"] as? String ?? "地点\(i+1)"
                let dur = step["suggested_duration"] as? String ?? ""
                out += "**Day \(i+1):** \(loc)"
                if !dur.isEmpty { out += "（建议停留：\(dur)）" }
                out += "\n"
            }
            out += "\n**（可根据您的兴趣调整）**"
            return out
        }
        if let days = dict["days"] as? [[String: Any]], !days.isEmpty {
            var out = "## 🗺️ 推荐行程路线：\n"
            for (i, day) in days.prefix(maxDays).enumerated() {
                out += "**Day \(i+1):** "
                if let attractions = day["attractions"] as? [[String: Any]] {
                    let names = attractions.compactMap { $0["name"] as? String }
                    out += names.joined(separator: " -> ")
                } else if let activities = day["activities"] as? [String] {
                    out += activities.joined(separator: " -> ")
                } else {
                    return nil
                }
                out += "\n"
            }
            out += "\n**（可根据您的兴趣调整）**"
            return out
        }
        return nil
    }
    
    // 预算格式化
    private func formatBudgetSection(from dict: [String: Any], totalBudget: String) -> String? {
        let budget = Double(totalBudget) ?? 3000.0
        var out = "## 💰 预算分析（总计¥\(Int(budget))）：\n"
        if let breakdown = dict["budget_breakdown"] as? [String: Any] {
            if let flight = (breakdown["flight"] as? [String: Any])?["amount"] ?? (breakdown["flight"] as? Double) {
                out += "• 机票：~¥\(Int(toDouble(flight)))\n"
            }
            if let acc = (breakdown["accommodation"] as? [String: Any])?["amount"] ?? (breakdown["accommodation"] as? Double) {
                out += "• 住宿：~¥\(Int(toDouble(acc))) (2晚)\n"
            }
            if let food = (breakdown["food"] as? [String: Any])?["amount"] ?? (breakdown["food"] as? Double) {
                out += "• 餐饮：~¥\(Int(toDouble(food) / Double(max(1, 3))))/天\n"
            }
            return out
        }
        if let daily = dict["daily_budget"] as? [String: Any] {
            if let per = daily["total"] as? Double {
                out += "• 每日预算（总计/天）：¥\(Int(per))\n"
            }
            if let perPerson = daily["per_person"] as? Double {
                out += "• 每人每日：¥\(Int(perPerson))\n"
            }
            return out
        }
        if let allocations = dict["allocations"] as? [String: Any] {
            if let tAny = allocations["transportation"] { out += "• 机票：~¥\(Int(toDouble(tAny))) (\(pct(toDouble(tAny), budget))%)\n" }
            if let aAny = allocations["accommodation"] { out += "• 住宿：~¥\(Int(toDouble(aAny))) (2晚，\(pct(toDouble(aAny), budget))%)\n" }
            return out
        }
        return nil
    }
    
    // Any -> Double 辅助
    private func toDouble(_ any: Any?) -> Double {
        guard let any = any else { return 0.0 }
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) ?? 0.0 }
        return 0.0
    }
    
    private func pct(_ part: Double, _ total: Double) -> Int {
        guard total > 0 else { return 0 }
        return Int((part / total) * 100)
    }
    
    
    
    /// 获取工作流状态
    func getWorkflowStatus(id: UUID) -> String? {
        return workflowStatus[id]
    }
    
    /// 获取工作流结果
    func getWorkflowResult(id: UUID) -> String? {
        guard let context = activeWorkflows[id],
              context.state == .completed else {
            return nil
        }
        
        // 使用类型注解的方式获取结果
        let result: String? = context.get("finalResult")
        guard let unwrappedResult = result else {
            return nil
        }
        
        return unwrappedResult
    }
    
}
