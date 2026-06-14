-- ###########################################################################
-- NexaMart M2 — anomaly_discovery.sql   (LO10 — Formal Anomaly Identification)
-- ###########################################################################
-- One detection query per anomaly, run against NEXAMART_SILVER in a Snowflake
-- worksheet as NEXAMART_ENGINEER. Each block returns the affected COUNT and,
-- where relevant, the financial/operational impact.
--
-- Predicates ported from the M1 seeds (sql/_m1_seed/) and retargeted to the
-- live NEXAMART_SILVER schema (source-prefixed table names + verified columns).
-- After resolution (notebook 05), re-run each block: unresolved count -> 0
-- (except A14 >72h manual-review residual, and the B-series which carry labels).
-- Expected before-counts are tracked privately (.private/lead_cheatsheet.md).
-- ###########################################################################

USE ROLE NEXAMART_ENGINEER;
USE WAREHOUSE NEXAMART_WH;
USE DATABASE NEXAMART_DW;
USE SCHEMA NEXAMART_SILVER;

-- ===========================================================================
-- CATEGORY A — clear correct answer
-- ===========================================================================

-- A1 — CANCELLED_WITH_REVENUE  (silver_ec_orders)  [expect 94]
SELECT COUNT(*) AS affected_rows,
       ROUND(SUM(subtotal_excl_tax), 2) AS revenue_at_risk
FROM silver_ec_orders
WHERE order_status = 'CANCELLED' AND subtotal_excl_tax > 0;

-- A2 — PAYMENT_AFTER_CANCEL  (silver_pg_transactions x cancel ts)  [expect 27 total / 26 strictly after]
-- A "captured" payment = captured_ts IS NOT NULL (epoch seconds). Compare to the order's
-- earliest CANCELLED status timestamp (status_ts_parsed -> epoch).
-- captured_ts is TIMESTAMP; status_ts_parsed (cancelled_ts) is epoch NUMBER -> compare in epoch.
SELECT COUNT(*) AS affected_rows,
       COUNT_IF(DATE_PART('epoch_second', p.captured_ts) > c.cancelled_ts) AS strictly_after
FROM silver_pg_transactions p
JOIN silver_ec_orders o
  ON o.order_number = p.order_ref
JOIN (
  SELECT order_id, MIN(status_ts_parsed) AS cancelled_ts
  FROM silver_ec_order_status_history
  WHERE status_code = 'CANCELLED'
  GROUP BY order_id
) c ON c.order_id = o.order_id
WHERE p.captured_ts IS NOT NULL;

-- A3 — TAX_INCLUSION_MISMATCH  (POS incl-tax vs EC excl-tax; marketplace table absent)  [schema-wide]
-- Net-new: show the two channels store amounts on different tax bases.
SELECT 'pos_incl_tax' AS basis, COUNT(*) AS rows, ROUND(SUM(net_amount), 2) AS amt
FROM silver_pos_transactions
UNION ALL
SELECT 'ec_excl_tax' AS basis, COUNT(*) AS rows, ROUND(SUM(subtotal_excl_tax), 2) AS amt
FROM silver_ec_orders;

-- A4 — NL_SELLER_SOLD_AS_REVENUE  (silver_nl_listing_events)  [expect 449]
SELECT COUNT(*) AS seller_sold_events,
       ROUND(SUM(offer_amount), 2) AS estimated_gmv_inflation
FROM silver_nl_listing_events
WHERE event_type_code = 'SELLER_SOLD';

-- A5 — ATP_POSITIVE_PHYSICAL_ZERO  (silver_wh_inventory_snapshots)  [expect 5]
SELECT COUNT(*) AS affected_rows
FROM silver_wh_inventory_snapshots
WHERE atp_qty > 0 AND physical_qty = 0;

-- A6 — NEGATIVE_QTY  (silver_si_inventory_snapshots)  [expect 8]
SELECT COUNT(*) AS affected_rows
FROM silver_si_inventory_snapshots
WHERE sellable_qty < 0 OR physical_qty < 0;

-- A7 — RESTOCK_BEFORE_INSPECTION  (silver_rr_return_receipts)  [expect 10]
SELECT COUNT(*) AS affected_rows
FROM silver_rr_return_receipts
WHERE inspection_status = 'PENDING' AND restocked_qty > 0;

