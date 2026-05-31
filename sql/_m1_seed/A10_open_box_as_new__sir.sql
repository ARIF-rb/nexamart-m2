-- Code: A10 | Source: sir | Predicate: Returned items with condition_on_receipt='OPENED' restocked as condition='NEW'. Sir: 12 rows.
SELECT COUNT(*) AS affected_rows
FROM rr_return_receipts
WHERE condition_on_receipt = 'OPENED'
  AND restocked_as_condition = 'NEW';
