//
//  BreedingBenchmarks.swift
//  LilyHillFarm
//
//  Created by Claude on 12/12/25.
//

import SwiftUI

/// Breeding performance benchmarks based on industry standards
struct BenchmarkResult {
    let label: String
    let color: Color
    let description: String
}

enum BreedingBenchmarks {
    /// Get benchmark status for average days post partum (calving to pregnancy)
    ///
    /// Industry targets:
    /// - Excellent (Top 10%): ≤ 80 days
    /// - Good: 81-90 days
    /// - Fair: 91-100 days
    /// - Needs Attention: > 100 days
    static func getDaysPostPartumBenchmark(days: Int) -> BenchmarkResult {
        if days <= 80 {
            return BenchmarkResult(
                label: "Excellent",
                color: .green,
                description: "Top 10% - Outstanding breeding efficiency"
            )
        } else if days <= 90 {
            return BenchmarkResult(
                label: "Good",
                color: .blue,
                description: "Meeting industry targets"
            )
        } else if days <= 100 {
            return BenchmarkResult(
                label: "Fair",
                color: .orange,
                description: "Room for improvement"
            )
        } else {
            return BenchmarkResult(
                label: "Needs Attention",
                color: .red,
                description: "Below industry standards"
            )
        }
    }

    /// Get benchmark status for average days between calving (calving interval)
    ///
    /// Industry targets:
    /// - Excellent (Top 10%): ≤ 360 days
    /// - Good: 361-365 days
    /// - Fair: 366-380 days
    /// - Needs Attention: > 380 days
    static func getDaysBetweenCalvingBenchmark(days: Int) -> BenchmarkResult {
        if days <= 360 {
            return BenchmarkResult(
                label: "Excellent",
                color: .green,
                description: "Top 10% - Elite calving interval"
            )
        } else if days <= 365 {
            return BenchmarkResult(
                label: "Good",
                color: .blue,
                description: "Meeting the gold standard (365 days)"
            )
        } else if days <= 380 {
            return BenchmarkResult(
                label: "Fair",
                color: .orange,
                description: "Above target - consider management adjustments"
            )
        } else {
            return BenchmarkResult(
                label: "Needs Attention",
                color: .red,
                description: "Significantly above target interval"
            )
        }
    }
}
