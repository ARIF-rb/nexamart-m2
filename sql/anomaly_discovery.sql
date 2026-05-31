-- ###########################################################################
-- NexaMart M2 — anomaly_discovery.sql   (LO10 — Formal Anomaly Identification)
-- ###########################################################################
-- One detection query per anomaly, run against NEXAMART_SILVER in a Snowflake
-- worksheet. Each block returns the affected rows + an interpretable COUNT and,
-- where relevant, the financial/operational impact.
--
-- HOW TO USE THIS FILE
--  1. Port each predicate from the M1 seed (sql/_m1_seed/<id>_*__ours.sql) — those
--     ran against SQLite/Bronze; here they must target NEXAMART_SILVER and use
--     Snowflake dialect (DATE/TIMESTAMP casts, DATEDIFF, etc.).
--  2. Replace every `/* TODO */` with the real predicate; keep the COUNT shape.
--  3. After resolution (notebook 05), re-run each query — the unresolved count
--     must drop to 0 (or the expected residual, e.g. A14 >72h manual-review rows).
--  4. Counts are acceptance contracts — see .private/lead_cheatsheet.md.
--
-- SEEDS PRESENT (sql/_m1_seed/): A01-A02, A04-A16, B01, B03, B07.
-- NET-NEW IN M2 (no seed): A03, B2, B4, B5, B6, B8 — write from scratch.
-- ###########################################################################

USE ROLE NEXAMART_ENGINEER;
USE WAREHOUSE NEXAMART_WH;
USE DATABASE NEXAMART_DW;
USE SCHEMA NEXAMART_SILVER;

-- ===========================================================================
-- CATEGORY A — clear correct answer
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A1 — CANCELLED_WITH_REVENUE                                   [Category A]
-- Desc   : EC order status CANCELLED but subtotal_excl_tax > 0 still flows to revenue.
-- Source : silver_ec_orders
-- M1     : reason CANCELLED_WITH_REVENUE | before-count 94 EC orders (~₹6.15 Cr incl. POS).
--          Instructor "~178" = 94 EC + ~84 POS cancelled-incl-tax (defended down to 94 EC).
-- Seed   : sql/_m1_seed/A01_cancelled_revenue__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_rows,
       ROUND(SUM(subtotal_excl_tax), 2) AS revenue_at_risk
FROM silver_ec_orders
WHERE /* TODO: order_status = 'CANCELLED' AND subtotal_excl_tax > 0 */ 1=0;

-- ---------------------------------------------------------------------------
-- A2 — PAYMENT_AFTER_CANCEL                                     [Category A]
-- Desc   : Payment gateway CAPTURE event timestamped after the order's cancellation.
-- Source : silver_pg_transactions + silver_ec_orders (+ status history)
-- M1     : 27 captured on cancelled orders; 26 strictly AFTER cancel ts (~₹1.08 Cr).
-- Seed   : sql/_m1_seed/A02_payment_after_cancel__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_rows,
       ROUND(SUM(amount), 2) AS reversal_liability
FROM silver_pg_transactions p
/* TODO: JOIN silver_ec_orders o ... WHERE capture_ts > o.cancelled_ts */
WHERE 1=0;

-- ---------------------------------------------------------------------------
-- A3 — TAX_INCLUSION_MISMATCH                                   [Category A]
-- Desc   : POS=incl-tax, EC=excl-tax, Marketplace=mixed. Naive cross-channel SUM is wrong.
-- Source : silver_pos_transactions, silver_ec_orders, silver_ts_marketplace_orders
-- M1     : schema-wide (no row flags in M1; net-new detection in M2). ~₹16.25 Cr naive-mix.
-- Seed   : (none — net-new). Detection = show the three bases differ for the same basket.
-- ---------------------------------------------------------------------------
-- TODO: demonstrate the mismatch — e.g. per channel, compare stored amount basis vs a
--       normalised tax-exclusive recomputation; return channels where they diverge.
SELECT 'pos' AS channel, COUNT(*) AS rows_incl_tax FROM silver_pos_transactions WHERE 1=0
UNION ALL
SELECT 'ec' AS channel, COUNT(*) AS rows_excl_tax FROM silver_ec_orders WHERE 1=0;

