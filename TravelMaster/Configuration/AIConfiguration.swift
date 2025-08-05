//
//  AIConfiguration.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation

struct AIConfiguration {
    static let shared = AIConfiguration()
    
    let apiKey: String
    let baseURL: String
    let model: String
    let maxTokens: Int
    let temperature: Double
    
    private init() {
        if let path = Bundle.main.path(forResource: "AIConfig", ofType: "plist"),
        let config = NSDictionary(contentsOfFile: path) {
            self.apiKey = config["API_KEY"] as? String ?? "sk-bd845719604f4338b1361fae11dba09e"
            self.baseURL = config["BASE_URL"] as? String ?? "https://api.deepseek.com"
            self.model = config["MODEL"] as? String ?? "deepseek-chat"
            self.maxTokens = config["MAX_TOKENS"] as? Int ?? 4000
            self.temperature = config["TEMPERATURE"] as? Double ?? 0.7
        } else {
            self.apiKey = "sk-bd845719604f4338b1361fae11dba09e"
            self.baseURL = "https://api.deepseek.com"
            self.model = "deepseek-chat"
            self.maxTokens = 4000
            self.temperature = 0.7
            
        }
    }
}
