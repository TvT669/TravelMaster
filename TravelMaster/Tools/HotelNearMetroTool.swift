//
//  HotelNearMetroTool.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/14.
//

import Foundation

struct HotelNearMetroTool: Tool {
    let name = "hotel_near_metro"
    let description = "按地铁站筛选步行N分钟内的酒店（高德Web服务）。"
    var parameters: [String : Any] {
            [
                "city": [
                    "type": "string",
                    "description": "城市名"
                ],
                "station": [
                    "type": "string",
                    "description": "地铁站名"
                ],
                "maxWalkMinutes": [
                    "type": "integer",
                    "description": "最大步行分钟数",
                    "default": 5
                ],
                "radiusMeters": [
                    "type": "integer",
                    "description": "搜索半径（米）",
                    "default": 600
                ],
                "maxResults": [
                    "type": "integer",
                    "description": "最多返回酒店数量",
                    "default": 10
                ]
            ]
        }
            
    func toAPIFormat() -> [String : Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": parameters,
                    "required": ["city", "station"]
                ]
            ]
        ]
    }
    
    func execute(arguments: [String : Any]) async throws -> String {
        let city = arguments["city"] as? String ?? ""
        let station = arguments["station"] as? String ?? ""
        let maxMin = (arguments["maxWalkMinutes"] as? Int) ?? 5
        let radius = (arguments["radiusMeters"] as? Int) ?? 600
        let maxOut = (arguments["maxResults"] as? Int) ?? 10
        
        guard !city.isEmpty, !station.isEmpty else {
            throw AIError.configurationError("city/station 必填")
        }
        
        let config = try MapConfiguration.load()
        let amap = AMapService(config: config)
        let (lng, lat) = try await amap.geocodeMetroStation(city: city, station: station)
        let pois = try await amap.searchHotelsAround(lng: lng, lat: lat, radius: radius, limit: 20)
        
        func parse(_ loc: String) -> (Double, Double)? {
            let p = loc.split(separator: ","); guard p.count == 2, let a = Double(p[0]), let b = Double(p[1]) else { return nil }; return (a,b)
        }
        
        let filtered: [[String: Any]] = await withTaskGroup(of: [String: Any]?.self) { group in
            for poi in pois {
                guard let to = parse(poi.location) else { continue }
                group.addTask {
                    do {
                        let secs = try await amap.walkingSecs(origin: (lng,lat), dest: to)
                        let mins = Int(ceil(Double(secs)/60.0))
                        return mins <= maxMin ? [
                            "name": poi.name,
                            "address": poi.address ?? "",
                            "location": poi.location,
                            "walkMinutes": mins,
                            "approxDistanceM": Int(poi.distance ?? "0") ?? 0
                        ] : nil
                    } catch { return nil }
                }
            }
            var out: [[String: Any]] = []
            for await one in group { if let one = one { out.append(one) } }
            return out
        }
        .sorted { ($0["walkMinutes"] as? Int ?? 0) < ($1["walkMinutes"] as? Int ?? 0) }
        .prefix(maxOut)
        .map { $0 }
        
        let result: [String: Any] = [
            "station": ["city": city, "name": station, "location": "\(lng),\(lat)"],
            "maxWalkMinutes": maxMin,
            "hotels": filtered
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