-- ---------------------------------------------------------------------------
-- A4 — NL_SELLER_SOLD_AS_REVENUE                                [Category A]
-- Desc   : NexaLocal SELLER_SOLD events summed at asking price into confirmed revenue.
-- Source : silver_nl_listing_events, silver_nl_listings
-- M1     : 449 SELLER_SOLD events (~₹1.72 Cr) — must be ESTIMATED, feeds B6 at weight 0.60.
-- Seed   : sql/_m1_seed/A04_seller_sold_estimated__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS seller_sold_events,
       ROUND(SUM(asking_price), 2) AS estimated_gmv_inflation
FROM silver_nl_listing_events
WHERE /* TODO: event_type = 'SELLER_SOLD' */ 1=0;

-- ---------------------------------------------------------------------------
-- A5 — ATP_POSITIVE_PHYSICAL_ZERO                               [Category A]
-- Desc   : Warehouse ATP > 0 while physical_qty = 0 for same SKU/location/date.
-- Source : silver_wh_inventory_snapshots
-- M1     : 5 SKU-date combinations (campaign window).
-- Seed   : sql/_m1_seed/A05_wh_atp_positive_phys_zero__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_rows
FROM silver_wh_inventory_snapshots
WHERE /* TODO: atp_qty > 0 AND physical_qty = 0 */ 1=0;

-- ---------------------------------------------------------------------------
-- A6 — NEGATIVE_QTY                                             [Category A]
-- Desc   : Negative sellable/physical quantity in store snapshots (physically impossible).
-- Source : silver_si_inventory_snapshots
-- M1     : 8 store snapshots.
-- Seed   : sql/_m1_seed/A06_negative_store_inventory__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_rows
FROM silver_si_inventory_snapshots
WHERE /* TODO: sellable_qty < 0 OR physical_qty < 0 */ 1=0;

-- ---------------------------------------------------------------------------
-- A7 — RESTOCK_BEFORE_INSPECTION                                [Category A]
-- Desc   : Returned stock restocked while inspection still PENDING.
-- Source : silver_rr_return_receipts
-- M1     : 10 receipts (inspection_status='PENDING' AND restocked_qty > 0).
-- Seed   : sql/_m1_seed/A07_restocked_before_inspection__ours.sql
-- Note   : distinct from A10 (condition-label predicate). A7 = timing.
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_rows
FROM silver_rr_return_receipts
WHERE /* TODO: inspection_status = 'PENDING' AND restocked_qty > 0 */ 1=0;

-- ---------------------------------------------------------------------------
-- A8 — MISSING_SNAPSHOT_DAY                                     [Category A]
-- Desc   : Stores missing daily snapshot rows (NOT zero inventory — data absent).
-- Source : silver_si_inventory_snapshots
-- M1     : stores 3, 7, 12 each missing 7 days in the 1-7 Aug RAMP-UP (~21 store-days,
--          PRE-campaign). Warehouses gapless. (M1 UNDERSTANDING.md "Aug 1-28" is superseded.)
-- Seed   : sql/_m1_seed/A08_missing_snapshot_days__ours.sql
-- Resolve: reconstruct (last snapshot + intervening transactions); flag RECONSTRUCTED+INFERRED.
-- ---------------------------------------------------------------------------
-- TODO: cross join (distinct store) x (calendar 1-7 Aug) LEFT JOIN snapshots; count missing.
SELECT COUNT(*) AS missing_store_days
FROM ( /* TODO expected grid */ SELECT 1 WHERE 1=0 ) g
LEFT JOIN silver_si_inventory_snapshots s ON 1=0
WHERE s.snapshot_date IS NULL;

