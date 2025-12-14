//
//  SupabaseConfig.swift
//  LilyHillFarm
//
//  Supabase configuration for the HERD cattle management system
//

import Foundation

struct SupabaseConfig {
    // MARK: - Configuration

    /// Supabase project URL
    static let supabaseURL = "https://kngaoytqvmjbrsjakzky.supabase.co"

    /// Supabase anon/public API key
    /// Note: Paste your actual anon key here (starts with eyJ...)
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZ2FveXRxdm1qYnJzamFremt5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MzMzMjIsImV4cCI6MjA4MDQwOTMyMn0.PmkU-Ed5vYQiB875Sl9bM0Eq_N8bfYJV-tK0kfa5afg"

    /// Vercel deployment URL for Next.js API routes (TTS, AI chat, etc.)
    static let apiURL = "https://app.lilyhillcattle.com"

    // MARK: - Storage Buckets

    /// Storage bucket name for cattle photos
    static let photosBucketName = "cattle-photos"

    // MARK: - Table Names

    struct Tables {
        static let cattle = "cattle"
        static let healthRecords = "health_records"
        static let calvingRecords = "calving_records"
        static let pregnancyRecords = "pregnancy_records"
        static let stageTransitions = "stage_transitions"
        static let processingRecords = "processing_records"
        static let saleRecords = "sale_records"
        static let mortalityRecords = "mortality_records"
        static let photos = "photos"
        static let tasks = "tasks"
        static let contacts = "contacts"

        // Reference data (read-only)
        static let breeds = "breeds"
        static let treatmentPlans = "treatment_plans"
        static let treatmentPlanSteps = "treatment_plan_steps"
        static let healthRecordTypes = "health_record_types"
        static let healthConditions = "health_conditions"
        static let medications = "medications"
        static let veterinarians = "veterinarians"
        static let processors = "processors"
        static let buyers = "buyers"
        static let cattleStages = "cattle_stages"
        static let productionPaths = "production_paths"
        static let productionPathStages = "production_path_stages"
        static let pastures = "pastures"
        static let pastureLogs = "pasture_logs"
    }

    // MARK: - Validation

    /// Check if Supabase is properly configured
    static var isConfigured: Bool {
        return supabaseURL != "YOUR_SUPABASE_URL" &&
               supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY" &&
               !supabaseURL.isEmpty &&
               !supabaseAnonKey.isEmpty
    }
}
