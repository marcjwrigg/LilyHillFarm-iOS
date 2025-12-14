//
//  DateHelpers.swift
//  LilyHillFarm
//
//  Shared date conversion helpers for DTOs
//

import Foundation

// MARK: - Date Conversion Helpers

extension Date {
    /// Convert Date to ISO8601 string format for Supabase (full timestamp with timezone)
    /// Use this for datetime fields that need time precision
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }

    /// Convert Date to date-only string (YYYY-MM-DD) for Supabase
    /// Use this for date-only fields (breeding_date, calving_date, etc.) to avoid timezone shifts
    func toDateOnlyString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: self)
    }
}

extension String {
    /// Convert ISO8601 string or date-only string to Date
    func toDate() -> Date? {
        // Check if this is a date-only string (YYYY-MM-DD) without time component
        if self.count == 10 && self.contains("-") && !self.contains("T") && !self.contains(":") {
            // Parse as date-only at midnight UTC to avoid timezone shifts
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            if let date = dateFormatter.date(from: self) {
                return date
            }
        }

        // Try with fractional seconds first (full timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date
        }

        // Try without fractional seconds (common Supabase format)
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: self) {
            return date
        }

        // Try with date and time but no timezone (another common format)
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        if let date = formatter.date(from: self) {
            return date
        }

        // Log parsing failures for debugging
        print("⚠️ Failed to parse date string: \(self)")
        return nil
    }
}
