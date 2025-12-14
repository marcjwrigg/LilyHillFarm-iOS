//
//  BuyerDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Buyers with Supabase
//

import Foundation

/// DTO for syncing buyer data with Supabase
struct BuyerDTO: Codable {
    let id: UUID
    let name: String
    let type: String?
    let contactName: String?
    let phone: String?
    let email: String?
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let notes: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case contactName = "contact_name"
        case phone
        case email
        case address
        case city
        case state
        case zipCode = "zip_code"
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
