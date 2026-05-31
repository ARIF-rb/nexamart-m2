-- Code: A6 | Source: team | Predicate: Negative physical_qty OR negative sellable_qty in store snapshots. Cheatsheet lists 8 store snapshots (same set).
SELECT COUNT(*) AS affected_rows
FROM si_inventory_snapshots
WHERE physical_qty < 0
   OR sellable_qty < 0;
