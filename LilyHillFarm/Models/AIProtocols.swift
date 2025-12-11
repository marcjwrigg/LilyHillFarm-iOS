//
//  AIProtocols.swift
//  LilyHillFarm
//
//  AI Synchronization Protocols for Cattle Breeding
//

import Foundation

struct ProtocolStep {
    let day: Int
    let title: String
    let description: String
    let actions: [String]
    let notes: String?
}

struct AIProtocol {
    let id: String
    let name: String
    let description: String
    let totalDays: Int
    let animalType: String // "cows", "heifers", or "both"
    let steps: [ProtocolStep]
    let ftaiTimingCows: Int? // hours after CIDR removal
    let ftaiTimingHeifers: Int? // hours after CIDR removal
}

// AI Protocol definitions
let AI_PROTOCOLS: [String: AIProtocol] = [
    "7_day_cosynch": AIProtocol(
        id: "7_day_cosynch",
        name: "7-Day CO-Synch + CIDR",
        description: "Most commonly used protocol across the industry for fixed-time AI of beef cows.",
        totalDays: 10,
        animalType: "both",
        steps: [
            ProtocolStep(
                day: 0,
                title: "Day 0: Insert CIDR + GnRH",
                description: "First handling event - insert CIDR and administer GnRH",
                actions: [
                    "Insert CIDR (1.38g progesterone)",
                    "Administer GnRH (100 μg gonadorelin acetate) IM",
                    "Record animal IDs and tag numbers",
                    "Check for any health issues"
                ],
                notes: "Handle animals calmly to reduce stress"
            ),
            ProtocolStep(
                day: 7,
                title: "Day 7: Remove CIDR + PGF2α",
                description: "Second handling event - remove CIDR and administer prostaglandin",
                actions: [
                    "Remove CIDR",
                    "Administer PGF2α (25 mg dinoprost tromethamine) IM",
                    "Observe for any retained CIDRs",
                    "Monitor animal condition"
                ],
                notes: "Ensure complete CIDR removal"
            ),
            ProtocolStep(
                day: 9,
                title: "Day 9-10: Fixed-Time AI",
                description: "Perform AI based on animal type",
                actions: [
                    "Administer GnRH (100 μg) at time of AI",
                    "Perform artificial insemination",
                    "Record breeding date and sire information",
                    "Note any animals showing signs of estrus"
                ],
                notes: "Cows: AI at 66 hours. Heifers: AI at 54 hours"
            )
        ],
        ftaiTimingCows: 66,
        ftaiTimingHeifers: 54
    ),
    "7_and_7_synch": AIProtocol(
        id: "7_and_7_synch",
        name: "7 & 7 Synch",
        description: "Newer protocol showing improved pregnancy rates.",
        totalDays: 16,
        animalType: "both",
        steps: [
            ProtocolStep(
                day: 0,
                title: "Day 0: Insert CIDR + PGF2α",
                description: "First handling - insert CIDR and administer prostaglandin",
                actions: [
                    "Insert CIDR (1.38g progesterone)",
                    "Administer PGF2α (25 mg dinoprost tromethamine) IM",
                    "Record animal IDs",
                    "Check body condition scores"
                ],
                notes: nil
            ),
            ProtocolStep(
                day: 7,
                title: "Day 7: GnRH Administration",
                description: "Mid-protocol GnRH treatment",
                actions: [
                    "Administer GnRH (100 μg gonadorelin acetate) IM",
                    "CIDR remains in place",
                    "Monitor for any issues"
                ],
                notes: "Do NOT remove CIDR on this day"
            ),
            ProtocolStep(
                day: 14,
                title: "Day 14: Remove CIDR + PGF2α",
                description: "Remove CIDR and administer second dose of prostaglandin",
                actions: [
                    "Remove CIDR",
                    "Administer PGF2α (25 mg) IM",
                    "Observe for estrus signs",
                    "Check for retained CIDRs"
                ],
                notes: nil
            ),
            ProtocolStep(
                day: 16,
                title: "Day 16-17: Fixed-Time AI",
                description: "Perform AI at appropriate timing for cows and heifers",
                actions: [
                    "Administer GnRH (100 μg) at time of AI",
                    "Perform artificial insemination",
                    "Record breeding information",
                    "Note AI technician and semen batch"
                ],
                notes: "Cows: 66 hours post-CIDR. Heifers: 54 hours post-CIDR"
            )
        ],
        ftaiTimingCows: 66,
        ftaiTimingHeifers: 54
    ),
    "5_day_cosynch": AIProtocol(
        id: "5_day_cosynch",
        name: "5-Day CO-Synch + CIDR",
        description: "Shorter protocol with modest improvement in pregnancy rates.",
        totalDays: 8,
        animalType: "both",
        steps: [
            ProtocolStep(
                day: 0,
                title: "Day 0: Insert CIDR + GnRH",
                description: "Insert CIDR and administer GnRH",
                actions: [
                    "Insert CIDR (1.38g progesterone)",
                    "Administer GnRH (100 μg gonadorelin acetate) IM",
                    "Record animal information"
                ],
                notes: nil
            ),
            ProtocolStep(
                day: 5,
                title: "Day 5 AM: Remove CIDR + First PGF2α",
                description: "Remove CIDR and give first prostaglandin dose",
                actions: [
                    "Remove CIDR",
                    "Administer PGF2α (25 mg) IM",
                    "Schedule second PG dose for 8 hours later"
                ],
                notes: "First of two PG doses required"
            ),
            ProtocolStep(
                day: 5,
                title: "Day 5 PM: Second PGF2α (8 hrs later)",
                description: "Administer second prostaglandin dose",
                actions: [
                    "Administer second PGF2α (25 mg) IM",
                    "Ensure 8-hour spacing from first dose",
                    "No CIDR insertion"
                ],
                notes: "Critical to maintain 8-hour spacing"
            ),
            ProtocolStep(
                day: 7,
                title: "Day 7-8: Fixed-Time AI",
                description: "Perform AI based on animal type",
                actions: [
                    "Administer GnRH (100 μg) at time of AI",
                    "Perform artificial insemination",
                    "Record all breeding data",
                    "Observe for estrus behavior"
                ],
                notes: "Earlier timing than 7-day protocol"
            )
        ],
        ftaiTimingCows: 66,
        ftaiTimingHeifers: 54
    )
]

// Helper function to get protocol by ID
func getAIProtocol(id: String) -> AIProtocol? {
    return AI_PROTOCOLS[id]
}

// Helper function to calculate step dates from a start date
func calculateProtocolDates(startDate: Date, aiProtocol: AIProtocol) -> [(step: ProtocolStep, date: Date)] {
    return aiProtocol.steps.map { step in
        let date = Calendar.current.date(byAdding: .day, value: step.day, to: startDate) ?? startDate
        return (step: step, date: date)
    }
}
