//
//  ContactRepository.swift
//  LilyHillFarm
//
//  Repository for syncing Contacts with Supabase
//

import Foundation
@preconcurrency internal import CoreData
import Supabase

class ContactRepository: BaseSyncManager {

    // MARK: - Fetch from Supabase

    /// Fetch all contacts for current user from Supabase
    func fetchAll() async throws -> [ContactDTO] {
        try requireAuth()

        let farmId = try await getFarmId()

        let contacts: [ContactDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.contacts)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .order("name", ascending: true)
            .execute()
            .value

        return contacts
    }

    /// Fetch contact by ID
    func fetchById(_ id: UUID) async throws -> ContactDTO? {
        try requireAuth()

        let contacts: [ContactDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.contacts)
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value

        return contacts.first
    }

    /// Fetch contacts by type
    func fetchByType(_ type: String) async throws -> [ContactDTO] {
        try requireAuth()

        let farmId = try await getFarmId()

        let contacts: [ContactDTO] = try await supabase.client
            .from(SupabaseConfig.Tables.contacts)
            .select()
            .eq("farm_id", value: farmId.uuidString)
            .eq("type", value: type)
            .order("name", ascending: true)
            .execute()
            .value

        return contacts
    }

    // MARK: - Create/Update/Delete

    /// Create new contact in Supabase
    func create(_ contact: Contact) async throws -> ContactDTO {
        try requireAuth()

        let farmId = try await getFarmId()

        let dto = ContactDTO(from: contact, farmId: farmId)

        let created: ContactDTO = try await supabase.client
            .from(SupabaseConfig.Tables.contacts)
            .insert(dto)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    /// Update existing contact in Supabase
    func update(_ contact: Contact) async throws -> ContactDTO {
        try requireAuth()

        guard let id = contact.id else {
            throw RepositoryError.invalidData
        }

        let farmId = try await getFarmId()

        let dto = ContactDTO(from: contact, farmId: farmId)

        let updated: ContactDTO = try await supabase.client
            .from(SupabaseConfig.Tables.contacts)
            .update(dto)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return updated
    }

    /// Delete contact from Supabase
    func delete(_ id: UUID) async throws {
        try requireAuth()

        try await supabase.client
            .from(SupabaseConfig.Tables.contacts)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Sync

    /// Sync all contacts with related data: fetch from Supabase and update Core Data
    func syncFromSupabase() async throws {
        try requireAuth()

        print("🔄 Fetching contacts from Supabase...")
        var contactDTOs = try await fetchAll()
        print("✅ Fetched \(contactDTOs.count) contacts from Supabase")

        // Fetch related data for all contacts
        print("🔄 Fetching related contact data...")
        for i in 0..<contactDTOs.count {
            let contactId = contactDTOs[i].id

            // Fetch phone numbers
            let phoneNumbers = try await fetchPhoneNumbers(for: contactId)
            contactDTOs[i].phoneNumbers = phoneNumbers

            // Fetch emails
            let emails = try await fetchEmails(for: contactId)
            contactDTOs[i].emails = emails

            // Fetch contact persons (if business)
            if contactDTOs[i].isBusiness {
                let persons = try await fetchContactPersons(for: contactId)
                contactDTOs[i].contactPersons = persons
            }
        }
        print("✅ Fetched all related contact data")

        try await context.perform { [weak self] in
            guard let self = self else { return }

            print("🔄 Syncing \(contactDTOs.count) contacts to Core Data...")

            for dto in contactDTOs {
                // Try to find existing contact
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)

                let results = try self.context.fetch(fetchRequest)

                let contact: Contact
                if let existing = results.first {
                    contact = existing
                } else {
                    contact = Contact(context: self.context)
                }

                // Update contact from DTO
                dto.update(contact)

                // Sync phone numbers
                if let phoneNumberDTOs = dto.phoneNumbers {
                    self.syncPhoneNumbers(phoneNumberDTOs, for: contact)
                }

                // Sync emails
                if let emailDTOs = dto.emails {
                    self.syncEmails(emailDTOs, for: contact)
                }

                // Sync contact persons
                if let personDTOs = dto.contactPersons {
                    self.syncContactPersons(personDTOs, for: contact)
                }
            }

            print("💾 Saving contacts to Core Data...")
            try self.saveContext()
            print("✅ Contacts sync completed!")
        }
    }

    // MARK: - Fetch Related Data

    private func fetchPhoneNumbers(for contactId: UUID) async throws -> [ContactPhoneNumberDTO] {
        let data = try await supabase.client
            .from("contact_phone_numbers")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .execute()
            .data

        return try JSONDecoder().decode([ContactPhoneNumberDTO].self, from: data)
    }

    private func fetchEmails(for contactId: UUID) async throws -> [ContactEmailDTO] {
        let data = try await supabase.client
            .from("contact_emails")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .execute()
            .data

        return try JSONDecoder().decode([ContactEmailDTO].self, from: data)
    }

    private func fetchContactPersons(for contactId: UUID) async throws -> [ContactPersonDTO] {
        let data = try await supabase.client
            .from("contact_persons")
            .select()
            .eq("business_contact_id", value: contactId.uuidString)
            .execute()
            .data

        return try JSONDecoder().decode([ContactPersonDTO].self, from: data)
    }

    // MARK: - Sync Related Entities

    private func syncPhoneNumbers(_ dtos: [ContactPhoneNumberDTO], for contact: Contact) {
        // Get existing phone numbers
        let existingPhoneNumbers = (contact.phoneNumbers as? Set<ContactPhoneNumber>) ?? []
        let existingIds = Set(existingPhoneNumbers.compactMap { $0.id })
        let dtoIds = Set(dtos.map { $0.id })

        // Remove phone numbers that no longer exist
        for phoneNumber in existingPhoneNumbers where !dtoIds.contains(phoneNumber.id!) {
            context.delete(phoneNumber)
        }

        // Add or update phone numbers
        for dto in dtos {
            let phoneNumber: ContactPhoneNumber
            if let existing = existingPhoneNumbers.first(where: { $0.id == dto.id }) {
                phoneNumber = existing
            } else {
                phoneNumber = ContactPhoneNumber(context: context)
                phoneNumber.contact = contact
            }
            dto.update(phoneNumber)
        }
    }

    private func syncEmails(_ dtos: [ContactEmailDTO], for contact: Contact) {
        // Get existing emails
        let existingEmails = (contact.emails as? Set<ContactEmail>) ?? []
        let existingIds = Set(existingEmails.compactMap { $0.id })
        let dtoIds = Set(dtos.map { $0.id })

        // Remove emails that no longer exist
        for email in existingEmails where !dtoIds.contains(email.id!) {
            context.delete(email)
        }

        // Add or update emails
        for dto in dtos {
            let email: ContactEmail
            if let existing = existingEmails.first(where: { $0.id == dto.id }) {
                email = existing
            } else {
                email = ContactEmail(context: context)
                email.contact = contact
            }
            dto.update(email)
        }
    }

    private func syncContactPersons(_ dtos: [ContactPersonDTO], for contact: Contact) {
        // Get existing contact persons
        let existingPersons = (contact.contactPersons as? Set<ContactPerson>) ?? []
        let existingIds = Set(existingPersons.compactMap { $0.id })
        let dtoIds = Set(dtos.map { $0.id })

        // Remove persons that no longer exist
        for person in existingPersons where !dtoIds.contains(person.id!) {
            context.delete(person)
        }

        // Add or update persons
        for dto in dtos {
            let person: ContactPerson
            if let existing = existingPersons.first(where: { $0.id == dto.id }) {
                person = existing
            } else {
                person = ContactPerson(context: context)
                person.businessContact = contact
            }
            dto.update(person)
        }
    }

    /// Push local contact to Supabase
    func pushToSupabase(_ contact: Contact) async throws {
        try requireAuth()

        if let id = contact.id {
            // Try to fetch existing
            let existingContact = try await context.perform {
                let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                return try self.context.fetch(fetchRequest).first
            }

            if existingContact != nil {
                _ = try await update(contact)
            } else {
                _ = try await create(contact)
            }
        } else {
            _ = try await create(contact)
        }
    }
}
