-- ============================================================================
-- BACKFILL MISSING PREGNANCY RECORDS FROM CALVING DATA
-- ============================================================================
-- This script creates pregnancy records for any calving records that don't have one
-- Estimates breeding date from calving date assuming 283 day gestation period
-- Assumes natural service for all backfilled records
--
-- HOW TO RUN:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Paste this entire script
-- 3. Click "Run"
-- ============================================================================

-- First, let's see how many calving records are missing pregnancy records
SELECT
    COUNT(*) as calving_records_without_pregnancy
FROM calving_records
WHERE pregnancy_id IS NULL;

-- Show sample of what will be created
SELECT
    cr.id as calving_record_id,
    cr.dam_id,
    c.sire_id as bull_from_calf,
    (cr.calving_date - INTERVAL '283 days')::DATE AS estimated_breeding_date,
    cr.calving_date::DATE AS calving_date,
    'Natural' AS breeding_method,
    'calved' AS status
FROM calving_records cr
LEFT JOIN cattle c ON c.id = cr.calf_id
WHERE cr.pregnancy_id IS NULL
    AND cr.dam_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM cattle WHERE id = cr.dam_id)
LIMIT 10;

-- ============================================================================
-- EXECUTE THE BACKFILL
-- ============================================================================

-- Insert pregnancy records for calving records that don't have one
INSERT INTO pregnancy_records (
    id,
    cow_id,
    bull_id,
    breeding_date,
    breeding_method,
    status,
    expected_calving_date,
    notes,
    created_at
)
SELECT
    gen_random_uuid() AS id,
    cr.dam_id AS cow_id,
    c.sire_id AS bull_id,  -- Get sire from the calf record
    (cr.calving_date - INTERVAL '283 days')::DATE AS breeding_date,
    'Natural' AS breeding_method,
    'calved' AS status,
    cr.calving_date::DATE AS expected_calving_date,
    'Backfilled from calving record - assumed natural service with 283 day gestation' AS notes,
    cr.created_at AS created_at
FROM calving_records cr
LEFT JOIN cattle c ON c.id = cr.calf_id
WHERE cr.pregnancy_id IS NULL  -- Only backfill where no pregnancy record exists
    AND cr.dam_id IS NOT NULL  -- Must have a dam
    AND EXISTS (SELECT 1 FROM cattle WHERE id = cr.dam_id)  -- Dam must exist in cattle table
ON CONFLICT DO NOTHING
RETURNING id, cow_id, breeding_date, status;

-- Update the calving records to link to the newly created pregnancy records
-- We match based on dam_id, breeding_date calculated from calving_date, and status='Calved'
WITH updated AS (
    UPDATE calving_records cr
    SET pregnancy_id = pr.id
    FROM pregnancy_records pr
    WHERE cr.pregnancy_id IS NULL
        AND pr.cow_id = cr.dam_id
        AND pr.status = 'calved'
        AND pr.expected_calving_date = cr.calving_date::DATE
        AND pr.notes LIKE '%Backfilled from calving record%'
        AND pr.breeding_date = (cr.calving_date - INTERVAL '283 days')::DATE
    RETURNING cr.id, cr.pregnancy_id
)
SELECT COUNT(*) as calving_records_linked FROM updated;

-- ============================================================================
-- VERIFY THE RESULTS
-- ============================================================================

-- Check how many calving records still don't have pregnancy records
SELECT
    COUNT(*) as remaining_calving_records_without_pregnancy
FROM calving_records
WHERE pregnancy_id IS NULL;

-- Show sample of newly created pregnancy records
SELECT
    pr.id,
    pr.breeding_date,
    pr.breeding_method,
    pr.status,
    pr.expected_calving_date,
    pr.notes
FROM pregnancy_records pr
WHERE pr.notes LIKE '%Backfilled from calving record%'
ORDER BY pr.created_at DESC
LIMIT 10;
