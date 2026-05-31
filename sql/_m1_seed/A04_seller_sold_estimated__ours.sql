-- Code: A4 | Source: team | Predicate: 449 SELLER_SOLD events corresponding to 449 distinct SOLD listings.
SELECT
    (SELECT COUNT(*)                FROM nl_listing_events WHERE event_type_code='SELLER_SOLD') AS seller_sold_events,
    (SELECT COUNT(DISTINCT listing_id) FROM nl_listing_events WHERE event_type_code='SELLER_SOLD') AS distinct_listings,
    (SELECT COUNT(*)                FROM nl_listing_events WHERE event_type_code='SELLER_SOLD') AS affected_rows;
