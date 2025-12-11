//
//  Contact+Extensions.swift
//  LilyHillFarm
//
//  Extensions for Contact entity
//

import Foundation
@preconcurrency internal import CoreData

extension Contact {

    // MARK: - Display Helpers

    /// Primary phone number (marked as primary or first in list)
    var primaryPhone: ContactPhoneNumber? {
        let phoneArray = (phoneNumbers as? Set<ContactPhoneNumber>)?.sorted {
            if $0.isPrimary != $1.isPrimary {
                return $0.isPrimary && !$1.isPrimary
            }
            return ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        }
        return phoneArray?.first
    }

    /// All phone numbers sorted (primary first, then by creation date)
    var sortedPhoneNumbers: [ContactPhoneNumber] {
        (phoneNumbers as? Set<ContactPhoneNumber>)?.sorted {
            if $0.isPrimary != $1.isPrimary {
                return $0.isPrimary && !$1.isPrimary
            }
            return ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        } ?? []
    }

    /// Primary email (marked as primary or first in list)
    var primaryEmail: ContactEmail? {
        let emailArray = (emails as? Set<ContactEmail>)?.sorted {
            if $0.isPrimary != $1.isPrimary {
                return $0.isPrimary && !$1.isPrimary
            }
            return ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        }
        return emailArray?.first
    }

    /// All emails sorted (primary first, then by creation date)
    var sortedEmails: [ContactEmail] {
        (emails as? Set<ContactEmail>)?.sorted {
            if $0.isPrimary != $1.isPrimary {
                return $0.isPrimary && !$1.isPrimary
            }
            return ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        } ?? []
    }

    /// Primary contact person (for business contacts)
    var primaryContactPerson: ContactPerson? {
        let personArray = (contactPersons as? Set<ContactPerson>)?.sorted {
            if $0.isPrimary != $1.isPrimary {
                return $0.isPrimary && !$1.isPrimary
            }
            return ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        }
        return personArray?.first
    }

    /// All contact persons sorted (primary first, then by creation date)
    var sortedContactPersons: [ContactPerson] {
        (contactPersons as? Set<ContactPerson>)?.sorted {
            if $0.isPrimary != $1.isPrimary {
                return $0.isPrimary && !$1.isPrimary
            }
            return ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        } ?? []
    }

    /// Display name (uses name or company if available)
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let company = company, !company.isEmpty {
            return company
        }
        return "Unknown Contact"
    }

    /// Full address as single string
    var fullAddress: String? {
        var components: [String] = []

        if let line1 = addressLine1, !line1.isEmpty {
            components.append(line1)
        }
        if let line2 = addressLine2, !line2.isEmpty {
            components.append(line2)
        }

        var cityStateZip: [String] = []
        if let city = city, !city.isEmpty {
            cityStateZip.append(city)
        }
        if let state = state, !state.isEmpty {
            cityStateZip.append(state)
        }
        if let zip = zipCode, !zip.isEmpty {
            cityStateZip.append(zip)
        }

        if !cityStateZip.isEmpty {
            components.append(cityStateZip.joined(separator: ", "))
        }

        if let country = country, !country.isEmpty, country.lowercased() != "usa" && country.lowercased() != "us" {
            components.append(country)
        }

        return components.isEmpty ? nil : components.joined(separator: "\n")
    }

    /// Is this contact active?
    var isActive: Bool {
        status?.lowercased() == "active"
    }
}
