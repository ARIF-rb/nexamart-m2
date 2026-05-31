-- Code: A10 | Source: team (matches sir verbatim — 12 receipts).
-- Predicate: condition_on_receipt='OPENED' AND restocked_as_condition='NEW' — open-box items restocked into NEW pool. M4-owned per docs/tasks/M4.md Task 11.
-- Distinct from A7 (RESTOCK_BEFORE_INSPECTION) which uses inspection_status='PENDING' AND restocked_qty > 0 (10 receipts, Lead's scope). Sets overlap but are not equal.
SELECT COUNT(*) AS affected_rows
FROM rr_return_receipts
WHERE condition_on_receipt = 'OPENED'
  AND restocked_as_condition = 'NEW';