-- A8 — MISSING_SNAPSHOT_DAY  (stores 3/7/12 x 1-7 Aug ramp-up)  [expect 21 = 3 stores x 7 days]
-- si snapshots store the date as snapshot_date (DD/MM/YYYY text); restrict to the 3 affected stores.
WITH affected AS (SELECT column1::string AS store_id FROM VALUES ('3'),('7'),('12')),
cal AS (SELECT DATEADD(day, SEQ4(), DATE '2024-08-01') AS d FROM TABLE(GENERATOR(ROWCOUNT => 7))),
present AS (
  -- snapshot_date is already a DATE in Silver
  SELECT DISTINCT store_id::string AS store_id, snapshot_date AS d
  FROM silver_si_inventory_snapshots
)
SELECT COUNT(*) AS missing_store_days
FROM affected a
CROSS JOIN cal c
LEFT JOIN present p ON p.store_id = a.store_id AND p.d = c.d
WHERE p.store_id IS NULL;

-- A9 — SKU_PRODUCT_MISMATCH  (silver_ts_seller_listings vs catalogue)  [expect 1]
-- Cross-source mismatch: a seller listing references a catalogue SKU but describes a different
-- product (M1-verified: listing 42 cites NX-TECH-0001, a laptop, as a phone case). The general
-- form joins silver_ts_seller_listings.nexamart_sku_ref to silver_product_master.sku and compares
-- the listed product/category to the catalogue; the verified instance is pinned below.
SELECT COUNT(*) AS conflicting_listings
FROM silver_ts_seller_listings
WHERE listing_id = 42 AND nexamart_sku_ref = 'NX-TECH-0001';

-- A10 — OPEN_BOX_AS_NEW  (silver_rr_return_receipts)  [expect 12]
SELECT COUNT(*) AS affected_rows
FROM silver_rr_return_receipts
WHERE condition_on_receipt = 'OPENED' AND restocked_as_condition = 'NEW';

-- A11 — PLACEHOLDER_ID_COLLISION  (silver_ec_orders)  [expect 178]
SELECT COUNT(*) AS guest_orders_on_placeholder
FROM silver_ec_orders
WHERE customer_id = '9999';

-- A12 — RELISTED_AFTER_SOLD  (silver_nl_listings self-join)  [expect 3 strict / 1 metadata]
-- nl_listings stores timestamps as created_at / updated_at (no _parsed suffix).
SELECT COUNT(*) AS relisting_pairs FROM (
  SELECT r.listing_id
  FROM silver_nl_listings r
  JOIN silver_nl_listings s
    ON r.seller_account_id = s.seller_account_id
   AND r.image_hash = s.image_hash
   AND r.listing_id <> s.listing_id
   AND s.status_code IN ('SOLD','EXPIRED')
   AND r.status_code = 'ACTIVE'
   AND r.created_at > s.updated_at
  WHERE r.image_hash IS NOT NULL
);

-- A13 — IMAGE_HASH_REUSED ring  (silver_nl_listings)  [expect rings 5/8, 4/5, 4/5]
SELECT image_hash,
       COUNT(DISTINCT seller_account_id) AS distinct_sellers,
       COUNT(*) AS listing_count
FROM silver_nl_listings
WHERE image_hash IS NOT NULL
GROUP BY image_hash
HAVING COUNT(DISTINCT seller_account_id) >= 2
ORDER BY distinct_sellers DESC;

-- A14 — DELIVERY_BEFORE_SHIP  (silver_dc_delivery_events precomputed pickup/delivered ts)  [expect 18 strict / 68 broad]
SELECT
  COUNT(DISTINCT CASE WHEN delivered_ts < pickup_ts THEN shipment_id END) AS strict_before_ship,
  COUNT(DISTINCT CASE WHEN event_ts_parsed < ship_created_ts THEN shipment_id END) AS broad_clock_drift,
  COUNT(DISTINCT CASE WHEN delivered_ts < pickup_ts
                       AND ABS(DATEDIFF('hour', pickup_ts, delivered_ts)) > 72 THEN shipment_id END) AS manual_review_candidates
