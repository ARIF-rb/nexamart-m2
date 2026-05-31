-- Code: A15 | Source: sir | Predicate: Review submitted_at is before the courier DELIVERED confirmation. rv_reviews exposes days_post_delivery already — a negative value encodes the same pre-condition. Sir: 25.
SELECT COUNT(*) AS affected_rows
FROM rv_reviews
WHERE days_post_delivery < 0;
