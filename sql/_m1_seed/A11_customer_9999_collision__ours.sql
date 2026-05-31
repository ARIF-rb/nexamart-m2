-- Code: A11 | Source: team | Predicate: Sir's 178 + verification that customer_id=9999 is also a singleton real-loyalty row (Sarah Chen). All 178 EC orders use SESS-GUEST-* session_id, confirming guest-checkout placeholder pattern.
SELECT
    (SELECT COUNT(*) FROM ec_orders WHERE customer_id = 9999)                                       AS guest_orders_attributed,
    (SELECT COUNT(*) FROM ec_orders WHERE customer_id = 9999 AND session_id LIKE 'SESS-GUEST%')     AS guest_orders_with_guest_session,
    (SELECT COUNT(*) FROM ec_orders WHERE customer_id = 9999)                                       AS affected_rows;
