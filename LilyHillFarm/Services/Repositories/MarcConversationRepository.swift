//
//  MarcConversationRepository.swift
//  LilyHillFarm
//
//  Repository for managing Marc AI conversation history
//

import Foundation
import Supabase

@MainActor
class MarcConversationRepository {
    private let supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager) {
        self.supabaseManager = supabaseManager
    }

    // MARK: - Fetch Conversations

    /// Fetch all conversations for current user's farm
    func fetchConversations() async throws -> [MarcConversationSummary] {
        guard let client = supabaseManager.client else {
            throw RepositoryError.notAuthenticated
        }

        let farmId = try await supabaseManager.fetchFarmId()

        let response = try await client
            .from("marc_conversations")
            .select("id, title, last_message_preview, last_message_at, message_count, updated_at")
            .eq("farm_id", value: farmId.uuidString)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let conversations = try decoder.decode([MarcConversationSummary].self, from: response.data)

        return conversations
    }

    /// Fetch a specific conversation with full message history
    func fetchConversation(id: UUID) async throws -> MarcConversation {
        guard let client = supabaseManager.client else {
            throw RepositoryError.notAuthenticated
        }

        let response = try await client
            .from("marc_conversations")
            .select("*")
            .eq("id", value: id.uuidString)
            .is("deleted_at", value: nil)
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let conversation = try decoder.decode(MarcConversation.self, from: response.data)

        return conversation
    }

    // MARK: - Create Conversation

    /// Create a new conversation
    func createConversation(title: String, messages: [ChatMessage]) async throws -> UUID {
        guard let client = supabaseManager.client else {
            throw RepositoryError.notAuthenticated
        }

        let farmId = try await supabaseManager.fetchFarmId()
        let userId = try await client.auth.session.user.id

        // Get last message for preview
        let lastMessage = messages.last
        let lastMessagePreview = lastMessage?.content.prefix(100).description ?? ""

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let messagesData = try encoder.encode(messages)
        let messagesJson = String(data: messagesData, encoding: .utf8) ?? "[]"

        struct ConversationInsert: Encodable {
            let user_id: String
            let farm_id: String
            let title: String
            let messages: String
            let message_count: Int
            let last_message_preview: String
            let last_message_at: String
        }

        let conversationData = ConversationInsert(
            user_id: userId.uuidString,
            farm_id: farmId.uuidString,
            title: title,
            messages: messagesJson,
            message_count: messages.count,
            last_message_preview: lastMessagePreview,
            last_message_at: ISO8601DateFormatter().string(from: Date())
        )

        let response = try await client
            .from("marc_conversations")
            .insert(conversationData)
            .select("id")
            .single()
            .execute()

        struct ConversationId: Decodable {
            let id: UUID
        }

        let result = try JSONDecoder().decode(ConversationId.self, from: response.data)
        return result.id
    }

    // MARK: - Update Conversation

    /// Update conversation with new messages
    func updateConversation(id: UUID, messages: [ChatMessage]) async throws {
        guard let client = supabaseManager.client else {
            throw RepositoryError.notAuthenticated
        }

        // Get last message for preview
        let lastMessage = messages.last
        let lastMessagePreview = lastMessage?.content.prefix(100).description ?? ""

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let messagesData = try encoder.encode(messages)
        let messagesJson = String(data: messagesData, encoding: .utf8) ?? "[]"

        struct ConversationUpdate: Encodable {
            let messages: String
            let message_count: Int
            let last_message_preview: String
            let last_message_at: String
        }

        let updateData = ConversationUpdate(
            messages: messagesJson,
            message_count: messages.count,
            last_message_preview: lastMessagePreview,
            last_message_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client
            .from("marc_conversations")
            .update(updateData)
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Delete Conversation

    /// Soft delete a conversation
    func deleteConversation(id: UUID) async throws {
        guard let client = supabaseManager.client else {
            throw RepositoryError.notAuthenticated
        }

        struct ConversationDelete: Encodable {
            let deleted_at: String
        }

        let deleteData = ConversationDelete(
            deleted_at: ISO8601DateFormatter().string(from: Date())
        )

        try await client
            .from("marc_conversations")
            .update(deleteData)
            .eq("id", value: id.uuidString)
            .execute()
    }
}
