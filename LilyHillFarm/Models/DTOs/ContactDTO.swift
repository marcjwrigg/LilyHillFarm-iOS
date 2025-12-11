//
//  ContactDTO.swift
//  LilyHillFarm
//
//  Data Transfer Object for syncing Contacts with Supabase
//

import Foundation

/// DTO for syncing contact data with Supabase
struct ContactDTO: Codable {
    let id: UUID
    let farmId: UUID
    let name: String
    let type: String
    let company: String?
    let isBusiness: Bool

    // Legacy fields (deprecated but kept for compatibility)
    let phone: String?
    let email: String?
    let address: String?

    // New address fields
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let country: String?

    // Business fields
    let website: String?
    let taxId: String?
    let paymentTerms: String?

    // Contact preferences
    let status: String
    let preferredContactMethod: String?

    let notes: String?
    let deletedAt: String?
    let createdAt: String
    let updatedAt: String

    // Related data (fetched separately but included for convenience)
    var phoneNumbers: [ContactPhoneNumberDTO]?
    var emails: [ContactEmailDTO]?
    var contactPersons: [ContactPersonDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case farmId = "farm_id"
        case name
        case type
        case company
        case isBusiness = "is_business"
        case phone
        case email
        case address
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case city
        case state
        case zipCode = "zip_code"
        case country
        case website
        case taxId = "tax_id"
        case paymentTerms = "payment_terms"
        case status
        case preferredContactMethod = "preferred_contact_method"
        case notes
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case phoneNumbers = "phone_numbers"
        case emails
        case contactPersons = "contact_persons"
    }
}

/// DTO for contact phone numbers
struct ContactPhoneNumberDTO: Codable {
    let id: UUID
    let contactId: UUID
    let phoneNumber: String
    let phoneType: String
    let isPrimary: Bool
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case phoneNumber = "phone_number"
        case phoneType = "phone_type"
        case isPrimary = "is_primary"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// DTO for contact emails
struct ContactEmailDTO: Codable {
    let id: UUID
    let contactId: UUID
    let email: String
    let emailType: String
    let isPrimary: Bool
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case email
        case emailType = "email_type"
        case isPrimary = "is_primary"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// DTO for contact persons (people at business contacts)
struct ContactPersonDTO: Codable {
    let id: UUID
    let businessContactId: UUID
    let name: String
    let title: String?
    let email: String?
    let phone: String?
    let isPrimary: Bool
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case businessContactId = "business_contact_id"
        case name
        case title
        case email
        case phone
        case isPrimary = "is_primary"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Core Data Conversion

extension ContactDTO {
    /// Initialize from Core Data Contact entity
    init(from contact: Contact, farmId: UUID) {
        self.id = contact.id ?? UUID()
        self.farmId = farmId
        self.name = contact.name ?? ""
        self.type = contact.contactType ?? ""
        self.company = contact.company
        self.isBusiness = contact.isBusiness

        // Legacy fields
        self.phone = contact.phone
        self.email = contact.email
        self.address = contact.address

        // New address fields
        self.addressLine1 = contact.addressLine1
        self.addressLine2 = contact.addressLine2
        self.city = contact.city
        self.state = contact.state
        self.zipCode = contact.zipCode
        self.country = contact.country

        // Business fields
        self.website = contact.website
        self.taxId = contact.taxId
        self.paymentTerms = contact.paymentTerms

        // Contact preferences
        self.status = contact.status ?? "Active"
        self.preferredContactMethod = contact.preferredContactMethod

        self.notes = contact.notes
        self.deletedAt = contact.deletedAt?.toISO8601String()
        self.createdAt = (contact.createdAt ?? Date()).toISO8601String()
        self.updatedAt = (contact.modifiedAt ?? Date()).toISO8601String()

        // Related entities (not included in init, added during sync)
        self.phoneNumbers = nil
        self.emails = nil
        self.contactPersons = nil
    }

    /// Update Core Data Contact entity from DTO
    func update(_ contact: Contact) {
        contact.id = self.id
        contact.farmId = self.farmId
        contact.name = self.name
        contact.contactType = self.type
        contact.company = self.company
        contact.isBusiness = self.isBusiness

        // Legacy fields
        contact.phone = self.phone
        contact.email = self.email
        contact.address = self.address

        // New address fields
        contact.addressLine1 = self.addressLine1
        contact.addressLine2 = self.addressLine2
        contact.city = self.city
        contact.state = self.state
        contact.zipCode = self.zipCode
        contact.country = self.country

        // Business fields
        contact.website = self.website
        contact.taxId = self.taxId
        contact.paymentTerms = self.paymentTerms

        // Contact preferences
        contact.status = self.status
        contact.preferredContactMethod = self.preferredContactMethod

        contact.notes = self.notes
        contact.deletedAt = self.deletedAt?.toDate()
        contact.createdAt = self.createdAt.toDate()
        contact.modifiedAt = self.updatedAt.toDate()

        // Related entities handled separately by repository
    }
}

// MARK: - ContactPhoneNumber Conversion

extension ContactPhoneNumberDTO {
    /// Update Core Data ContactPhoneNumber entity from DTO
    func update(_ phoneNumber: ContactPhoneNumber) {
        phoneNumber.id = self.id
        phoneNumber.phoneNumber = self.phoneNumber
        phoneNumber.phoneType = self.phoneType
        phoneNumber.isPrimary = self.isPrimary
        phoneNumber.notes = self.notes
        phoneNumber.createdAt = self.createdAt.toDate()
        phoneNumber.updatedAt = self.updatedAt.toDate()
    }
}

// MARK: - ContactEmail Conversion

extension ContactEmailDTO {
    /// Update Core Data ContactEmail entity from DTO
    func update(_ emailEntity: ContactEmail) {
        emailEntity.id = self.id
        emailEntity.email = self.email
        emailEntity.emailType = self.emailType
        emailEntity.isPrimary = self.isPrimary
        emailEntity.notes = self.notes
        emailEntity.createdAt = self.createdAt.toDate()
        emailEntity.updatedAt = self.updatedAt.toDate()
    }
}

// MARK: - ContactPerson Conversion

extension ContactPersonDTO {
    /// Update Core Data ContactPerson entity from DTO
    func update(_ person: ContactPerson) {
        person.id = self.id
        person.name = self.name
        person.title = self.title
        person.email = self.email
        person.phone = self.phone
        person.isPrimary = self.isPrimary
        person.notes = self.notes
        person.createdAt = self.createdAt.toDate()
        person.updatedAt = self.updatedAt.toDate()
    }
}

