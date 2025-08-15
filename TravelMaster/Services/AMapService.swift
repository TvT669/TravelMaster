//
//  AMapService.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation

struct AMapService {
    let apiKey: String

    init(config: MapConfiguration) {
        self.apiKey = config.apiKey
    }

    func geocodeMetroStation(city: String, station: String) async throws -> (Double, Double) {
        var comps = URLComponents(string: "https://restapi.amap.com/v3/place/text")!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "keywords", value: station),
            .init(name: "city", value: city),
            .init(name: "citylimit", value: "true"),
            .init(name: "types", value: "150500"), // 地铁站
            .init(name: "offset", value: "1"),
            .init(name: "page", value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(AMapPlaceResponse.self, from: data)
        guard resp.status == "1", let first = resp.pois.first,
              let loc = parseLocation(first.location) else {
            throw AIError.networkError(NSError(domain: "AMap", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到地铁站"]))
        }
        return loc
    }

    func searchHotelsAround(lng: Double, lat: Double, radius: Int, limit: Int) async throws -> [AMapPOI] {
        var comps = URLComponents(string: "https://restapi.amap.com/v3/place/around")!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "location", value: "\(lng),\(lat)"),
            .init(name: "radius", value: "\(radius)"),
            .init(name: "types", value: "1001"), // 宾馆酒店
            .init(name: "sortrule", value: "distance"),
            .init(name: "offset", value: "\(min(limit, 50))"),
            .init(name: "page", value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(AMapPlaceResponse.self, from: data)
        guard resp.status == "1" else {
            throw AIError.networkError(NSError(domain: "AMap", code: -2, userInfo: [NSLocalizedDescriptionKey: "酒店搜索失败"]))
        }
        return resp.pois
    }

    func walkingSecs(origin: (Double, Double), dest: (Double, Double)) async throws -> Int {
        var comps = URLComponents(string: "https://restapi.amap.com/v3/direction/walking")!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "origin", value: "\(origin.0),\(origin.1)"),
            .init(name: "destination", value: "\(dest.0),\(dest.1)")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(AMapWalkingResponse.self, from: data)
        guard resp.status == "1", let secsStr = resp.route?.paths?.first?.duration, let secs = Int(secsStr) else {
            throw AIError.networkError(NSError(domain: "AMap", code: -3, userInfo: [NSLocalizedDescriptionKey: "步行路径计算失败"]))
        }
        return secs
    }
    
    // 通用POI搜索
    func geocodePOI(city: String, keyword: String) async throws -> (Double, Double) {
        var comps = URLComponents(string: "https://restapi.amap.com/v3/place/text")!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "keywords", value: keyword),
            .init(name: "city", value: city),
            .init(name: "citylimit", value: "true"),
            .init(name: "offset", value: "1"),
            .init(name: "page", value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(AMapPlaceResponse.self, from: data)
        guard resp.status == "1", let first = resp.pois.first,
              let loc = parseLocation(first.location) else {
            throw AIError.networkError(NSError(domain: "AMap", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到地点：\(keyword) in \(city)"]))
        }
        return loc
    }

    // 公交路线查询
    func transitSecs(origin: (Double, Double), dest: (Double, Double), city: String) async throws -> Int {
        var comps = URLComponents(string: "https://restapi.amap.com/v3/direction/transit/integrated")!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "origin", value: "\(origin.0),\(origin.1)"),
            .init(name: "destination", value: "\(dest.0),\(dest.1)"),
            .init(name: "city", value: city)
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(AMapTransitResponse.self, from: data)
        guard resp.status == "1", let secsStr = resp.route?.transits?.first?.duration, let secs = Int(secsStr) else {
            throw AIError.networkError(NSError(domain: "AMap", code: -4, userInfo: [NSLocalizedDescriptionKey: "公交路径计算失败"]))
        }
        return secs
    }

    // 驾车路线查询
    func drivingSecs(origin: (Double, Double), dest: (Double, Double)) async throws -> Int {
        var comps = URLComponents(string: "https://restapi.amap.com/v3/direction/driving")!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "origin", value: "\(origin.0),\(origin.1)"),
            .init(name: "destination", value: "\(dest.0),\(dest.1)")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(AMapDrivingResponse.self, from: data)
        guard resp.status == "1", let secsStr = resp.route?.paths?.first?.duration, let secs = Int(secsStr) else {
            throw AIError.networkError(NSError(domain: "AMap", code: -5, userInfo: [NSLocalizedDescriptionKey: "驾车路径计算失败"]))
        }
        return secs
    }

    // MARK: - 内部模型与工具
    private func parseLocation(_ s: String) -> (Double, Double)? {
        let p = s.split(separator: ",")
        guard p.count == 2, let a = Double(p[0]), let b = Double(p[1]) else { return nil }
        return (a, b)
    }
}

// 复用在此文件中的轻量解码模型
private struct AMapPlaceResponse: Decodable {
    let status: String
    let count: String?
    let pois: [AMapPOI]
}

struct AMapPOI: Decodable {
    let name: String
    let location: String
    let address: String?
    let distance: String?

    private enum CodingKeys: String, CodingKey {
        case name, location, address, distance
    }

    init(name: String, location: String, address: String?, distance: String?) {
        self.name = name
        self.location = location
        self.address = address
        self.distance = distance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.location = (try? container.decode(String.self, forKey: .location)) ?? ""
        self.address = try? container.decode(String.self, forKey: .address)

        // distance 可能是 String/Int/Double/Array
        if let s = try? container.decode(String.self, forKey: .distance) {
            self.distance = s
        } else if let i = try? container.decode(Int.self, forKey: .distance) {
            self.distance = String(i)
        } else if let d = try? container.decode(Double.self, forKey: .distance) {
            self.distance = String(Int(d))
        } else if let arr = try? container.decode([String].self, forKey: .distance), let first = arr.first {
            self.distance = first
        } else if let arrAny = try? container.decode([Int].self, forKey: .distance), let first = arrAny.first {
            self.distance = String(first)
        } else {
            self.distance = nil
        }
    }
}

private struct AMapWalkingResponse: Decodable {
    let status: String
    let route: AMapRoute?
}

private struct AMapRoute: Decodable {
    let paths: [AMapPath]?
}

private struct AMapTransitResponse: Decodable {
    let status: String
    let route: AMapTransitRoute?
}

private struct AMapTransitRoute: Decodable {
    let transits: [AMapTransitPath]?
}

private struct AMapTransitPath: Decodable {
    let duration: String?
}

private struct AMapDrivingResponse: Decodable {
    let status: String
    let route: AMapDrivingRoute?
}

private struct AMapDrivingRoute: Decodable {
    let paths: [AMapPath]?
}

private struct AMapPath: Decodable {
    let duration: String?
}
