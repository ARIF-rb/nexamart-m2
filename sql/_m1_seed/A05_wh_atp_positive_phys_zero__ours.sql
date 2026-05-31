-- Code: A5 | Source: team | Predicate: Same predicate as sir — atp_qty>0 with physical_qty=0; cheatsheet locks 5 SKU-date combinations during campaign window.
SELECT COUNT(*) AS affected_rows
FROM wh_inventory_snapshots
WHERE atp_qty > 0
  AND physical_qty = 0;
