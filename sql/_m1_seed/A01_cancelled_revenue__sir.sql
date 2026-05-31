-- Code: A1 | Source: sir | Predicate: Cancelled transactions/orders with positive amounts counted as revenue, across POS (status_code='C') and EC (order_status='CANCELLED'). Sir documents "~178 rows" combining both channels.
-- Source tables (per sir): pos_transactions, ec_orders
-- Sir's resolution: Silver filter status_code='C' (POS) and order_status='CANCELLED' (EC). Flag UNRELIABLE.

SELECT
    (SELECT COUNT(*) FROM pos_transactions WHERE status_code = 'C' AND total_amount_incl_tax > 0)
  + (SELECT COUNT(*) FROM ec_orders        WHERE order_status = 'CANCELLED' AND subtotal_excl_tax > 0)
  AS affected_rows;
