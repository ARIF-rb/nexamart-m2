-- Code: A15 | Source: team | Predicate: Same — days_post_delivery < 0, with assertion that all 25 carry is_verified_purchase=0 (must be true to defend "verified-purchase rate overstated" narrative).
SELECT
    COUNT(*)                                          AS affected_rows,
    SUM(CASE WHEN is_verified_purchase = 0 THEN 1 ELSE 0 END) AS unverified_subset
FROM rv_reviews
WHERE days_post_delivery < 0;
