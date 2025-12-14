//
//  PastureLogDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Pasture Logs with Supabase
//

import Foundation
internal import CoreData

/// DTO for syncing pasture log data with Supabase
struct PastureLogDTO: Codable {
    let id: UUID
    let userId: UUID
    let pastureId: UUID
    let farmId: UUID?
    let logType: String
    let logDate: String
    let title: String
    let description: String?

    // Soil testing fields
    let soilPh: Double?
    let nitrogenLevel: String?
    let phosphorusLevel: String?
    let potassiumLevel: String?
    let testResults: String?
    let recommendations: String?

    // Maintenance fields
    let maintenanceType: String?
    let materialsUsed: String?
    let cost: Double?
    let laborHours: Double?
    let status: String?
    let completedDate: String?

    // Movement fields
    let animalsMovedIn: Int?
    let animalsMovedOut: Int?
    let stockingDensity: Double?

    // Hay cutting fields
    let hayCut: String?
    let cuttingDate: String?
    let bailingDate: String?
    let yieldPerAcre: Double?
    let totalYield: Double?
    let moistureContent: Double?
    let baleCount: Int?
    let baleWeight: Double?
    let qualityGrade: String?

    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pastureId = "pasture_id"
        case farmId = "farm_id"
        case logType = "log_type"
        case logDate = "log_date"
        case title
        case description
        case soilPh = "soil_ph"
        case nitrogenLevel = "nitrogen_level"
        case phosphorusLevel = "phosphorus_level"
        case potassiumLevel = "potassium_level"
        case testResults = "test_results"
        case recommendations
        case maintenanceType = "maintenance_type"
        case materialsUsed = "materials_used"
        case cost
        case laborHours = "labor_hours"
        case status
        case completedDate = "completed_date"
        case animalsMovedIn = "animals_moved_in"
        case animalsMovedOut = "animals_moved_out"
        case stockingDensity = "stocking_density"
        case hayCut = "hay_cut"
        case cuttingDate = "cutting_date"
        case bailingDate = "bailing_date"
        case yieldPerAcre = "yield_per_acre"
        case totalYield = "total_yield"
        case moistureContent = "moisture_content"
        case baleCount = "bale_count"
        case baleWeight = "bale_weight"
        case qualityGrade = "quality_grade"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Core Data Extensions

extension PastureLogDTO {
    /// Initialize DTO from Core Data entity
    init(from log: PastureLog, farmId: UUID) {
        self.id = log.id ?? UUID()
        self.userId = log.userId ?? UUID()
        self.pastureId = log.pastureId ?? UUID()
        self.farmId = farmId
        self.logType = log.logType ?? ""
        self.logDate = ISO8601DateFormatter().string(from: log.logDate ?? Date())
        self.title = log.title ?? ""
        self.description = log.logDescription

        // These fields may not exist in the Core Data model yet
        // TODO: Add these fields to the Core Data model if needed
        self.soilPh = nil
        self.nitrogenLevel = nil
        self.phosphorusLevel = nil
        self.potassiumLevel = nil
        self.testResults = nil
        self.recommendations = nil
        self.maintenanceType = nil
        self.materialsUsed = nil
        self.cost = nil
        self.laborHours = nil
        self.status = nil
        self.completedDate = nil
        self.animalsMovedIn = nil
        self.animalsMovedOut = nil
        self.stockingDensity = nil
        self.hayCut = nil
        self.cuttingDate = nil
        self.bailingDate = nil
        self.yieldPerAcre = nil
        self.totalYield = nil
        self.moistureContent = nil
        self.baleCount = nil
        self.baleWeight = nil
        self.qualityGrade = nil

        self.notes = log.notes
        self.createdAt = log.createdAt != nil ? ISO8601DateFormatter().string(from: log.createdAt!) : nil
        self.updatedAt = log.updatedAt != nil ? ISO8601DateFormatter().string(from: log.updatedAt!) : nil
    }

    /// Update Core Data entity from DTO
    func update(_ log: PastureLog) {
        let formatter = ISO8601DateFormatter()

        log.id = self.id
        log.userId = self.userId
        log.pastureId = self.pastureId
        log.farmId = self.farmId
        log.logType = self.logType
        log.logDate = formatter.date(from: self.logDate)
        log.title = self.title
        log.logDescription = self.description

        // These fields may not exist in the Core Data model yet
        // TODO: Add field mapping when Core Data model is updated

        log.notes = self.notes
        log.createdAt = self.createdAt != nil ? formatter.date(from: self.createdAt!) : nil
        log.updatedAt = self.updatedAt != nil ? formatter.date(from: self.updatedAt!) : nil
    }
}
