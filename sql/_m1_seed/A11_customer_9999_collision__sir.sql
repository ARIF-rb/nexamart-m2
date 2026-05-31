-- Code: A11 | Source: sir | Predicate: 178 EC guest orders attributed to customer_id=9999 (Sarah Chen's loyalty id). Sir: 178 guest orders.
SELECT COUNT(*) AS affected_rows
FROM ec_orders
WHERE customer_id = 9999;
