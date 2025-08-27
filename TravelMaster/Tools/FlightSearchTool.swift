//
//  FlightSearchTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/16.
//

import Foundation

struct FlightSearchTool: Tool {
    let name = "flight_search"
    let description = "搜索指定日期和城市间的航班信息，支持单程和往返查询"
    
    var parameters: [String: Any] {
        [
            "origin": [
                "type": "string",
                "description": "出发城市或机场代码 (如: PEK, 北京)"
            ],
            "destination": [
                "type": "string",
                "description": "目的地城市或机场代码 (如: SHA, 上海)"
            ],
            "departure_date": [
                "type": "string",
                "description": "出发日期 (格式: YYYY-MM-DD)"
            ],
            "return_date": [
                "type": "string",
                "description": "返程日期 (格式: YYYY-MM-DD, 可选)"
            ],
            "adults": [
                "type": "integer",
                "description": "成人数量",
                "default": 1
            ],
            "children": [
                "type": "integer",
                "description": "儿童数量 (2-11岁)",
                "default": 0
            ],
            "travel_class": [
                "type": "string",
                "description": "舱位等级 (ECONOMY, PREMIUM_ECONOMY, BUSINESS, FIRST)",
                "default": "ECONOMY"
            ],
            "max_results": [
                "type": "integer",
                "description": "最大结果数",
                "default": 5
            ],
            "currency": [
                "type": "string",
                "description": "货币代码",
                "default": "CNY"
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
                    "required": ["origin", "destination", "departure_date"]
                ]
            ]
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        // 获取参数
        guard let origin = arguments["origin"] as? String, !origin.isEmpty else {
            throw AIError.configurationError("必须提供出发地")
        }
        
        guard let destination = arguments["destination"] as? String, !destination.isEmpty else {
            throw AIError.configurationError("必须提供目的地")
        }
        
        guard let departureDate = arguments["departure_date"] as? String, !departureDate.isEmpty else {
            throw AIError.configurationError("必须提供出发日期")
        }
        
        let returnDate = arguments["return_date"] as? String
        let adults = arguments["adults"] as? Int ?? 1
        let children = arguments["children"] as? Int ?? 0
        let travelClass = arguments["travel_class"] as? String ?? "ECONOMY"
        let maxResults = arguments["max_results"] as? Int ?? 5
        let currency = arguments["currency"] as? String ?? "CNY"
        
        // 创建 Amadeus 服务
        let config = try TicketConfiguration.load()
        let amadeus = AmadeusService(config: config)
        
        // 将城市名称转换为 IATA 代码（如果需要）
        var originCode = origin
        var destinationCode = destination
        
        // 如果输入不是 IATA 代码格式（3个字母），则尝试搜索机场
        if !isIATACode(origin) {
            // 先尝试本地映射
             if let mappedCode = amadeus.getCityCode(for: origin) {
                 print("🌍 使用本地映射: \(origin) -> \(mappedCode)")
                 originCode = mappedCode
             } else {
                 // 回退到API搜索(添加异常处理)
                 do {
                     print("🔍 尝试API搜索: \(origin)")
                     let airportResponse = try await amadeus.searchAirports(keyword: origin)
                     if let firstAirport = airportResponse.data.first {
                         originCode = firstAirport.iataCode
                         print("✅ API搜索成功: \(origin) -> \(originCode)")
                     } else {
                         // API返回为空
                         print("⚠️ API未找到结果: \(origin)")
                         throw AIError.configurationError("无法找到出发地机场代码: \(origin)")
                     }
                 } catch {
                     print("❌ API搜索失败: \(origin), 错误: \(error.localizedDescription)")
                     throw AIError.configurationError("无法确定出发地机场代码: \(origin)")
                 }
             }
        }
        
        if !isIATACode(destination) {
            if let mappedCode = amadeus.getCityCode(for: destination) {
                 print("🌍 使用本地映射: \(destination) -> \(mappedCode)")
                 destinationCode = mappedCode
             } else {
                 do {
                     print("🔍 尝试API搜索: \(destination)")
                     let airportResponse = try await amadeus.searchAirports(keyword: destination)
                     if let firstAirport = airportResponse.data.first {
                         destinationCode = firstAirport.iataCode
                         print("✅ API搜索成功: \(destination) -> \(destinationCode)")
                     } else {
                         print("⚠️ API未找到结果: \(destination)")
                         throw AIError.configurationError("无法找到目的地机场代码: \(destination)")
                     }
                 } catch {
                     print("❌ API搜索失败: \(destination), 错误: \(error.localizedDescription)")
                     throw AIError.configurationError("无法确定目的地机场代码: \(destination)")
                 }
             };   if let mappedCode = amadeus.getCityCode(for: destination) {
                 print("🌍 使用本地映射: \(destination) -> \(mappedCode)")
                 destinationCode = mappedCode
             } else {
                 do {
                     print("🔍 尝试API搜索: \(destination)")
                     let airportResponse = try await amadeus.searchAirports(keyword: destination)
                     if let firstAirport = airportResponse.data.first {
                         destinationCode = firstAirport.iataCode
                         print("✅ API搜索成功: \(destination) -> \(destinationCode)")
                     } else {
                         print("⚠️ API未找到结果: \(destination)")
                         throw AIError.configurationError("无法找到目的地机场代码: \(destination)")
                     }
                 } catch {
                     print("❌ API搜索失败: \(destination), 错误: \(error.localizedDescription)")
                     throw AIError.configurationError("无法确定目的地机场代码: \(destination)")
                 }
             }
        }
        
        // 搜索航班
        let searchParams = AmadeusService.FlightOffersSearchParams(
            originLocationCode: originCode,
            destinationLocationCode: destinationCode,
            departureDate: departureDate,
            returnDate: returnDate,
            adults: adults,
            children: children,
            infants: 0,
            travelClass: travelClass,
            maxResults: maxResults,
            currencyCode: currency
        )
        
        do {
            let response = try await amadeus.searchFlightOffers(params: searchParams)
            
            // 提取所需信息转换为友好格式
            let flights = response.data.prefix(maxResults).map { offer -> [String: Any] in
                var flightInfo: [String: Any] = [
                    "id": offer.id,
                    "price": [
                        "total": offer.price.total,
                        "currency": offer.price.currency
                    ]
                ]
                
                // 提取行程信息
                var segments: [[String: Any]] = []
                for itinerary in offer.itineraries {
                    for segment in itinerary.segments {
                        let segmentInfo: [String: Any] = [
                            "departure": [
                                "airport": segment.departure.iataCode,
                                "time": formatDateTime(segment.departure.at)
                            ],
                            "arrival": [
                                "airport": segment.arrival.iataCode,
                                "time": formatDateTime(segment.arrival.at)
                            ],
                            "airline": segment.carrierCode,
                            "flight_number": segment.number,
                            "duration": segment.duration
                        ]
                        segments.append(segmentInfo)
                    }
                }
                
                flightInfo["segments"] = segments
                
                // 提取舱位信息
                if let firstTraveler = offer.travelerPricings.first,
                   let firstSegment = firstTraveler.fareDetailsBySegment.first {
                    flightInfo["cabin_class"] = firstSegment.cabin
                }
                
                return flightInfo
            }
            
            // 构建最终返回结果
            let result: [String: Any] = [
                "ok": true,
                "tool": name,
                "query": [
                    "origin": origin,
                    "origin_code": originCode,
                    "destination": destination,
                    "destination_code": destinationCode,
                    "departure_date": departureDate,
                    "return_date": returnDate ?? "无",
                    "adults": adults,
                    "children": children,
                    "travel_class": travelClass
                ],
                "flight_count": flights.count,
                "flights": flights,
                "is_round_trip": returnDate != nil,
                "currency": currency
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            let errorResult: [String: Any] = [
                "ok": false,
                "tool": name,
                "error": error.localizedDescription,
                "query": [
                    "origin": origin,
                    "destination": destination,
                    "departure_date": departureDate
                ]
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: errorResult)
            return String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"Unknown error\"}"
        }
    }
    
    // 判断是否是 IATA 代码（3个字母）
    private func isIATACode(_ code: String) -> Bool {
        return code.count == 3 && code.uppercased() == code
    }
    
    // 格式化日期时间
    private func formatDateTime(_ isoString: String) -> String {
        // 转换 ISO8601 格式到友好的展示格式
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: isoString) else {
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}
