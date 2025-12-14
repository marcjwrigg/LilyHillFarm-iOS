//
//  VeterinarianDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Veterinarians with Supabase
//

import Foundation

/// DTO for syncing veterinarian data with Supabase
struct VeterinarianDTO: Codable {
    let id: UUID
    let farmId: UUID
    let name: String
    let clinicName: String?
    let phone: String?
    let email: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case name
        case clinicName = "clinic_name"
        case phone
        case email
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
