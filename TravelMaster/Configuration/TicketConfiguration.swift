//
//  TicketConfiguration.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/16.
//

import Foundation

struct TicketConfiguration {
    let amadeusAPIKey: String
    let amadeusAPISecret: String
    let amadeusEnvironment: String
    
    enum ConfigError: Error, LocalizedError {
        case missingConfig
        case missingKey(String)
        
        var errorDescription: String? {
            switch self {
            case .missingConfig:
                return "无法找到 TicketConfig.plist 文件"
            case .missingKey(let key):
                return "配置中缺少 \(key) 键"
            }
        }
    }
    
    static func load() throws -> TicketConfiguration {
        guard let url = Bundle.main.url(forResource: "TicketConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw ConfigError.missingConfig
        }
        
        guard let apiKey = dict["AMADEUS_API_KEY"] as? String, !apiKey.isEmpty else {
            throw ConfigError.missingKey("AMADEUS_API_KEY")
        }
        
        guard let apiSecret = dict["AMADEUS_API_SECRET"] as? String, !apiSecret.isEmpty else {
            throw ConfigError.missingKey("AMADEUS_API_SECRET")
        }
        
        let env = dict["AMADEUS_ENV"] as? String ?? "test"
        
        return TicketConfiguration(
            amadeusAPIKey: apiKey,
            amadeusAPISecret: apiSecret,
            amadeusEnvironment: env
        )
    }
}
