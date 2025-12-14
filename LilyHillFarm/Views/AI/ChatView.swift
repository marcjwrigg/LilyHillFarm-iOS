//
//  ChatView.swift
//  LilyHillFarm
//
//  Main AI chat interface
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(aiService: AIService, supabaseManager: SupabaseManager, conversationId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            aiService: aiService,
            supabaseManager: supabaseManager,
            conversationId: conversationId
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                                MessageRow(message: message)
                                    .id(index)
                            }

                            if viewModel.isLoading {
                                LoadingIndicator()
                            }

                            if viewModel.voiceService.isGeneratingAudio {
                                GeneratingAudioIndicator()
                            } else if viewModel.voiceService.isSpeaking {
                                SpeakingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping on messages
                        isInputFocused = false
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.count - 1, anchor: .bottom)
                        }
                    }
                }

                // Error Message
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onDismiss: {
                        viewModel.errorMessage = nil
                    })
                }

                // Input Area
                ChatInputView(
                    text: $viewModel.inputText,
                    selectedImages: $viewModel.selectedImages,
                    isLoading: viewModel.isLoading,
                    isListening: viewModel.voiceService.isListening,
                    isInputFocused: $isInputFocused,
                    onSend: viewModel.sendMessage,
                    onAddImage: viewModel.addImage,
                    onRemoveImage: viewModel.removeImage,
                    onStartVoiceInput: viewModel.startVoiceInput,
                    onStopVoiceInput: { viewModel.stopVoiceInput() }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // Navigate away from chat (go back to previous tab)
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToDashboard"), object: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Image("marc-avatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Voice output toggle
                        Button {
                            viewModel.toggleVoiceOutput()
                        } label: {
                            Image(systemName: viewModel.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .foregroundColor(viewModel.voiceEnabled ? .blue : .gray)
                        }

                        // Context menu
                        Menu {
                            Picker("Context", selection: $viewModel.selectedContext) {
                                Text("General").tag(ChatContext.general)
                                Text("Project").tag(ChatContext.project)
                                Text("Health").tag(ChatContext.health)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                isInputFocused = true
            }
            .onDisappear {
                viewModel.clearChat()
            }
        }
    }
}

// MARK: - Message Row
struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Marc's avatar for assistant messages
            if message.role == .assistant {
                Image("marc-avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1))
            }

            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Message bubble
                MarkdownText(
                    message.content,
                    fontSize: 17,
                    textColor: message.role == .user ? .white : .primary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    message.role == .user
                        ? LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

                // Images indicator (base64 strings can't be displayed without decoding)
                if let images = message.images, !images.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                        Text("\(images.count) image\(images.count == 1 ? "" : "s")")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, message.role == .user ? 0 : 16)
                }
            }
            .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Chat Input
struct ChatInputView: View {
    @Binding var text: String
    @Binding var selectedImages: [UIImage]
    let isLoading: Bool
    let isListening: Bool
    var isInputFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onAddImage: (UIImage) -> Void
    let onRemoveImage: (Int) -> Void
    let onStartVoiceInput: () -> Void
    let onStopVoiceInput: () -> Void

    @State private var showImagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 12) {
                // Image thumbnails
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .cornerRadius(12)
                                        .clipped()

                                    Button {
                                        onRemoveImage(index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 20, height: 20))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Text input
                HStack(alignment: .bottom, spacing: 10) {
                    if isListening {
                        // When listening, show full-width Speak button
                        Button {
                            onStopVoiceInput()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)

                                Image(systemName: "waveform")
                                    .font(.system(size: 20, weight: .medium))

                                Text("Listening... Tap to stop")
                                    .font(.system(size: 17, weight: .medium))

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(25)
                        }
                    } else {
                        // Normal layout with all controls
                        // Photo button
                        Button {
                            showImagePicker = true
                        } label: {
                            Image(systemName: "photo.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(selectedImages.count >= 4 ? .gray : .blue)
                        }
                        .disabled(isLoading || selectedImages.count >= 4)

                        // Speak button
                        Button {
                            // Dismiss keyboard before starting voice input
                            isInputFocused.wrappedValue = false
                            onStartVoiceInput()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Speak")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                        }
                        .disabled(isLoading)

                        // Text field with send button
                        ZStack(alignment: .trailing) {
                            TextField("Message Marc...", text: $text, axis: .vertical)
                                .padding(10)
                                .padding(.trailing, 40)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                                .lineLimit(1...6)
                                .disabled(isLoading)
                                .focused(isInputFocused)
                                .onSubmit {
                                    onSend()
                                }

                            Button {
                                onSend()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                        .frame(width: 32, height: 32)

                                    Image(systemName: isLoading ? "hourglass" : "arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                            .padding(.trailing, 6)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isListening)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                selectedImages: $selectedImages,
                maxImages: 4,
                onAddImage: onAddImage
            )
        }
    }
}

// MARK: - Supporting Views
struct LoadingIndicator: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("marc-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1))

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Marc is thinking...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            Spacer(minLength: 60)
        }
    }
}

struct GeneratingAudioIndicator: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("marc-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1))

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Generating audio...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            Spacer(minLength: 60)
        }
    }
}

struct SpeakingIndicator: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("marc-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1))

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Marc is speaking...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            Spacer(minLength: 60)
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button("Dismiss", action: onDismiss)
        }
        .padding()
        .background(Color(.systemRed).opacity(0.1))
    }
}
