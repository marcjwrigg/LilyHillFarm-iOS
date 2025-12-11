-- Backfill missing pregnancy records for calving records
-- Estimates breeding date from calving date assuming 283 day gestation
-- Assumes natural service for all backfilled records

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
ON CONFLICT DO NOTHING;

-- Now update the calving records to link to the newly created pregnancy records
-- We match based on dam_id, breeding_date calculated from calving_date, and status='Calved'
UPDATE calving_records cr
SET pregnancy_id = pr.id
FROM pregnancy_records pr
WHERE cr.pregnancy_id IS NULL
    AND pr.cow_id = cr.dam_id
    AND pr.status = 'calved'
    AND pr.expected_calving_date = cr.calving_date::DATE
    AND pr.notes LIKE '%Backfilled from calving record%'
    AND pr.breeding_date = (cr.calving_date - INTERVAL '283 days')::DATE;

-- Add a comment
COMMENT ON COLUMN pregnancy_records.notes IS
'Notes about the pregnancy. Records with "Backfilled from calving record" were auto-generated from historical calving data.';
