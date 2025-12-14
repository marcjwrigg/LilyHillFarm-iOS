//
//  ProcessorDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Processors with Supabase
//

import Foundation

/// DTO for syncing processor data with Supabase
struct ProcessorDTO: Codable {
    let id: UUID
    let farmId: UUID
    let name: String
    let location: String?
    let phone: String?
    let email: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case name
        case location
        case phone
        case email
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
