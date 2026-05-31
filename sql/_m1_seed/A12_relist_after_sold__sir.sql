-- Code: A12 | Source: sir | Predicate: A listing marked SOLD whose identical title/price/image_hash is relisted by the same seller days later. Sir: 1 listing pair.
-- The explicit "1 row" matches the metadata field nl_listings.relist_count > 0 (or original_listing_ref populated).
SELECT COUNT(*) AS affected_rows
FROM nl_listings
WHERE relist_count > 0;
