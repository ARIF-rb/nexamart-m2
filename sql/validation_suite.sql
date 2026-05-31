-- ###########################################################################
-- NexaMart M2 — validation_suite.sql   (LO13 — Data Warehouse Validation)
-- ###########################################################################
-- Run AFTER every Gold rebuild (and after anomaly resolution). Each check returns
-- the OFFENDING rows; target is 0 rows unless noted (Check 7 expects >= 1 per fact).
-- Expect failures on the first run — iterate Silver/Gold fixes and re-run. Record
-- every iteration in report Section 3 (which checks failed, what you fixed, final state).
--
-- Replace each `/* TODO */` with the concrete grain/columns for that table.
-- A check "passes" when its SELECT returns zero rows (except Check 7).
-- ###########################################################################

USE ROLE NEXAMART_ENGINEER;
USE WAREHOUSE NEXAMART_WH;
USE DATABASE NEXAMART_DW;
USE SCHEMA NEXAMART_GOLD;

-- ===========================================================================
-- CHECK 1 — COMPLETENESS: every Gold table non-empty + matches expected count.
-- Pass: no table reports 0 rows (or a count far below its Silver source).
-- ===========================================================================
-- TODO: expand to all 27 Gold tables; compare against expected counts from Silver.
SELECT 'fact_ecommerce_order_line' AS gold_table, COUNT(*) AS row_count FROM fact_ecommerce_order_line
UNION ALL SELECT 'fact_store_sale_line', COUNT(*) FROM fact_store_sale_line
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
-- ... TODO remaining 24 tables ...
;
-- FAIL if any row_count = 0.

-- ===========================================================================
-- CHECK 2 — REFERENTIAL INTEGRITY: zero orphan FKs in any fact.
-- Pattern: LEFT JOIN fact -> dim on surrogate key; WHERE dim key IS NULL.
-- ===========================================================================
-- TODO: repeat per (fact, dim FK). Example:
SELECT 'fact_ecommerce_order_line.customer_sk' AS fk, COUNT(*) AS orphan_rows
FROM fact_ecommerce_order_line f
LEFT JOIN dim_customer d ON f.customer_surrogate_key = d.customer_surrogate_key
WHERE d.customer_surrogate_key IS NULL AND f.customer_surrogate_key IS NOT NULL
-- UNION ALL ... TODO every other FK ...
;
-- FAIL if orphan_rows > 0 for any FK.

-- ===========================================================================
-- CHECK 3 — GRAIN VIOLATIONS: no duplicate rows at the declared grain.
-- Pattern: GROUP BY <declared grain>; HAVING COUNT(*) > 1.
-- ===========================================================================
-- TODO: one query per fact at its declared grain. Example (store sale line):
SELECT receipt_number, product_surrogate_key, COUNT(*) AS dup_rows
FROM fact_store_sale_line
GROUP BY receipt_number, product_surrogate_key
HAVING COUNT(*) > 1
-- ... TODO every fact's grain ...
;
-- FAIL if any group has dup_rows > 1.

-- ===========================================================================
-- CHECK 4 — ADDITIVE FACT SANITY: net = gross - discount - return.
-- ===========================================================================
SELECT COUNT(*) AS broken_rows
FROM fact_store_sale_line
WHERE ABS(net_sale_amount
          - (gross_sale_amount - discount_amount - return_amount)) > 0.01;
-- FAIL if broken_rows > 0.

-- ===========================================================================
-- CHECK 5 — SEMI-ADDITIVE GUARD: no mart view SUMs ATP across dates.
-- This is a CODE/REVIEW check: scan kpi_views.sql for SUM(atp...) without a single-date
-- filter or per-date GROUP BY. Programmatic guard: inspect view definitions.
-- ===========================================================================
SELECT table_name AS suspect_view
FROM NEXAMART_DW.INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'NEXAMART_MARTS'
  AND UPPER(view_definition) LIKE '%SUM%ATP%'
  AND UPPER(view_definition) NOT LIKE '%GROUP BY%DATE%';  -- TODO: refine heuristic
-- FAIL if any view sums ATP across dates. (Manually confirm flagged views.)

-- ===========================================================================
-- CHECK 6 — METRIC CERTAINTY COMPLETENESS: no NULL metric_certainty_level in any fact.
-- ===========================================================================
-- TODO: repeat per fact table.
SELECT 'fact_ecommerce_order_line' AS gold_table, COUNT(*) AS null_certainty
FROM fact_ecommerce_order_line WHERE metric_certainty_level IS NULL
-- UNION ALL ... TODO all 14 facts ...
;
-- FAIL if null_certainty > 0 anywhere.

-- ===========================================================================
-- CHECK 7 — CAMPAIGN PERIOD COVERAGE: >= 1 row per (campaign-accepting) fact in 8-28 Aug 2024.
-- This check PASSES when each row_in_window >= 1 (opposite polarity to the others).
-- ===========================================================================
-- TODO: repeat per fact that accepts campaign-period data (join its date dim/role).
SELECT 'fact_ecommerce_order_line' AS gold_table,
       COUNT_IF(order_date BETWEEN '2024-08-08' AND '2024-08-28') AS rows_in_window
FROM fact_ecommerce_order_line
-- UNION ALL ... TODO other campaign-accepting facts ...
;
-- FAIL if any rows_in_window = 0.

-- ===========================================================================
-- CHECK 8 — INVENTORY BALANCE RECONCILIATION: sample SKU-location-week; list failures
--           WITH SKU + location identifiers.
-- opening + inbound - outbound should equal closing snapshot for the week.
-- ===========================================================================
-- TODO: pick a sample of SKU-location-week combos; compute derived vs recorded balance.
SELECT sku, location_id, week_start,
       opening_qty, inbound_qty, outbound_qty, closing_qty_recorded,
       (opening_qty + inbound_qty - outbound_qty) AS closing_qty_derived
FROM ( /* TODO reconciliation CTE */ SELECT NULL AS sku, NULL AS location_id,
        NULL AS week_start, 0 AS opening_qty, 0 AS inbound_qty, 0 AS outbound_qty,
        0 AS closing_qty_recorded WHERE 1=0 )
WHERE closing_qty_recorded <> (opening_qty + inbound_qty - outbound_qty);
-- FAIL rows list the offending SKU + location.

-- ===========================================================================
-- CHECK 9 — CLASSIFIED CERTAINTY SEGREGATION: no Finance-domain mart row is ESTIMATED
--           without is_confirmed_transaction = FALSE. Estimated never in confirmed totals.
-- ===========================================================================
-- TODO: union the Finance-domain views (those carrying is_confirmed_transaction).
SELECT 'vw_confirmed_gmv' AS finance_view, COUNT(*) AS bad_rows
FROM NEXAMART_MARTS.vw_confirmed_gmv
WHERE metric_certainty_level = 'ESTIMATED' AND is_confirmed_transaction <> FALSE
-- UNION ALL ... TODO other finance views ...
;
-- FAIL if bad_rows > 0.

-- ===========================================================================
-- CHECK 10 — TEMPORAL CONSISTENCY: no delivered-before-shipped beyond the >72h
--            correction threshold (post-A14-resolution residual must be manual-review only).
-- ===========================================================================
SELECT COUNT(*) AS uncorrected_violations
FROM fact_order_fulfilment
WHERE /* TODO: delivered_ts < shipped_ts AND resolution_method <> 'ESCALATED_MANUAL_REVIEW' */ 1=0;
-- FAIL if uncorrected_violations > 0.

-- ###########################################################################
-- After all 10 pass, record the iteration count + per-iteration failures in report S3.
-- ###########################################################################
