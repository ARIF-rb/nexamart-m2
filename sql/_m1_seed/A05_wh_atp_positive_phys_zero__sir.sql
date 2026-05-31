-- Code: A5 | Source: sir | Predicate: wh_inventory_snapshots rows where atp_qty > 0 AND physical_qty = 0 (same row, same SKU, same date). Sir: 5 rows.
SELECT COUNT(*) AS affected_rows
FROM wh_inventory_snapshots
WHERE atp_qty > 0 AND physical_qty = 0;