-- ---------------------------------------------------------------------------
-- A9 — SKU_PRODUCT_MISMATCH                                     [Category A]
-- Desc   : Same SKU maps to different products across catalogue vs seller feed.
-- Source : silver_product_master (+ marketplace listing source)
-- M1     : 1 (NX-TECH-0001 = laptop in catalogue, phone case in seller feed).
-- Seed   : sql/_m1_seed/A09_sku_title_mismatch__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS conflicting_skus
FROM ( /* TODO: SKUs with >1 distinct canonical product across sources */ SELECT 1 WHERE 1=0 );

-- ---------------------------------------------------------------------------
-- A10 — OPEN_BOX_AS_NEW                                         [Category A]
-- Desc   : Opened-condition returns restocked into the NEW sellable pool.
-- Source : silver_rr_return_receipts
-- M1     : 12 receipts (condition_on_receipt='OPENED' AND restocked_as_condition='NEW').
-- Seed   : sql/_m1_seed/A10_open_box_as_new__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_rows
FROM silver_rr_return_receipts
WHERE /* TODO: condition_on_receipt='OPENED' AND restocked_as_condition='NEW' */ 1=0;

-- ---------------------------------------------------------------------------
-- A11 — PLACEHOLDER_ID_COLLISION                                [Category A]
-- Desc   : Guest placeholder customer_id 9999 collides with a real loyalty customer.
-- Source : silver_customer_master, silver_ec_orders
-- M1     : 178 EC orders on 9999 (all SESS-GUEST-*) + 1 real loyalty (Sarah Chen).
-- Seed   : sql/_m1_seed/A11_customer_9999_collision__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS guest_orders_on_placeholder
FROM silver_ec_orders
WHERE /* TODO: customer_id = '9999' AND session_id LIKE 'SESS-GUEST-%' */ 1=0;

-- ---------------------------------------------------------------------------
-- A12 — RELISTED_AFTER_SOLD                                     [Category A]
-- Desc   : Listing marked SOLD then relisted (same seller, image hash, title/price).
-- Source : silver_nl_listings, silver_nl_listing_events
-- M1     : 3 pairs via image-hash+same-seller (instructor headline "1" via relist_count>0).
-- Seed   : sql/_m1_seed/A12_relist_after_sold__ours.sql
-- Resolve: link pair; exclude original from Estimated GMV; seller_marked_sold_reliability=LOW.
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS relisting_pairs
FROM ( /* TODO: self-join on seller+image_hash where prior status SOLD/EXPIRED */ SELECT 1 WHERE 1=0 );

-- ---------------------------------------------------------------------------
-- A13 — IMAGE_HASH_REUSED (coordinated ring)                    [Category A]
-- Desc   : Same image hash across listings from different seller accounts (+ other signals).
-- Source : silver_nl_listings, silver_nl_listing_events (+ account create times)
-- M1     : hash rings — bb3c... 5 sellers/8 listings; acebc2... 4/5; 76537d... 4/5.
-- Seed   : sql/_m1_seed/A13_image_hash_ring__ours.sql
-- ---------------------------------------------------------------------------
SELECT image_hash,
       COUNT(DISTINCT seller_account_id) AS distinct_sellers,
       COUNT(*) AS listing_count
FROM silver_nl_listings
WHERE image_hash IS NOT NULL
GROUP BY image_hash
HAVING COUNT(DISTINCT seller_account_id) >= 2   -- TODO: layer price/age/contact signals
ORDER BY distinct_sellers DESC;

-- ---------------------------------------------------------------------------
-- A14 — DELIVERY_BEFORE_SHIP                                    [Category A]
-- Desc   : Delivery event timestamp precedes shipment creation/PICKED_UP (clock drift).
-- Source : silver_dc_delivery_events, silver_dc_shipments
-- M1     : 18 strict (DELIVERED < PICKED_UP/SHIPPED); 68 broad (event < created_datetime).
-- Seed   : sql/_m1_seed/A14_delivered_before_shipped__ours.sql
-- Resolve: corrected_ts = PICKED_UP + 36h median; delta > 72h -> REQUIRES_MANUAL_REVIEW.
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_shipments,
       COUNT_IF(/* TODO delta_hours > 72 */ 1=0) AS manual_review_candidates
