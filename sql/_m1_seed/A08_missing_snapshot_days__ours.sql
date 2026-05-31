-- Code: A8 | Source: team | Predicate: Same identification — Stores 3, 7, 12 each have exactly 24 distinct Aug snapshot dates instead of 31; the 7-day gap falls inside the Aug 1-28 campaign ramp (Aug 1-7). 3 stores × 7 days = 21 missing store-days. Other 17 stores have full 31-day Aug coverage; warehouses gapless.
WITH aug_coverage AS (
    SELECT store_id, COUNT(DISTINCT snapshot_date) AS aug_days
    FROM si_inventory_snapshots
    WHERE snapshot_date LIKE '%/08/2024'
    GROUP BY store_id
)
SELECT
    (SELECT SUM(31 - aug_days) FROM aug_coverage WHERE aug_days < 31) AS affected_rows,
    (SELECT COUNT(*)            FROM aug_coverage WHERE aug_days < 31) AS affected_stores;
