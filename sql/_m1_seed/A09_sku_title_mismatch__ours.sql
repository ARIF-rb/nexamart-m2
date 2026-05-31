-- Code: A9 | Source: team | Predicate: Same — listing_id=42 specifically, mapped to NX-TECH-0001 (laptop in catalogue) but titled as phone case by Seller 75.
SELECT COUNT(*) AS affected_rows
FROM ts_seller_listings
WHERE listing_id = 42
  AND nexamart_sku_ref = 'NX-TECH-0001';
