-- Code: B3 | Source: team | Predicate: All 175 NULL-reference movements are movement_type='PCK' (pick) — adds the type-attribution dimension sir's text implies but doesn't filter on. Cheatsheet locks: 175 / all PCK.
SELECT
    COUNT(*)                                                                  AS affected_rows,
    SUM(CASE WHEN movement_type = 'PCK' THEN 1 ELSE 0 END)                    AS pck_subset,
    COUNT(DISTINCT movement_type)                                             AS distinct_types
FROM wh_inventory_movements
WHERE reference_number IS NULL;
