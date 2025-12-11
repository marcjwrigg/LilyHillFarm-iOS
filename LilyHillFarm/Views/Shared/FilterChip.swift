//
//  FilterChip.swift
//  LilyHillFarm
//
//  Reusable filter chip component
//

import SwiftUI

// MARK: - Standard Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var style: ChipStyle = .primary

    enum ChipStyle {
        case primary, secondary
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                    (style == .primary ? Color.primary : Color.secondary) :
                    Color(red: 0.9, green: 0.9, blue: 0.9)
                )
                .foregroundColor(isSelected ? Color.white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Filter Chip

struct CompactFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    isSelected ? Color.primary : Color(red: 0.9, green: 0.9, blue: 0.9)
                )
                .foregroundColor(isSelected ? Color.white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
