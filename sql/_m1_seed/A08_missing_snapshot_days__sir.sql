-- Code: A8 | Source: sir | Predicate: Stores 3, 7, 12 missing snapshot records for Aug 1-7. Sir: ~21 missing store-days. snapshot_date format is DD/MM/YYYY in si_inventory_snapshots.
WITH stores(store_id) AS (
    SELECT 3 UNION ALL SELECT 7 UNION ALL SELECT 12
),
days(d) AS (
    SELECT '01/08/2024' UNION ALL SELECT '02/08/2024' UNION ALL SELECT '03/08/2024' UNION ALL
    SELECT '04/08/2024' UNION ALL SELECT '05/08/2024' UNION ALL SELECT '06/08/2024' UNION ALL
    SELECT '07/08/2024'
),
expected AS (
    SELECT s.store_id, d.d AS snapshot_date FROM stores s CROSS JOIN days d
),
actual AS (
    SELECT DISTINCT store_id, snapshot_date
    FROM si_inventory_snapshots
    WHERE store_id IN (3, 7, 12)
)
SELECT COUNT(*) AS affected_rows
FROM expected e
LEFT JOIN actual a
  ON a.store_id = e.store_id AND a.snapshot_date = e.snapshot_date
WHERE a.snapshot_date IS NULL;
