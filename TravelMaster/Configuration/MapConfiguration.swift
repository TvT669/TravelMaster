//
//  MapConfiguration.swift
//  TravelMaster
//
//   Created by 珠穆朗玛小蜜蜂 on 2025/8/14.
//

import Foundation

struct MapConfiguration {
    let apiKey: String

    enum ConfigError: Error, LocalizedError {
        case missingKey

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "缺少高德 Key。请在 MapConfig.plist 的 AMAP_API_KEY 中填写，或在 Info.plist 添加同名键。"
            }
        }
    }

    static func load() throws -> MapConfiguration {
        // 优先从 MapConfig.plist 读取
        if let url = Bundle.main.url(forResource: "MapConfig", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = obj as? [String: Any],
           let key = dict["amapWebKey"] as? String, !key.isEmpty {
            return MapConfiguration(apiKey: key)
        }

        // 其次从 Info.plist 读取
        if let key = Bundle.main.object(forInfoDictionaryKey: "AMAP_API_KEY") as? String, !key.isEmpty {
            return MapConfiguration(apiKey: key)
        }

        throw ConfigError.missingKey
    }
}
