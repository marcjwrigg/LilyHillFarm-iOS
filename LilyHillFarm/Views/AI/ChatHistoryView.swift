//
//  ChatHistoryView.swift
//  LilyHillFarm
//
//  View for displaying Marc AI conversation history
//

import SwiftUI
import Combine

struct ChatHistoryView: View {
    @StateObject private var viewModel: ChatHistoryViewModel
    @State private var showingNewChat = false

    init(supabaseManager: SupabaseManager, aiService: AIService) {
        _viewModel = StateObject(wrappedValue: ChatHistoryViewModel(
            supabaseManager: supabaseManager,
            aiService: aiService
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading conversations...")
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                conversationsList
            }
        }
        .navigationTitle("Marc Conversations")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewChat = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            ChatView(
                aiService: viewModel.aiService,
                supabaseManager: viewModel.supabaseManager
            )
        }
        .refreshable {
            await viewModel.loadConversations()
        }
        .task {
            await viewModel.loadConversations()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image("marc-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 3))

            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a new conversation with Marc")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewChat = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Conversation")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Conversations List

    private var conversationsList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink(destination: conversationDetailView(for: conversation)) {
                    ConversationRow(conversation: conversation)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        _Concurrency.Task {
                            await viewModel.deleteConversation(conversation.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Conversation Detail

    @ViewBuilder
    private func conversationDetailView(for conversation: MarcConversationSummary) -> some View {
        ChatView(
            aiService: viewModel.aiService,
            supabaseManager: viewModel.supabaseManager,
            conversationId: conversation.id
        )
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: MarcConversationSummary

    private var timeAgo: String {
        guard let lastMessageAt = conversation.lastMessageAt else {
            return ""
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastMessageAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let preview = conversation.lastMessagePreview, !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 4) {
                Image(systemName: "message.fill")
                    .font(.caption2)
                Text("\(conversation.messageCount) messages")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class ChatHistoryViewModel: ObservableObject {
    @Published var conversations: [MarcConversationSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let supabaseManager: SupabaseManager
    let aiService: AIService
    private let repository: MarcConversationRepository

    init(supabaseManager: SupabaseManager, aiService: AIService) {
        self.supabaseManager = supabaseManager
        self.aiService = aiService
        self.repository = MarcConversationRepository(supabaseManager: supabaseManager)
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        do {
            conversations = try await repository.fetchConversations()
            print("✅ [ChatHistory] Loaded \(conversations.count) conversations")
        } catch {
            print("❌ [ChatHistory] Error loading conversations: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteConversation(_ id: UUID) async {
        do {
            try await repository.deleteConversation(id: id)
            conversations.removeAll { $0.id == id }
            print("✅ [ChatHistory] Deleted conversation")
        } catch {
            print("❌ [ChatHistory] Error deleting conversation: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}
