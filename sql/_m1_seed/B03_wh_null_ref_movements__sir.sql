-- Code: B3 | Source: sir | Predicate: wh_inventory_movements with NULL reference_number, PCK-type. Sir: 175 rows.
SELECT COUNT(*) AS affected_rows
FROM wh_inventory_movements
WHERE reference_number IS NULL;
