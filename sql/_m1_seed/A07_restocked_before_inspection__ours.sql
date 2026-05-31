-- Code: A7 | Source: team (adopted from sir per .private/anomaly_count_verification_2026-05-25.md)
-- Predicate: inspection_status='PENDING' AND restocked_qty > 0
-- Stock re-entered the sellable pool before inspection completed. Expect 10.
-- A10's separate 12-row OPENED+NEW set lives in A10_open_box_as_new__ours.sql;
-- the two predicates overlap but are not equal.
SELECT COUNT(*) AS affected_rows
FROM rr_return_receipts
WHERE inspection_status = 'PENDING'
  AND restocked_qty > 0;
