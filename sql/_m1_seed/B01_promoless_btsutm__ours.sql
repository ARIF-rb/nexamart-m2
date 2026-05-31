-- Code: B1 | Source: team | Predicate: Candidate set = ALL Aug 8-28 EC orders without a promo code (126). The 102 in sir's count is the subset whose session carried the BTS UTM tag. Both surfaces matter: 126 is the population at risk of missed attribution; 102 is the recoverable subset.
SELECT
    (SELECT COUNT(*) FROM ec_orders
       WHERE order_date BETWEEN '2024-08-08' AND '2024-08-28'
         AND promo_code_applied IS NULL)                                                            AS candidate_set_promoless,
    (SELECT COUNT(DISTINCT o.order_id)
       FROM ec_orders o
       JOIN ws_sessions s ON s.session_id = o.session_id
       WHERE o.order_date BETWEEN '2024-08-08' AND '2024-08-28'
         AND o.promo_code_applied IS NULL
         AND s.utm_campaign = 'BTS2024')                                                            AS bts_utm_attributable,
    (SELECT COUNT(*) FROM ec_orders
       WHERE order_date BETWEEN '2024-08-08' AND '2024-08-28'
         AND promo_code_applied IS NULL)                                                            AS affected_rows;
