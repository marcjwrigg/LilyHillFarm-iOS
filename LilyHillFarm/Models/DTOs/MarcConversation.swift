//
//  MarcConversation.swift
//  LilyHillFarm
//
//  Model for Marc AI conversation history
//

import Foundation

struct MarcConversation: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let farmId: UUID
    let title: String
    let messages: [ChatMessage]
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let lastMessagePreview: String?
    let lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case farmId = "farm_id"
        case title
        case messages
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
    }
}

struct MarcConversationSummary: Codable, Identifiable {
    let id: UUID
    let title: String
    let lastMessagePreview: String?
    let lastMessageAt: Date?
    let messageCount: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt = "last_message_at"
        case messageCount = "message_count"
        case updatedAt = "updated_at"
    }
}
