-- Code: B7 | Source: team | Predicate: Event-level framing — 144 READY_FOR_PICKUP scans vs 119 BOPIS_COLLECTED scans; the 25-event gap is the candidate set. Cheatsheet: 119 collected vs 144 ready.
SELECT
    (SELECT COUNT(DISTINCT shipment_id) FROM dc_delivery_events WHERE event_type_code = 'READY_FOR_PICKUP') AS ready_shipments,
    (SELECT COUNT(DISTINCT shipment_id) FROM dc_delivery_events WHERE event_type_code = 'BOPIS_COLLECTED')  AS collected_shipments,
    (SELECT COUNT(DISTINCT shipment_id) FROM dc_delivery_events WHERE event_type_code = 'READY_FOR_PICKUP')
  - (SELECT COUNT(DISTINCT shipment_id) FROM dc_delivery_events WHERE event_type_code = 'BOPIS_COLLECTED')  AS affected_rows;
