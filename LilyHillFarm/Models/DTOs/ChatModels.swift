import Foundation

// MARK: - Request Models (Minimal - Server validates)

struct ChatRequest: Encodable {
    let messages: [ChatMessage]
    let context: ChatContext
    let contextData: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case messages, context
        case contextData = "contextData"
    }
}

struct ChatMessage: Codable {
    let role: MessageRole
    let content: String
    let images: [ChatImage]?

    enum MessageRole: String, Codable {
        case user
        case assistant
    }
}

struct ChatImage: Codable {
    let type = "image"
    let source: ImageSource

    struct ImageSource: Codable {
        let type = "base64"
        let mediaType: String  // "image/jpeg", "image/png", etc.
        let data: String       // Base64 encoded image

        enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
    }
}

enum ChatContext: String, Codable {
    case project
    case health
    case general
}

// MARK: - Response Models (Flexible - Display only)

struct ChatResponse: Decodable {
    let type: ResponseType
    let content: String?
    let message: String?
    let suggestion: ChatSuggestion?

    enum ResponseType: String, Decodable {
        case message
        case suggestion
    }
}

struct ChatSuggestion: Decodable {
    let context: ChatContext
    let data: [String: AnyCodable]  // Flexible structure - server defines shape
}

// MARK: - Context Data Builders
// Note: AnyCodable is defined in BaseRepository.swift

extension ChatRequest {
    /// Build general context data
    static func generalContextData(farmId: String) -> [String: AnyCodable] {
        return [
            "farmId": AnyCodable(farmId),
            "assistantName": AnyCodable("Marc"),
            "mode": AnyCodable("general")
        ]
    }

    /// Build project context data
    static func projectContextData(
        farmId: String,
        projectId: String,
        projectName: String,
        projectType: String? = nil,
        description: String? = nil,
        estimatedBudget: Double? = nil,
        actualBudget: Double? = nil,
        startDate: String? = nil,
        targetEndDate: String? = nil,
        currentTasks: [[String: Any]] = [],
        currentMilestones: [[String: Any]] = []
    ) -> [String: AnyCodable] {
        var data: [String: AnyCodable] = [
            "farmId": AnyCodable(farmId),
            "projectId": AnyCodable(projectId),
            "projectName": AnyCodable(projectName),
            "currentTasks": AnyCodable(currentTasks),
            "currentMilestones": AnyCodable(currentMilestones)
        ]

        if let projectType = projectType { data["projectType"] = AnyCodable(projectType) }
        if let description = description { data["description"] = AnyCodable(description) }
        if let estimatedBudget = estimatedBudget { data["estimatedBudget"] = AnyCodable(estimatedBudget) }
        if let actualBudget = actualBudget { data["actualBudget"] = AnyCodable(actualBudget) }
        if let startDate = startDate { data["startDate"] = AnyCodable(startDate) }
        if let targetEndDate = targetEndDate { data["targetEndDate"] = AnyCodable(targetEndDate) }

        return data
    }

    /// Build health context data
    static func healthContextData(
        farmId: String,
        cattleId: String,
        cattleTag: String,
        cattleName: String? = nil,
        sex: String,
        age: String,
        breed: String? = nil,
        currentWeight: Double? = nil,
        currentStatus: String,
        recentHealthRecords: [[String: Any]] = []
    ) -> [String: AnyCodable] {
        var data: [String: AnyCodable] = [
            "farmId": AnyCodable(farmId),
            "cattleId": AnyCodable(cattleId),
            "cattleTag": AnyCodable(cattleTag),
            "sex": AnyCodable(sex),
            "age": AnyCodable(age),
            "currentStatus": AnyCodable(currentStatus),
            "recentHealthRecords": AnyCodable(recentHealthRecords)
        ]

        if let cattleName = cattleName { data["cattleName"] = AnyCodable(cattleName) }
        if let breed = breed { data["breed"] = AnyCodable(breed) }
        if let currentWeight = currentWeight { data["currentWeight"] = AnyCodable(currentWeight) }

        return data
    }
}
