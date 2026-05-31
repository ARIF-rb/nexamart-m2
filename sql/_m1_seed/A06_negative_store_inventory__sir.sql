-- Code: A6 | Source: sir | Predicate: si_inventory_snapshots rows with negative physical_qty. Sir: 8 rows.
SELECT COUNT(*) AS affected_rows
FROM si_inventory_snapshots
WHERE physical_qty < 0;
