-- Code: A1 | Source: team | Predicate: Cancelled EC orders carrying positive revenue (subtotal_excl_tax > 0). Lead's cheatsheet locks the EC count at 94 orders summing ₹4,078,605.
-- Source table (ours): ec_orders. POS cancellations are treated under A3 normalisation (tax-inclusive amounts must not be summed with EC excl-tax).

SELECT COUNT(*) AS affected_rows,
       ROUND(SUM(subtotal_excl_tax), 2) AS revenue_at_risk
FROM ec_orders
WHERE order_status = 'CANCELLED'
  AND subtotal_excl_tax > 0;
