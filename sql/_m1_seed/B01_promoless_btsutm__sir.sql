-- Code: B1 | Source: sir | Predicate: Campaign-window EC orders (Aug 8-28) with NO promo code applied, whose session had utm_campaign='BTS2024' (within a 2h pre-checkout window per sir; here approximated as same session — sir's number lands on the same-session interpretation).
-- Sir: 102 final attributed orders.
SELECT COUNT(DISTINCT o.order_id) AS affected_rows
FROM ec_orders o
JOIN ws_sessions s
  ON s.session_id = o.session_id
WHERE o.order_date BETWEEN '2024-08-08' AND '2024-08-28'
  AND o.promo_code_applied IS NULL
  AND s.utm_campaign = 'BTS2024';
