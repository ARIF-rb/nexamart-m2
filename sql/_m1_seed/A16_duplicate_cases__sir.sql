-- Code: A16 | Source: sir | Predicate: Same customer filed identical complaint across CHAT/PHONE/EMAIL within 48h; 3 separate cases per cluster. Sir: 7 cases.
-- The Bronze table already exposes is_duplicate_flag with canonical_case_ref populated — the source provides the materialised view of sir's predicate.
SELECT COUNT(*) AS affected_rows
FROM cs_cases
WHERE is_duplicate_flag = 1;
