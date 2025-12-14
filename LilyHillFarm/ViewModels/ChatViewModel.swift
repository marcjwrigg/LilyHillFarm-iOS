//
//  ChatViewModel.swift
//  LilyHillFarm
//
//  View model for AI chat interface
//

import SwiftUI
import PhotosUI
import Combine
import Supabase
import Auth

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var selectedImages: [UIImage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedContext: ChatContext = .general
    @Published var voiceEnabled: Bool = false // User can toggle voice on/off

    private let aiService: AIService
    private let supabaseManager: SupabaseManager
    @ObservedObject var voiceService: VoiceService = VoiceService()
    private let conversationRepository: MarcConversationRepository

    // Current conversation ID (nil for new conversations)
    var currentConversationId: UUID?

    // Context data builder
    func buildContextData() async throws -> [String: AnyCodable] {
        let farmId = try await supabaseManager.fetchFarmId()
        let farmIdString = farmId.uuidString

        switch selectedContext {
        case .general:
            return ChatRequest.generalContextData(farmId: farmIdString)
        case .project:
            // TODO: Populate from project detail view when integrated
            return ChatRequest.generalContextData(farmId: farmIdString)
        case .health:
            // TODO: Populate from cattle health view when integrated
            return ChatRequest.generalContextData(farmId: farmIdString)
        }
    }

    init(aiService: AIService, supabaseManager: SupabaseManager, conversationId: UUID? = nil) {
        self.aiService = aiService
        self.supabaseManager = supabaseManager
        self.conversationRepository = MarcConversationRepository(supabaseManager: supabaseManager)
        self.currentConversationId = conversationId

        // Set up callback for when voice stops automatically (from silence detection)
        voiceService.onAutoStopListening = { [weak self] in
            guard let self = self else { return }
            _Concurrency.Task { @MainActor in
                // Trigger auto-send when silence detection stops listening
                self.stopVoiceInput(autoSend: true)
            }
        }

        // Load existing conversation or add welcome message
        if let conversationId = conversationId {
            _Concurrency.Task {
                await loadConversation(id: conversationId)
            }
        } else {
            addWelcomeMessage()
        }
    }

    // MARK: - Public Methods

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        _Concurrency.Task {
            // Disable voice when sending typed text
            await sendMessageAsync(fromVoiceInput: false)
        }
    }

    func addImage(_ image: UIImage) {
        guard selectedImages.count < 4 else {
            errorMessage = "Maximum 4 images allowed"
            return
        }
        selectedImages.append(image)
    }

    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }

    func clearImages() {
        selectedImages.removeAll()
    }

    func clearChat() {
        messages.removeAll()
        inputText = ""
        selectedImages.removeAll()
        errorMessage = nil
        voiceService.stopSpeaking()
        voiceService.stopListening()
        currentConversationId = nil // Start new conversation
        addWelcomeMessage()
    }

    // MARK: - Conversation Management

    func loadConversation(id: UUID) async {
        do {
            let conversation = try await conversationRepository.fetchConversation(id: id)
            messages = conversation.messages
            currentConversationId = id
            print("✅ [ChatViewModel] Loaded conversation with \(messages.count) messages")
        } catch {
            print("❌ [ChatViewModel] Error loading conversation: \(error)")
            errorMessage = "Failed to load conversation"
            addWelcomeMessage()
        }
    }

    func saveConversation() async {
        do {
            // Generate title from first user message
            let title = messages.first(where: { $0.role == .user })?.content.prefix(50).description ?? "New Conversation"

            if let conversationId = currentConversationId {
                // Update existing conversation
                try await conversationRepository.updateConversation(id: conversationId, messages: messages)
                print("✅ [ChatViewModel] Updated conversation")
            } else {
                // Create new conversation
                let newId = try await conversationRepository.createConversation(title: title, messages: messages)
                currentConversationId = newId
                print("✅ [ChatViewModel] Created new conversation")
            }
        } catch {
            print("❌ [ChatViewModel] Error saving conversation: \(error)")
            // Don't show error to user - message still works locally
        }
    }

    // MARK: - Voice Methods

    func startVoiceInput() {
        _Concurrency.Task {
            do {
                try await voiceService.startListening()

                // Auto-enable voice output for natural conversation
                if !voiceEnabled {
                    voiceEnabled = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopVoiceInput(autoSend: Bool = true) {
        print("🛑 [ChatViewModel] stopVoiceInput called with autoSend=\(autoSend)")

        // Only stop listening if still listening (avoid duplicate stop calls)
        if voiceService.isListening {
            voiceService.stopListening()
        }

        // Copy transcribed text to input field
        let transcribed = voiceService.transcribedText
        print("📝 [ChatViewModel] Transcribed text: '\(transcribed)'")

        if !transcribed.isEmpty {
            inputText = transcribed

            // Auto-send message when voice input completes
            if autoSend && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("📤 [ChatViewModel] Auto-sending message...")
                // Small delay to ensure UI updates
                _Concurrency.Task {
                    try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    print("📤 [ChatViewModel] Calling sendMessageAsync...")
                    // Keep voice enabled for voice input
                    await sendMessageAsync(fromVoiceInput: true)
                }
            } else {
                print("⚠️ [ChatViewModel] Not auto-sending: autoSend=\(autoSend), isEmpty=\(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
            }
        } else {
            print("⚠️ [ChatViewModel] Transcribed text is empty, not sending")
        }
    }

    func toggleVoiceOutput() {
        voiceEnabled.toggle()
        if !voiceEnabled {
            voiceService.stopSpeaking()
        }
    }

    func retry() {
        // Resend last user message
        if let lastUserMessage = messages.last(where: { $0.role == .user }) {
            inputText = lastUserMessage.content
            if let images = lastUserMessage.images {
                // Note: Can't recover original UIImages from base64, so user needs to re-add them
                print("[ChatViewModel] Cannot restore images from previous message")
            }
        }
    }

    // MARK: - Private Methods

    private func sendMessageAsync(fromVoiceInput: Bool = false) async {
        errorMessage = nil
        isLoading = true

        // If sending typed text (not voice), disable voice output
        if !fromVoiceInput {
            print("💬 [ChatViewModel] Text message detected - disabling voice output")
            voiceEnabled = false
        } else {
            print("🎤 [ChatViewModel] Voice message detected - keeping voice output enabled")
        }

        // Build user message
        var chatImages: [ChatImage]? = nil
        if !selectedImages.isEmpty {
            do {
                chatImages = try selectedImages.map { try aiService.convertImageToBase64(image: $0) }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
        }

        let userMessage = ChatMessage(
            role: .user,
            content: inputText,
            images: chatImages
        )

        // Add to message list
        messages.append(userMessage)

        // Clear input
        let messagesCopy = messages
        inputText = ""
        selectedImages.removeAll()

        do {
            // Build context data
            let contextData = try await buildContextData()

            // Send to API
            let response = try await aiService.sendMessage(
                messages: messagesCopy,
                context: selectedContext,
                contextData: contextData
            )

            // Handle response
            handleResponse(response)

            // Save conversation after successful response
            await saveConversation()

        } catch {
            print("❌ [ChatViewModel] Error sending message: \(error)")
            errorMessage = error.localizedDescription
            // Remove user message on error (or keep it for retry)
            // messages.removeLast()
        }

        isLoading = false
    }

    private func handleResponse(_ response: ChatResponse) {
        switch response.type {
        case .message:
            // Regular conversational response
            if let content = response.content {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: content,
                    images: nil
                )

                // If voice is enabled, wait to show message until audio starts
                if voiceEnabled {
                    // Set callback to show message when audio starts playing
                    voiceService.onAudioPlaybackStarted = { [weak self] in
                        guard let self = self else { return }
                        _Concurrency.Task { @MainActor in
                            self.messages.append(assistantMessage)
                        }
                    }
                    voiceService.speak(content, voice: .male)
                } else {
                    // No voice - show message immediately
                    messages.append(assistantMessage)
                }
            }

        case .suggestion:
            // Structured suggestion (project/health plan)
            var textToSpeak = ""
            var messagesToAdd: [ChatMessage] = []

            if let message = response.message {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: message,
                    images: nil
                )
                messagesToAdd.append(assistantMessage)
                textToSpeak = message
            }

            // TODO: Parse and display suggestion data
            // For now, just show the summary
            if let suggestion = response.suggestion,
               let summary = suggestion.data["summary"]?.value as? String {
                let summaryMessage = ChatMessage(
                    role: .assistant,
                    content: "📋 **Suggestion**: \(summary)",
                    images: nil
                )
                messagesToAdd.append(summaryMessage)

                if textToSpeak.isEmpty {
                    textToSpeak = "I have a suggestion for you. \(summary)"
                }
            }

            // If voice is enabled, wait to show messages until audio starts
            if voiceEnabled && !textToSpeak.isEmpty {
                voiceService.onAudioPlaybackStarted = { [weak self] in
                    guard let self = self else { return }
                    _Concurrency.Task { @MainActor in
                        self.messages.append(contentsOf: messagesToAdd)
                    }
                }
                voiceService.speak(textToSpeak, voice: .male)
            } else {
                // No voice - show messages immediately
                messages.append(contentsOf: messagesToAdd)
            }
        }
    }

    func addWelcomeMessage() {
        let greetings = [
            "Hey! Marc here. What can I help you with today?",
            "Marc at your service! What do you need?",
            "Howdy! Ready to talk cattle, projects, or whatever else is on your mind?",
            "Hi there! I'm Marc, your farm management assistant. What's up?",
        ]

        // 20% chance of sarcastic greeting
        let sarcasticGreetings = [
            "Oh great, another question about cattle. Just kidding! What's up?",
            "Well, well, well... looks like someone needs my help. What can I do for ya?",
            "Marc here. Let me guess - the weather's still unpredictable and equipment's still broken? 😏"
        ]

        let useSarcastic = Double.random(in: 0...1) < 0.2
        let greeting = useSarcastic
            ? sarcasticGreetings.randomElement()!
            : greetings.randomElement()!

        let welcomeMessage = ChatMessage(
            role: .assistant,
            content: greeting,
            images: nil
        )
        messages.append(welcomeMessage)

        // Don't speak the initial welcome message
    }
}