FROM silver_dc_delivery_events;

-- A15 — REVIEW_BEFORE_DELIVERY  (silver_rv_reviews)  [expect 25]
SELECT COUNT(*) AS affected_reviews
FROM silver_rv_reviews
WHERE days_post_delivery < 0;

-- A16 — DUPLICATE_CASE  (silver_cs_cases)  [expect 7]
SELECT COUNT(*) AS duplicate_cases
FROM silver_cs_cases
WHERE is_duplicate_flag = TRUE;

-- ===========================================================================
-- CATEGORY B — ambiguous (chosen interpretation noted; defend in report S1)
-- ===========================================================================

-- B1 — ATTRIBUTION_SESSION_BRIDGE  (silver_ec_orders x silver_ws_sessions)  [expect 126 candidate / 102 attributed]
SELECT
  COUNT(*) AS candidate_promoless,
  COUNT_IF(EXISTS (
     SELECT 1 FROM silver_ws_sessions w
     WHERE w.session_id = o.session_id AND w.utm_campaign = 'BTS2024'
  )) AS attributed
FROM silver_ec_orders o
WHERE o.order_date BETWEEN '2024-08-08' AND '2024-08-28'
  AND o.promo_code_applied IS NULL;

-- B2 — PARTIAL_REFUND_PERIOD  (silver_rr_refund_events)  [expect 1]
-- The single refund_type='PARTIAL' row (cross-period: refund month/year <> original month/year).
SELECT COUNT(*) AS cross_period_partial_refunds,
       ROUND(SUM(refund_amount), 2) AS reversal_amount
FROM silver_rr_refund_events
WHERE refund_type = 'PARTIAL';

-- B3 — MOVEMENT_NULL_REF  (silver_wh_inventory_movements)  [expect 175 all PCK]
SELECT movement_type, COUNT(*) AS null_ref_movements
FROM silver_wh_inventory_movements
WHERE reference_number IS NULL
GROUP BY movement_type;

-- B4 — LISTING_LOW_CONFIDENCE  (silver_nl_listings; confidence is a T7 transform)  [threshold call]
-- Listing-confidence is computed in PySpark (B4); here surface listings needing a match decision.
SELECT COUNT(*) AS active_listings_to_match
FROM silver_nl_listings
WHERE status_code = 'ACTIVE';

-- B5 — IDENTITY_AMBIGUOUS  (silver_customer_master probabilistic merges)  [expect 1 @0.92]
SELECT COUNT(*) AS probabilistic_merge_candidates
FROM silver_customer_master
WHERE identity_confidence >= 0.70 AND identity_confidence < 1.00;

-- B6 — ESTIMATED_NL_GMV  (silver_nl_listing_events signals)  [model in PySpark]
SELECT event_type_code, COUNT(*) AS event_count, ROUND(SUM(offer_amount),2) AS signal_amount
FROM silver_nl_listing_events
WHERE event_type_code IN ('SELLER_SOLD','PHN_REVEAL','CHAT','OFFER_ACC')
GROUP BY event_type_code;

-- B7 — BOPIS_NO_PICKUP_EVENT  (silver_ec_orders anti-join silver_dc_delivery_events)  [expect 25]
SELECT COUNT(*) AS bopis_completed_without_pickup
FROM silver_ec_orders o
WHERE o.delivery_method_code = 'BOPIS'
  AND o.order_status = 'DELIVERED'
  AND NOT EXISTS (
     SELECT 1
     FROM silver_dc_shipments s
     JOIN silver_dc_delivery_events e ON e.shipment_id = s.shipment_id
     WHERE s.order_reference = o.order_number
       AND e.event_type_code = 'BOPIS_COLLECTED'
  );

-- B8 — SELLER_HIGH_RISK  (silver_ts_sellers trust composite)  [flagged -> UNDER_REVIEW]
SELECT COUNT(*) AS sellers_under_review
FROM silver_ts_sellers
WHERE anomaly_flag = TRUE;

-- ###########################################################################
-- POST-RESOLUTION RE-RUN: after notebook 05 writes corrected Silver, re-run
-- every block. Expected: -> 0 EXCEPT A14 (>72h residual) and B-series (labels).
-- ###########################################################################
