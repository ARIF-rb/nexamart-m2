-- Code: A2 | Source: sir | Predicate: Payment gateway CAPTURED event timestamp occurs after the order was already cancelled. Sir's count: 27 rows.
-- Source tables: pg_transactions, ec_orders. CAPTURED is encoded in pg_transactions as status_code=2 with captured_ts populated.

SELECT COUNT(*) AS affected_rows
FROM ec_orders o
JOIN pg_transactions p
  ON p.order_ref = o.order_number
WHERE o.order_status = 'CANCELLED'
  AND p.captured_ts IS NOT NULL;
