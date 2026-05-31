-- Code: A7 | Source: sir | Predicate: inspection_status='PENDING' but restocked_qty > 0 — returned stock incremented to sellable inventory before inspection event confirms condition. Sir: 10 rows.
SELECT COUNT(*) AS affected_rows
FROM rr_return_receipts
WHERE inspection_status = 'PENDING'
  AND restocked_qty > 0;
