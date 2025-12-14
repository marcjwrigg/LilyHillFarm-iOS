//
//  VoiceService.swift
//  LilyHillFarm
//
//  Voice chat service for speech-to-text and text-to-speech
//

import Foundation
import Speech
import AVFoundation
import Combine
import Supabase
import Auth

@MainActor
class VoiceService: NSObject, ObservableObject {
    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var isGeneratingAudio: Bool = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // OpenAI TTS (replaces AVSpeechSynthesizer)
    private var audioPlayer: AVAudioPlayer?
    private let apiBaseURL: String

    // Silence detection
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 0.4 // Stop after 0.4 seconds of silence

    // Callback when listening stops automatically (from silence detection)
    var onAutoStopListening: (() -> Void)?

    // Callback when audio playback starts (for showing message in UI)
    var onAudioPlaybackStarted: (() -> Void)?

    override init() {
        // Get API base URL - use Vercel URL for Next.js API routes
        self.apiBaseURL = SupabaseConfig.apiURL
        super.init()
    }

    // MARK: - Speech-to-Text (Voice Input)

    /// Request microphone and speech recognition permissions
    func requestPermissions() async -> Bool {
        // Request microphone permission
        let micPermission = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micPermission else {
            await MainActor.run {
                errorMessage = "Microphone access is required for voice chat"
            }
            return false
        }

        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Speech recognition access is required for voice chat"
            }
            return false
        }

        return true
    }

    /// Start listening and transcribing speech
    func startListening() async throws {
        print("🎤 [VoiceService] startListening called...")

        // Stop any ongoing listening first
        if isListening {
            print("🎤 [VoiceService] Already listening, stopping first...")
            stopListening()
            // Small delay to ensure cleanup completes
            try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        // Cancel and clear any existing recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        // Clear silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil

        // Stop audio engine if running
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Remove any existing tap
        let audioInputNode = audioEngine.inputNode
        if audioInputNode.numberOfInputs > 0 {
            audioInputNode.removeTap(onBus: 0)
        }

        // Check permissions
        guard await requestPermissions() else {
            throw VoiceError.permissionDenied
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create fresh recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // Add farm-specific vocabulary hints to improve accuracy
        recognitionRequest.contextualStrings = [
            "calf", "calves", "calving", "calve", "calved",
            "cattle", "heifer", "heifers", "bull", "bulls", "cow", "cows",
            "breeding", "bred", "pregnancy", "pregnant",
            "weaning", "weaned", "wean",
            "pasture", "pastures",
            "vaccination", "vaccinate", "vaccinated",
            "treatment", "treated", "treating",
            "health record", "health records",
            "tag number", "ear tag",
            "veterinarian", "vet",
            "foot rot", "pink eye", "scours",
            "deworm", "deworming", "dewormed"
        ]

        // Start audio engine and install tap
        let recordingFormat = audioInputNode.outputFormat(forBus: 0)
        audioInputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                _Concurrency.Task { @MainActor in
                    // Ignore results if we're not listening anymore
                    guard self.isListening else {
                        print("⚠️ [VoiceService] Ignoring result - not listening anymore")
                        return
                    }

                    self.transcribedText = result.bestTranscription.formattedString
                    print("🎤 [VoiceService] Transcribed: \(result.bestTranscription.formattedString) (isFinal: \(result.isFinal))")

                    // Cancel existing silence timer
                    self.silenceTimer?.invalidate()

                    // If we got a final result, stop immediately
                    if result.isFinal {
                        print("✅ [VoiceService] Final result detected, stopping...")
                        self.stopListening()
                        self.onAutoStopListening?()
                    } else {
                        // Start a new silence timer - if no more speech for X seconds, consider it done
                        print("⏱️ [VoiceService] Starting silence timer...")
                        self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceTimeout, repeats: false) { [weak self] _ in
                            guard let self = self else { return }
                            _Concurrency.Task { @MainActor in
                                print("⏰ [VoiceService] Silence timeout reached, stopping...")
                                self.stopListening()
                                self.onAutoStopListening?()
                            }
                        }
                    }
                }
            }

            if let error = error {
                // Ignore cancellation errors (expected when we stop manually)
                let nsError = error as NSError
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                    print("ℹ️ [VoiceService] Recognition canceled (expected)")
                    return
                }

                print("❌ [VoiceService] Recognition error: \(error)")
                _Concurrency.Task { @MainActor in
                    self.stopListening()
                }
            }
        }

        isListening = true
        transcribedText = ""
        print("🎤 [VoiceService] Started listening...")
    }

    /// Stop listening
    func stopListening() {
        guard isListening else {
            print("⚠️ [VoiceService] Already stopped, skipping...")
            return
        }

        print("🛑 [VoiceService] Stopping listening...")

        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Remove tap safely
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }

        // End recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        print("✅ [VoiceService] Stopped listening. Transcribed text: \(transcribedText)")
    }

    // MARK: - Text-to-Speech (Voice Output) using OpenAI TTS

    /// Speak text aloud using OpenAI TTS
    func speak(_ text: String, voice: VoiceType = .natural) {
        // Stop any ongoing speech
        stopSpeaking()

        print("🔊 [VoiceService] Generating speech with OpenAI TTS...")
        isGeneratingAudio = true
        isSpeaking = false

        // Map voice type to OpenAI voice
        let openAIVoice: String
        switch voice {
        case .male:
            openAIVoice = "onyx" // Natural male voice
        case .natural:
            openAIVoice = "nova" // Natural female voice
        case .custom(let customVoice):
            openAIVoice = customVoice
        }

        // Call TTS API asynchronously
        _Concurrency.Task {
            do {
                let audioData = try await fetchTTSAudio(text: text, voice: openAIVoice)
                await MainActor.run {
                    self.isGeneratingAudio = false
                    self.isSpeaking = true
                }
                await playAudio(audioData)
            } catch {
                print("❌ [VoiceService] TTS error: \(error)")
                await MainActor.run {
                    self.isGeneratingAudio = false
                    self.isSpeaking = false
                    self.errorMessage = "Failed to generate speech: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Fetch audio from OpenAI TTS API
    private func fetchTTSAudio(text: String, voice: String) async throws -> Data {
        // Get auth token
        guard let authSession = try? await SupabaseManager.shared.client.auth.session else {
            throw VoiceError.notAuthenticated
        }

        let accessToken = authSession.accessToken

        // Build request
        let url = URL(string: "\(apiBaseURL)/api/ai/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "voice": voice
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Extended timeout for TTS generation
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let urlSession = URLSession(configuration: config)

        print("🌐 [VoiceService] Calling TTS API...")
        let (data, response) = try await urlSession.data(for: request)

        // Handle HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceError.audioGenerationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [VoiceService] TTS API error (\(httpResponse.statusCode)): \(errorText)")
            throw VoiceError.audioGenerationFailed
        }

        print("✅ [VoiceService] Received \(data.count) bytes of audio")
        return data
    }

    /// Play audio data using AVAudioPlayer
    private func playAudio(_ audioData: Data) async {
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create audio player
            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            await MainActor.run {
                self.audioPlayer = player
            }

            // Play audio
            print("🔊 [VoiceService] Playing audio...")

            // Notify that audio playback has started (so UI can show the message)
            await MainActor.run {
                self.onAudioPlaybackStarted?()
                self.onAudioPlaybackStarted = nil // Clear callback after use
            }

            player.play()

        } catch {
            print("❌ [VoiceService] Playback error: \(error)")
            await MainActor.run {
                self.isSpeaking = false
                self.isGeneratingAudio = false
                self.errorMessage = "Failed to play audio: \(error.localizedDescription)"
            }
        }
    }

    /// Stop speaking
    func stopSpeaking() {
        print("🛑 [VoiceService] Stopping speech...")
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        isSpeaking = false
        isGeneratingAudio = false
        onAudioPlaybackStarted = nil // Clear callback
        print("✅ [VoiceService] Speech stopped")
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ [VoiceService] Audio playback finished (success: \(flag))")
        _Concurrency.Task { @MainActor in
            self.isSpeaking = false
            self.isGeneratingAudio = false
            self.audioPlayer = nil
            print("✅ [VoiceService] isSpeaking and isGeneratingAudio set to false")
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ [VoiceService] Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        _Concurrency.Task { @MainActor in
            self.isSpeaking = false
            self.isGeneratingAudio = false
            self.audioPlayer = nil
            self.errorMessage = "Audio playback failed"
        }
    }
}

// MARK: - Voice Types

enum VoiceType {
    case natural // Premium quality voice (Zoe/Siri)
    case male // Male voice option
    case custom(String)
}

// MARK: - Errors

enum VoiceError: LocalizedError {
    case permissionDenied
    case recognitionFailed
    case audioEngineFailed
    case audioGenerationFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition permission denied"
        case .recognitionFailed:
            return "Failed to initialize speech recognition"
        case .audioEngineFailed:
            return "Failed to start audio engine"
        case .audioGenerationFailed:
            return "Failed to generate audio from text"
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        }
    }
}
