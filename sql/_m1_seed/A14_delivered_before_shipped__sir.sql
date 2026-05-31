-- Code: A14 | Source: sir | Predicate: A DELIVERED event timestamp is earlier than the PICKED_UP event timestamp for the same shipment. Sir: 18 shipments. "SHIPPED" is not a dc_delivery_events code; PICKED_UP is the closest analogue.
SELECT COUNT(*) AS affected_rows
FROM (
    SELECT shipment_id
    FROM dc_delivery_events
    GROUP BY shipment_id
    HAVING MIN(CASE WHEN event_type_code = 'DELIVERED' THEN event_timestamp END) <
           MAX(CASE WHEN event_type_code = 'PICKED_UP' THEN event_timestamp END)
);
