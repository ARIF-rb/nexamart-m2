-- Code: A14 | Source: team | Predicate: Two detection contracts — (a) broad: any event timestamp predating dc_shipments.created_datetime (68 shipments); (b) strict: DELIVERED before PICKED_UP within the events themselves (18 shipments). Strict count matches sir; broad is ours for catching upstream clock drift.
SELECT
    (SELECT COUNT(DISTINCT s.shipment_id)
       FROM dc_shipments s
       JOIN dc_delivery_events e ON e.shipment_id = s.shipment_id
       WHERE e.event_timestamp < s.created_datetime)                          AS broad_clock_drift,
    (SELECT COUNT(*) FROM (
        SELECT shipment_id
        FROM dc_delivery_events
        GROUP BY shipment_id
        HAVING MIN(CASE WHEN event_type_code = 'DELIVERED' THEN event_timestamp END) <
               MAX(CASE WHEN event_type_code = 'PICKED_UP' THEN event_timestamp END)
    ))                                                                       AS strict_delivered_before_pickup,
    (SELECT COUNT(*) FROM (
        SELECT shipment_id
        FROM dc_delivery_events
        GROUP BY shipment_id
        HAVING MIN(CASE WHEN event_type_code = 'DELIVERED' THEN event_timestamp END) <
               MAX(CASE WHEN event_type_code = 'PICKED_UP' THEN event_timestamp END)
    ))                                                                       AS affected_rows;
