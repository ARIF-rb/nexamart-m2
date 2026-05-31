-- Code: A2 | Source: team | Predicate: Of all captured payments on cancelled orders, decompose into (a) captured strictly AFTER the earliest CANCELLED status_timestamp = 26, and (b) captured-then-cancelled (captured_ts <= cancel_ts) = 1. Total = 27.
-- Source tables: pg_transactions, ec_orders, ec_order_status_history. ec_order_status_history.status_timestamp is "YYYY-MM-DD HH:MM:SS" (text); pg.captured_ts is unix epoch.

WITH cancel_event AS (
    SELECT order_id, MIN(status_timestamp) AS cancel_ts
    FROM ec_order_status_history
    WHERE status_code = 'CANCELLED'
    GROUP BY order_id
),
joined AS (
    SELECT o.order_id, p.captured_ts, ce.cancel_ts
    FROM ec_orders o
    JOIN cancel_event ce ON ce.order_id = o.order_id
    JOIN pg_transactions p ON p.order_ref = o.order_number
    WHERE p.captured_ts IS NOT NULL
)
SELECT
    SUM(CASE WHEN captured_ts >  strftime('%s', cancel_ts) THEN 1 ELSE 0 END) AS strictly_after,
    SUM(CASE WHEN captured_ts <= strftime('%s', cancel_ts) THEN 1 ELSE 0 END) AS captured_then_cancelled,
    COUNT(*) AS affected_rows
FROM joined;
