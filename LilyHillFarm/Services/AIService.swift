//
//  AIService.swift
//  LilyHillFarm
//
//  AI Chat service for communicating with the Vercel-hosted chat API
//

import Foundation
import Supabase
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class AIService: ObservableObject {
    private let supabaseManager: SupabaseManager

    // TODO: Configure this with your actual Vercel deployment URL
    // For development, this might be: "http://localhost:3000"
    // For production: "https://your-app.vercel.app" or custom domain
    private let apiBaseURL: String

    // Configuration
    private let maxImages = 4
    private let maxMessageLength = 2000

    init(supabaseManager: SupabaseManager, apiBaseURL: String? = nil) {
        self.supabaseManager = supabaseManager

        // Use provided URL or fall back to config
        if let apiBaseURL = apiBaseURL {
            self.apiBaseURL = apiBaseURL
        } else if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            self.apiBaseURL = envURL
        } else {
            // Use the same API URL as configured in SupabaseConfig
            self.apiBaseURL = SupabaseConfig.apiURL
            print("✅ [AIService] Using production API URL")
        }

        print("✅ [AIService] Initialized with API URL: \(self.apiBaseURL)")
    }

    // MARK: - Public API

    /// Send message to AI chat endpoint
    func sendMessage(
        messages: [ChatMessage],
        context: ChatContext,
        contextData: [String: AnyCodable]
    ) async throws -> ChatResponse {
        // Validate input
        guard let lastMessage = messages.last else {
            throw AIServiceError.emptyMessages
        }

        if lastMessage.content.count > maxMessageLength {
            throw AIServiceError.messageTooLong(maxMessageLength)
        }

        if let images = lastMessage.images, images.count > maxImages {
            throw AIServiceError.tooManyImages(maxImages)
        }

        // Get auth token from Supabase
        guard let client = supabaseManager.client else {
            throw AIServiceError.notAuthenticated
        }

        let authSession = try await client.auth.session
        let accessToken = authSession.accessToken

        // Build request
        let chatRequest = ChatRequest(
            messages: messages,
            context: context,
            contextData: contextData
        )

        // Make API call
        guard let url = URL(string: "\(apiBaseURL)/api/ai/chat") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Vercel Protection Bypass token as HTTP header (recommended approach)
        request.addValue("vYbWdAuGWZjvrA4CZaR1NAkC7Dr0pd56", forHTTPHeaderField: "x-vercel-protection-bypass")

        // Debug: Print all headers
        print("🔐 [AIService] Request headers:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key.lowercased().contains("bypass") || key.lowercased().contains("vercel") {
                print("   \(key): \(value)")
            }
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(chatRequest)

        // Extended timeout for AI responses (60 seconds)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90

        // Enable cookie storage for bypass token
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true

        let session = URLSession(configuration: config)

        print("📤 [AIService] Sending chat request to: \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        // Handle HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        print("📥 [AIService] Received response with status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("❌ [AIService] API error: \(errorResponse.error)")
                throw AIServiceError.apiError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.error
                )
            }

            // If no structured error, show raw response for debugging
            if let rawError = String(data: data, encoding: .utf8) {
                print("❌ [AIService] Raw error response: \(rawError)")
            }

            throw AIServiceError.httpError(httpResponse.statusCode)
        }

        // Parse response
        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)

        print("✅ [AIService] Successfully decoded chat response")
        return chatResponse
    }

    // MARK: - Image Helpers

    /// Convert UIImage to base64 ChatImage with aggressive compression
    func convertImageToBase64(image: UIImage, compressionQuality: CGFloat = 0.6) throws -> ChatImage {
        // Resize image to max dimension of 1024px to reduce payload size
        let resizedImage = resizeImage(image, maxDimension: 1024)

        guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw AIServiceError.imageConversionFailed
        }

        // Check if image is too large (max 1MB per image after compression)
        let maxSize = 1_000_000 // 1MB
        if imageData.count > maxSize {
            print("⚠️ [AIService] Image too large (\(imageData.count) bytes), compressing further...")
            // Try even more aggressive compression
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
                throw AIServiceError.imageConversionFailed
            }

            if compressedData.count > maxSize {
                throw AIServiceError.imageTooLarge(compressedData.count)
            }

            let base64String = compressedData.base64EncodedString()
            return ChatImage(
                source: ChatImage.ImageSource(
                    mediaType: "image/jpeg",
                    data: base64String
                )
            )
        }

        let base64String = imageData.base64EncodedString()

        return ChatImage(
            source: ChatImage.ImageSource(
                mediaType: "image/jpeg",
                data: base64String
            )
        )
    }

    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // If image is already smaller, return as-is
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
        }

        // Resize the image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }
}

// MARK: - Error Types

enum AIServiceError: LocalizedError {
    case emptyMessages
    case messageTooLong(Int)
    case tooManyImages(Int)
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(statusCode: Int, message: String)
    case imageConversionFailed
    case imageTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .emptyMessages:
            return "No messages to send"
        case .messageTooLong(let max):
            return "Message too long. Maximum \(max) characters."
        case .tooManyImages(let max):
            return "Too many images. Maximum \(max) images per message."
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .invalidURL:
            return "Invalid API URL configuration"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error (\(code))"
        case .apiError(let statusCode, let message):
            return "Error (\(statusCode)): \(message)"
        case .imageConversionFailed:
            return "Failed to convert image"
        case .imageTooLarge(let bytes):
            let mb = Double(bytes) / 1_000_000.0
            return String(format: "Image too large (%.1fMB). Please use a smaller image.", mb)
        }
    }
}

struct ErrorResponse: Decodable {
    let error: String
    let code: String?
}
