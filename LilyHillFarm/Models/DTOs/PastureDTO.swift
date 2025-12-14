//
//  PastureDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Pastures with Supabase
//

import Foundation

// Helper for decoding heterogeneous JSON
private struct JSONValue: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let dict = try? container.decode([String: JSONValue].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([JSONValue].self) {
            value = array.map { $0.value }
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        // Not needed for our use case
        throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Encoding not supported"))
    }
}

/// DTO for syncing pasture data with Supabase
struct PastureDTO: Codable {
    let id: UUID
    let userId: UUID
    let farmId: UUID
    let name: String
    let pastureType: String
    let acreage: Double?
    let fencingType: String?
    let waterSource: String?
    let carryingCapacity: Int?
    let currentOccupancy: Int?
    let condition: String
    let lastGrazedDate: String?
    let restPeriodDays: Int?
    let forageType: String?
    let forageAcres: Double?
    let notes: String?
    let boundaryCoordinates: String?  // JSON as string
    let forageBoundaryCoordinates: String?  // JSON as string
    let centerLat: Double?
    let centerLng: Double?
    let mapZoomLevel: Int?
    let deletedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case farmId = "farm_id"
        case name
        case pastureType = "pasture_type"
        case acreage
        case fencingType = "fencing_type"
        case waterSource = "water_source"
        case carryingCapacity = "carrying_capacity"
        case currentOccupancy = "current_occupancy"
        case condition
        case lastGrazedDate = "last_grazed_date"
        case restPeriodDays = "rest_period_days"
        case forageType = "forage_type"
        case forageAcres = "forage_acres"
        case notes
        case boundaryCoordinates = "boundary_coordinates"
        case forageBoundaryCoordinates = "forage_boundary_coordinates"
        case centerLat = "center_lat"
        case centerLng = "center_lng"
        case mapZoomLevel = "map_zoom_level"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Custom decoder to handle boundary_coordinates as either String or Dictionary
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        farmId = try container.decode(UUID.self, forKey: .farmId)
        name = try container.decode(String.self, forKey: .name)
        pastureType = try container.decode(String.self, forKey: .pastureType)
        acreage = try container.decodeIfPresent(Double.self, forKey: .acreage)
        fencingType = try container.decodeIfPresent(String.self, forKey: .fencingType)
        waterSource = try container.decodeIfPresent(String.self, forKey: .waterSource)
        carryingCapacity = try container.decodeIfPresent(Int.self, forKey: .carryingCapacity)
        currentOccupancy = try container.decodeIfPresent(Int.self, forKey: .currentOccupancy)
        condition = try container.decode(String.self, forKey: .condition)
        lastGrazedDate = try container.decodeIfPresent(String.self, forKey: .lastGrazedDate)
        restPeriodDays = try container.decodeIfPresent(Int.self, forKey: .restPeriodDays)
        forageType = try container.decodeIfPresent(String.self, forKey: .forageType)
        forageAcres = try container.decodeIfPresent(Double.self, forKey: .forageAcres)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        centerLat = try container.decodeIfPresent(Double.self, forKey: .centerLat)
        centerLng = try container.decodeIfPresent(Double.self, forKey: .centerLng)
        mapZoomLevel = try container.decodeIfPresent(Int.self, forKey: .mapZoomLevel)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle boundary_coordinates - can be String or Dictionary (GeoJSON object from JSONB)
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .boundaryCoordinates) {
            boundaryCoordinates = stringValue
        } else if let jsonValue = try? container.decodeIfPresent(JSONValue.self, forKey: .boundaryCoordinates) {
            // Convert to JSON string
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonValue.value),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                boundaryCoordinates = jsonString
            } else {
                boundaryCoordinates = nil
            }
        } else {
            boundaryCoordinates = nil
        }

        // Handle forage_boundary_coordinates - can be String or Dictionary (GeoJSON object from JSONB)
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .forageBoundaryCoordinates) {
            forageBoundaryCoordinates = stringValue
        } else if let jsonValue = try? container.decodeIfPresent(JSONValue.self, forKey: .forageBoundaryCoordinates) {
            // Convert to JSON string
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonValue.value),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                forageBoundaryCoordinates = jsonString
            } else {
                forageBoundaryCoordinates = nil
            }
        } else {
            forageBoundaryCoordinates = nil
        }
    }
}
