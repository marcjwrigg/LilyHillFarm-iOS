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

    // Custom decoder to handle messages stored as JSON string in database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        farmId = try container.decode(UUID.self, forKey: .farmId)
        title = try container.decode(String.self, forKey: .title)
        messageCount = try container.decode(Int.self, forKey: .messageCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)

        // Messages are stored as a JSON string in the database
        // First decode as string, then parse the JSON
        let messagesString = try container.decode(String.self, forKey: .messages)
        guard let messagesData = messagesString.data(using: .utf8) else {
            throw DecodingError.dataCorruptedError(
                forKey: .messages,
                in: container,
                debugDescription: "Messages string could not be converted to data"
            )
        }

        let messagesDecoder = JSONDecoder()
        messagesDecoder.dateDecodingStrategy = .iso8601
        messages = try messagesDecoder.decode([ChatMessage].self, from: messagesData)
    }

    // Custom encoder to match the decoding behavior (though the repository handles encoding)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(farmId, forKey: .farmId)
        try container.encode(title, forKey: .title)
        try container.encode(messageCount, forKey: .messageCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(lastMessagePreview, forKey: .lastMessagePreview)
        try container.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)

        // Encode messages as JSON string
        let messagesEncoder = JSONEncoder()
        messagesEncoder.dateEncodingStrategy = .iso8601
        let messagesData = try messagesEncoder.encode(messages)
        let messagesString = String(data: messagesData, encoding: .utf8) ?? "[]"
        try container.encode(messagesString, forKey: .messages)
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
