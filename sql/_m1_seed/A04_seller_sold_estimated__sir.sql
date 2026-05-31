-- Code: A4 | Source: sir | Predicate: NexaLocal SELLER_SOLD events counted as confirmed GMV. Sir: 449 events.
SELECT COUNT(*) AS affected_rows
FROM nl_listing_events
WHERE event_type_code = 'SELLER_SOLD';
