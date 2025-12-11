//
//  BreedDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Breeds with Supabase
//

import Foundation

/// DTO for syncing breed reference data with Supabase
struct BreedDTO: Codable {
    let id: UUID
    let name: String
    let category: String?
    let characteristics: String?
    let isActive: Bool?
    let deletedAt: String?  // For soft delete sync

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case characteristics
        case isActive = "is_active"
        case deletedAt = "deleted_at"
    }
}

extension BreedDTO {
    /// Create DTO from Core Data Breed entity
    init(from breed: Breed) {
        self.id = breed.id ?? UUID()
        self.name = breed.name ?? ""
        self.category = breed.category ?? "Beef"
        self.characteristics = breed.characteristics
        self.isActive = breed.isActive
        self.deletedAt = breed.deletedAt?.toISO8601String()
    }

    /// Update Core Data entity from DTO
    func update(_ breed: Breed) {
        breed.id = self.id
        breed.name = self.name
        breed.category = self.category ?? "Beef"  // Default to Beef if category not set
        breed.characteristics = self.characteristics
        breed.isActive = self.isActive ?? true  // Default to active if not set
        breed.deletedAt = self.deletedAt?.toDate()
    }
}