FROM silver_dc_delivery_events d
/* TODO: JOIN silver_dc_shipments s ... WHERE delivered_ts < shipped_ts */
WHERE 1=0;

-- ---------------------------------------------------------------------------
-- A15 — REVIEW_BEFORE_DELIVERY                                  [Category A]
-- Desc   : Review submitted before the order's delivery confirmation.
-- Source : silver_rv_reviews (+ delivery confirmation)
-- M1     : 25 reviews (days_post_delivery < 0); all set verified_purchase = FALSE.
-- Seed   : sql/_m1_seed/A15_review_before_delivery__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS affected_reviews
FROM silver_rv_reviews
WHERE /* TODO: review_ts < delivery_confirmed_ts */ 1=0;

-- ---------------------------------------------------------------------------
-- A16 — DUPLICATE_CASE                                          [Category A]
-- Desc   : Same complaint logged via multiple channels = inflated complaint volume.
-- Source : silver_cs_cases
-- M1     : 7 cases flagged is_duplicate; dedupe to canonical_case_key.
-- Seed   : sql/_m1_seed/A16_duplicate_cases__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS duplicate_cases
FROM silver_cs_cases
WHERE /* TODO: match on (customer, category, ts proximity) */ 1=0;

-- ===========================================================================
-- CATEGORY B — ambiguous (chosen interpretation noted; defend in report S1)
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- B1 — ATTRIBUTION_SESSION_BRIDGE                               [Category B]
-- Desc   : Promo-less campaign-window orders with a prior BTS2024 UTM session.
-- Choice : ATTRIBUTE the bridged subset (attribution_confidence = 0.85).
-- Source : silver_ec_orders + silver_ws_sessions (+ attribution bridge)
-- M1     : 126 candidate (promo-less, in window) / 102 attributed via 2h UTM bridge.
--          (instructor col-dict quotes 91; anomaly-catalog quotes 102 — note both.)
-- Seed   : sql/_m1_seed/B01_promoless_btsutm__ours.sql
-- ---------------------------------------------------------------------------
SELECT
  COUNT(*) AS candidate_promoless,
  COUNT_IF(/* TODO has prior BTS2024 UTM session within bridge window */ 1=0) AS attributed
FROM silver_ec_orders
WHERE /* TODO: order_date BETWEEN '2024-08-08' AND '2024-08-28' AND promo_code IS NULL */ 1=0;

-- ---------------------------------------------------------------------------
-- B2 — PARTIAL_REFUND_PERIOD                                    [Category B]
-- Desc   : Aug sale, Sep partial refund (80%, 20% restocking fee) — which period?
-- Choice : recognise the reversal in the RETURN period (Sep), GAAP-style.
-- Source : silver_rr_refund_events (+ original sale)
-- M1     : 1 refund (~₹2.16 L). (No seed — net-new detection.)
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS cross_period_partial_refunds,
       ROUND(SUM(refund_amount), 2) AS reversal_amount
FROM silver_rr_refund_events
WHERE /* TODO: is_partial AND original_sale_month <> refund_month */ 1=0;

-- ---------------------------------------------------------------------------
-- B3 — MOVEMENT_NULL_REF                                        [Category B]
-- Desc   : Inventory decrement movements with no reference order number.
-- Choice : classify as probable missing-reference (INFERRED), not error/shrinkage.
-- Source : silver_wh_inventory_movements
-- M1     : 175 (all movement_type='PCK').
-- Seed   : sql/_m1_seed/B03_wh_null_ref_movements__ours.sql
-- ---------------------------------------------------------------------------
SELECT movement_type, COUNT(*) AS null_ref_movements
FROM silver_wh_inventory_movements
WHERE /* TODO: reference_order_number IS NULL */ 1=0
GROUP BY movement_type;

