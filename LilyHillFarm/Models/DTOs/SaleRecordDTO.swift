//
//  SaleRecordDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Sale Records with Supabase
//

import Foundation

/// DTO for syncing sale record data with Supabase
struct SaleRecordDTO: Codable {
    let id: UUID
    let cattleId: UUID
    let buyerId: UUID?  // FK to contacts table
    let saleDate: String?
    let salePrice: Double?
    let saleWeight: Double?
    let pricePerPound: Double?
    let quickbooksInvoiceId: String?
    let notes: String?
    let deletedAt: String?  // For soft delete sync
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cattleId = "cattle_id"
        case buyerId = "buyer_id"
        case saleDate = "sale_date"
        case salePrice = "sale_price"
        case saleWeight = "sale_weight"
        case pricePerPound = "price_per_pound"
        case quickbooksInvoiceId = "quickbooks_invoice_id"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

extension SaleRecordDTO {
    /// Create DTO from Core Data SaleRecord entity
    init(from record: SaleRecord) {
        self.id = record.id ?? UUID()
        self.cattleId = record.cattle?.id ?? UUID()
        self.buyerId = nil  // TODO: iOS stores buyer as String, DB uses buyer_id UUID FK - not currently synced
        self.saleDate = record.saleDate?.toISO8601String()
        self.salePrice = record.salePrice?.doubleValue
        self.saleWeight = record.saleWeight?.doubleValue
        self.pricePerPound = record.pricePerPound?.doubleValue
        self.quickbooksInvoiceId = nil  // Not stored in iOS Core Data
        self.notes = record.notes
        self.deletedAt = record.deletedAt?.toISO8601String()
        self.createdAt = record.createdAt?.toISO8601String()
        // Note: iOS Core Data fields not synced: buyer (String), buyerContact, paymentMethod, marketType
    }

    /// Update Core Data entity from DTO
    func update(_ record: SaleRecord) {
        record.id = self.id
        // cattle relationship handled separately
        record.saleDate = self.saleDate?.toDate()
        // buyer/buyerContact not synced from DB (would need Contact lookup)
        record.salePrice = self.salePrice.map { NSDecimalNumber(value: $0) }
        record.saleWeight = self.saleWeight.map { NSDecimalNumber(value: $0) }
        record.pricePerPound = self.pricePerPound.map { NSDecimalNumber(value: $0) }
        // paymentMethod/marketType not in DB
        record.notes = self.notes
        record.deletedAt = self.deletedAt?.toDate()
        record.createdAt = self.createdAt?.toDate()
    }
}
