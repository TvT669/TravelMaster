//
//  StorageService.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/4.
//

import Foundation

protocol StorageServiceProtocol {
    func saveConversation(_ message: [ChatMessage]) async throws
    func loadConversations() async throws -> [[ChatMessage]]
    func clearConversations() async throws
}

class StorageService: StorageServiceProtocol {
    private let userDefaults = UserDefaults.standard
    private let conversationkey = "saved_conversations"
    
    
    func saveConversation(_ messages: [ChatMessage]) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(messages)
        
        var savedConversations = try await loadConversationsData()
        savedConversations.append(data)
    }
    
    func loadConversations() async throws -> [[ChatMessage]] {
        let conversationData = try await loadConversationsData()
        let decoder = JSONDecoder()
        
        return try conversationData.map { data in
            try decoder.decode([ChatMessage].self, from: data)
        }
    }
    
    func clearConversations() async throws {
        userDefaults.removeObject(forKey: conversationkey)
    }
    
    private func loadConversationsData() async throws -> [Data] {
        guard let data = userDefaults.array(forKey: conversationkey) as? [Data] else {
            return []
        }
        return data
    }
}
