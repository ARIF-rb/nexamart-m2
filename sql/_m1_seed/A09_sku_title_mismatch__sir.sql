-- Code: A9 | Source: sir | Predicate: ts_seller_listings row with nexamart_sku_ref='NX-TECH-0001' but seller_product_title contains 'Phone Case'. Sir: 1 row, listing_id=42.
SELECT COUNT(*) AS affected_rows
FROM ts_seller_listings
WHERE nexamart_sku_ref = 'NX-TECH-0001'
  AND LOWER(seller_product_title) LIKE '%phone case%';
