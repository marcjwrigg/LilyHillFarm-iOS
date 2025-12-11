//
//  DateHelpers.swift
//  LilyHillFarm
//
//  Shared date conversion helpers for DTOs
//

import Foundation

// MARK: - Date Conversion Helpers

extension Date {
    /// Convert Date to ISO8601 string format for Supabase
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

extension String {
    /// Convert ISO8601 string to Date
    func toDate() -> Date? {
        // Try with fractional seconds first
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

        // Try just date (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = dateFormatter.date(from: self) {
            return date
        }

        // Log parsing failures for debugging
        print("⚠️ Failed to parse date string: \(self)")
        return nil
    }
}