-- ---------------------------------------------------------------------------
-- B4 — LISTING_LOW_CONFIDENCE (catalogue match)                 [Category B]
-- Desc   : NexaLocal free-text titles matched to catalogue with a confidence score.
-- Choice : match >= 0.75; 0.65-0.75 manual review; < 0.65 leave unmatched.
-- Source : silver_nl_listings, silver_product_master
-- M1     : threshold call. (No seed — net-new; matching done in T5/PySpark.)
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS listings_below_match_threshold
FROM silver_nl_listings
WHERE /* TODO: best_match_confidence < 0.75 */ 1=0;

-- ---------------------------------------------------------------------------
-- B5 — IDENTITY_AMBIGUOUS (cross-channel)                       [Category B]
-- Desc   : Same person across loyalty/EC/NL/guest with no shared exact key.
-- Choice : probabilistic merge at confidence >= 0.90 (Identity Confidence Score).
-- Source : silver_customer_master (+ source contact records)
-- M1     : 1 (0.92 confidence). (No seed — net-new; resolution in T4/PySpark.)
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS probabilistic_merge_candidates
FROM ( /* TODO: candidate pairs with 0.70 <= score < 1.00 */ SELECT 1 WHERE 1=0 );

-- ---------------------------------------------------------------------------
-- B6 — ESTIMATED_NL_GMV                                         [Category B]
-- Desc   : Modelled Estimated Classified GMV (no single correct formula).
-- Choice : SELLER_SOLD*0.60 + PHN_REVEAL*0.15 + CHAT*0.08 + OFFER_ACC*0.30, x confidence, +/-35% band.
-- Source : silver_nl_listing_events
-- M1     : campaign listings. ESTIMATED only. (No seed — model in PySpark; this query inspects signals.)
-- ---------------------------------------------------------------------------
SELECT event_type, COUNT(*) AS event_count
FROM silver_nl_listing_events
WHERE /* TODO: event_type IN ('SELLER_SOLD','PHN_REVEAL','CHAT','OFFER_ACC') AND campaign window */ 1=0
GROUP BY event_type;

-- ---------------------------------------------------------------------------
-- B7 — BOPIS_NO_PICKUP_EVENT                                    [Category B]
-- Desc   : BOPIS orders marked Completed with no pickup confirmation event.
-- Choice : treat as fulfilled (scan miss); flag collection_unconfirmed = TRUE.
-- Source : silver_dc_delivery_events, silver_ec_orders
-- M1     : 25 (READY_FOR_PICKUP present, BOPIS_COLLECTED absent).
-- Seed   : sql/_m1_seed/B07_bopis_pickup_gap__ours.sql
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS bopis_completed_without_pickup
FROM silver_ec_orders o
/* TODO: anti-join silver_dc_delivery_events for BOPIS_COLLECTED */
WHERE /* TODO: delivery_method='BOPIS' AND order_status='DELIVERED' */ 1=0;

-- ---------------------------------------------------------------------------
-- B8 — SELLER_HIGH_RISK (trust composite)                       [Category B]
-- Desc   : Composite seller trust score -> 5 risk tiers (equal-weight is unacceptable).
-- Choice : weighted composite (cancellation, late-fulfil, return, complaints/100, NL dup,
--          NL report, response rate, moderation) -> UNDER_REVIEW for flagged sellers.
-- Source : silver_ts_sellers (+ orders, returns, cases, NL signals)
-- M1     : flagged high-risk sellers -> UNDER_REVIEW. (No seed — score in PySpark.)
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS sellers_under_review
FROM silver_ts_sellers
WHERE /* TODO: composite_trust_score below tier threshold */ 1=0;

-- ###########################################################################
-- POST-RESOLUTION RE-RUN: after notebook 05 writes corrected Silver, re-run every
-- block above. Expected: all -> 0 EXCEPT A14 (residual = >72h manual-review rows)
-- and B-series (which carry classification labels rather than zeroing out).
-- ###########################################################################
