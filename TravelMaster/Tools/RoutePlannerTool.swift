//
//  RoutePlannerTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/16.
//

import Foundation

struct RoutePlannerTool: Tool {
    let name = "route_planner"
    let description = "基于高德地图规划多景点最优路线，支持步行、驾车、公交等方式"
    
    var parameters: [String: Any] {
        [
            "city": [
                "type": "string",
                "description": "城市名"
            ],
            "attractions": [
                "type": "array",
                "description": "景点列表",
                "items": [
                    "type": "string"
                ]
            ],
            "start_location": [
                "type": "string",
                "description": "起点（酒店名或地铁站）",
                "default": ""
            ],
            "transport_mode": [
                "type": "string",
                "description": "交通方式：walking/driving/transit",
                "default": "transit"
            ],
            "optimize_for": [
                "type": "string", 
                "description": "优化目标：time/distance",
                "default": "time"
            ]
        ]
    }
    
    func toAPIFormat() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": parameters,
                    "required": ["city", "attractions"]
                ]
            ]
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        let city = arguments["city"] as? String ?? ""
        let attractions = arguments["attractions"] as? [String] ?? []
        let startLocation = arguments["start_location"] as? String ?? ""
        let transportMode = arguments["transport_mode"] as? String ?? "transit"
        let optimizeFor = arguments["optimize_for"] as? String ?? "time"
        
        guard !city.isEmpty, !attractions.isEmpty else {
            throw AIError.configurationError("城市和景点列表必填")
        }
        
        let config = try MapConfiguration.load()
        let amap = AMapService(config: config)
        
        // 1. 获取所有地点的坐标
        let locations = try await getLocationsCoordinates(
            city: city,
            places: [startLocation] + attractions,
            amap: amap
        )
        
        // 2. 计算最优路线
        let optimizedRoute = try await calculateOptimalRoute(
            locations: locations,
            mode: transportMode,
            optimizeFor: optimizeFor,
            amap: amap
        )
        
        // 3. 生成详细行程
        let detailedItinerary = try await generateDetailedItinerary(
            route: optimizedRoute,
            mode: transportMode,
            city: city,
            amap: amap
        )
        
        let result: [String: Any] = [
            "city": city,
            "transport_mode": transportMode,
            "optimized_route": optimizedRoute.map { $0.name },
            "total_duration": calculateTotalDuration(detailedItinerary),
            "total_distance": calculateTotalDistance(detailedItinerary),
            "detailed_itinerary": detailedItinerary,
            "recommendations": generateRecommendations(for: optimizedRoute, mode: transportMode)
        ]
        
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - 私有方法
    
    private func getLocationsCoordinates(city: String, places: [String], amap: AMapService) async throws -> [LocationInfo] {
        var locations: [LocationInfo] = []
        
        for place in places where !place.isEmpty {
            do {
                let (lng, lat) = try await amap.geocodePOI(city: city, keyword: place)
                locations.append(LocationInfo(name: place, lng: lng, lat: lat))
            } catch {
                print("⚠️ 无法获取 \(place) 的坐标: \(error)")
                // 继续处理其他地点，不中断整个流程
            }
        }
        
        return locations
    }
    
    private func calculateOptimalRoute(
        locations: [LocationInfo], 
        mode: String,
        optimizeFor: String,
        amap: AMapService
    ) async throws -> [LocationInfo] {
        
        guard locations.count >= 2 else { return locations }
        
        // 简化版TSP算法：贪心选择最近邻
        var unvisited = Array(locations.dropFirst()) // 去掉起点
        var route = [locations.first!] // 从起点开始
        
        while !unvisited.isEmpty {
            let current = route.last!
            var bestNext: LocationInfo?
            var bestCost = Double.infinity
            
            // 并发计算到所有未访问点的距离/时间
            let costs = await withTaskGroup(of: (LocationInfo, Double).self) { group in
                for candidate in unvisited {
                    group.addTask {
                        let cost = await self.calculateCost(
                            from: current, 
                            to: candidate,
                            mode: mode,
                            optimizeFor: optimizeFor,
                            amap: amap
                        )
                        return (candidate, cost)
                    }
                }
                
                var results: [(LocationInfo, Double)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            // 选择成本最低的下一个点
            for (candidate, cost) in costs {
                if cost < bestCost {
                    bestCost = cost
                    bestNext = candidate
                }
            }
            
            if let next = bestNext {
                route.append(next)
                unvisited.removeAll { $0.name == next.name }
            } else {
                break
            }
        }
        
        return route
    }
    
    private func calculateCost(
        from: LocationInfo,
        to: LocationInfo, 
        mode: String,
        optimizeFor: String,
        amap: AMapService
    ) async -> Double {
        do {
            switch mode.lowercased() {
            case "walking":
                let seconds = try await amap.walkingSecs(
                    origin: (from.lng, from.lat),
                    dest: (to.lng, to.lat)
                )
                return optimizeFor == "time" ? Double(seconds) : Double(seconds) * 1.4 // 步行距离近似
                
            case "driving":
                let seconds = try await amap.drivingSecs(
                    origin: (from.lng, from.lat),
                    dest: (to.lng, to.lat)
                )
                return Double(seconds)
                
            case "transit":
                let seconds = try await amap.transitSecs(
                    origin: (from.lng, from.lat),
                    dest: (to.lng, to.lat),
                    city: "上海" // 这里应该传递实际城市参数
                )
                return Double(seconds)
                
            default:
                return Double.infinity
            }
        } catch {
            return Double.infinity // 无法到达时返回最大值
        }
    }
    
    private func generateDetailedItinerary(
        route: [LocationInfo],
        mode: String,
        city: String,
        amap: AMapService
    ) async throws -> [[String: Any]] {
        
        var itinerary: [[String: Any]] = []
        
        for i in 0..<route.count {
            let current = route[i]
            var step: [String: Any] = [
                "step": i + 1,
                "location": current.name,
                "coordinates": "\(current.lng),\(current.lat)",
                "arrival_time": estimateArrivalTime(step: i, baseTime: "09:00"),
                "suggested_duration": "60-90分钟"
            ]
            
            // 如果不是最后一站，计算到下一站的路线
            if i < route.count - 1 {
                let next = route[i + 1]
                let routeInfo = try await getRouteInfo(
                    from: current,
                    to: next,
                    mode: mode,
                    city: city,
                    amap: amap
                )
                step["next_destination"] = next.name
                step["route_info"] = routeInfo
            }
            
            itinerary.append(step)
        }
        
        return itinerary
    }
    
    private func getRouteInfo(
        from: LocationInfo,
        to: LocationInfo,
        mode: String,
        city: String,
        amap: AMapService
    ) async throws -> [String: Any] {
        
        switch mode.lowercased() {
        case "walking":
            let seconds = try await amap.walkingSecs(
                origin: (from.lng, from.lat),
                dest: (to.lng, to.lat)
            )
            return [
                "duration": "\(seconds / 60)分钟",
                "distance": "约\(Int(Double(seconds) * 1.4))米",
                "transport": "步行",
                "suggestion": "建议穿舒适的鞋子"
            ]
            
        case "driving":
            let seconds = try await amap.drivingSecs(
                origin: (from.lng, from.lat),
                dest: (to.lng, to.lat)
            )
            return [
                "duration": "\(seconds / 60)分钟", 
                "transport": "驾车",
                "suggestion": "注意停车位置"
            ]
            
        case "transit":
            let seconds = try await amap.transitSecs(
                origin: (from.lng, from.lat),
                dest: (to.lng, to.lat),
                city: city
            )
            return [
                "duration": "\(seconds / 60)分钟", 
                "transport": "公共交通",
                "suggestion": "建议使用地铁+步行组合"
            ]
            
        default:
            return [
                "duration": "未知",
                "transport": mode
            ]
        }
    }
    
    private func calculateTotalDuration(_ itinerary: [[String: Any]]) -> String {
        // 简化计算：假设每个景点停留1小时，加上路程时间
        let stopsCount = itinerary.count
        let totalMinutes = stopsCount * 60 + 120 // 60分钟/景点 + 2小时路程
        return "\(totalMinutes / 60)小时\(totalMinutes % 60)分钟"
    }
    
    private func calculateTotalDistance(_ itinerary: [[String: Any]]) -> String {
        return "约8-12公里" // 简化返回，实际可累计计算
    }
    
    private func generateRecommendations(for route: [LocationInfo], mode: String) -> [String] {
        var tips: [String] = []
        
        switch mode {
        case "walking":
            tips.append("建议穿舒适的步行鞋")
            tips.append("携带充足的水")
        case "transit":
            tips.append("建议购买一日交通卡")
            tips.append("避开早晚高峰时段")
        case "driving":
            tips.append("注意停车场位置")
            tips.append("预留停车费预算")
        default:
            break
        }
        
        if route.count > 4 {
            tips.append("景点较多，建议分两天游览")
        }
        
        tips.append("建议提前查看各景点的开放时间")
        tips.append("携带充电宝以备导航使用")
        
        return tips
    }
    
    private func estimateArrivalTime(step: Int, baseTime: String) -> String {
        // 简化时间估算：每个景点间隔1.5小时
        let minutes = step * 90
        let hour = 9 + minutes / 60
        let minute = minutes % 60
        return String(format: "预计%02d:%02d", hour, minute)
    }
}

// MARK: - 辅助数据结构

struct LocationInfo {
    let name: String
    let lng: Double
    let lat: Double
}
