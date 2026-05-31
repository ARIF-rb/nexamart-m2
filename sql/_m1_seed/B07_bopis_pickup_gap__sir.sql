-- Code: B7 | Source: sir | Predicate: BOPIS orders with order_status='DELIVERED' that have a READY_FOR_PICKUP scan but no BOPIS_COLLECTED scan. Sir: 25 affected orders.
SELECT COUNT(DISTINCT o.order_id) AS affected_rows
FROM ec_orders o
JOIN dc_shipments sh        ON sh.order_reference = o.order_number
JOIN dc_delivery_events ready ON ready.shipment_id = sh.shipment_id AND ready.event_type_code = 'READY_FOR_PICKUP'
LEFT JOIN dc_delivery_events coll
       ON coll.shipment_id = sh.shipment_id AND coll.event_type_code = 'BOPIS_COLLECTED'
WHERE o.delivery_method_code = 'BOPIS'
  AND o.order_status         = 'DELIVERED'
  AND coll.event_id IS NULL;
