-- ###########################################################################
-- NexaMart M2 — anomaly_resolution.sql   (LO11 documentation companion)
-- ###########################################################################
-- One documentation block per anomaly: detection query (ref), root cause, business
-- impact, resolution approach (which cell in notebook 05), and a POST-RESOLUTION
-- verification query that proves the fix worked (run against corrected NEXAMART_SILVER).
--
-- Category A: verification count should drop to 0 (A14 keeps a >72h manual-review residual).
-- Category B: rows are CLASSIFIED, not zeroed — verification confirms the classification
--   label is applied (b_classification populated) and documents the QUANTIFIED impact of
--   the chosen interpretation vs the alternative (brief §8.2).
--
-- Verify patterns: where the fix changes the detecting column we re-run the data predicate
-- (-> 0); where the fix only flags/relabels we count flagged rows still missing
-- resolution_applied (-> 0). Run after notebook 05 writes corrected Silver.
--
-- Resolution audit contract (every corrected row): anomaly_flag stays TRUE, original
-- anomaly_reason_code retained, + resolution_applied=TRUE + resolution_method (+ b_classification).
-- ###########################################################################

USE ROLE NEXAMART_ENGINEER;
USE WAREHOUSE NEXAMART_WH;
USE DATABASE NEXAMART_DW;
USE SCHEMA NEXAMART_SILVER;

-- ===========================================================================
-- CATEGORY A
-- ===========================================================================

-- A1 — CANCELLED_WITH_REVENUE -----------------------------------------------
-- Detection      : anomaly_discovery.sql A1
-- Root cause     : revenue column not zeroed when order_status set to CANCELLED.
-- Business impact: Sales over-counted revenue by ₹6.15 Cr (94 EC orders); explains Sales +34%.
-- Resolution     : 05 cell A1 — zero subtotal_excl_tax on cancelled rows; resolution_method
--                  ZEROED_CANCELLED_REVENUE; flag retained.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_ec_orders
WHERE order_status = 'CANCELLED' AND subtotal_excl_tax > 0;

-- A2 — PAYMENT_AFTER_CANCEL -------------------------------------------------
-- Detection      : anomaly_discovery.sql A2
-- Root cause     : payment gateway + order system not synchronised; capture after cancel.
-- Business impact: ₹1.08 Cr reversal liability; money collected for cancelled orders.
-- Resolution     : 05 cell A2 — flag as reversal-required (NOT revenue); resolution_method
--                  FLAGGED_REVERSAL_REQUIRED. Aligns with NCR definition (excluded from NCR).
-- Verify (expect 0 — every flagged payment carries a resolution):
SELECT COUNT(*) AS unresolved
FROM silver_pg_transactions
WHERE anomaly_reason_code LIKE '%PAYMENT_AFTER_CANCEL%'
  AND COALESCE(resolution_applied, FALSE) = FALSE;

-- A3 — TAX_INCLUSION_MISMATCH -----------------------------------------------
-- Detection      : anomaly_discovery.sql A3
-- Root cause     : three channels store amounts on different tax/commission bases.
-- Business impact: ~₹16.25 Cr naive cross-channel sum is neither comparable nor correct.
-- Resolution     : 05 cell A3 — derive revenue_excl_tax on POS (tax-exclusive basis);
--                  resolution_method NORMALISED_TAX_EXCLUSIVE. EC is already tax-exclusive.
-- Verify (expect 0 — every POS row normalised to a tax-exclusive measure):
SELECT COUNT(*) AS unnormalised
FROM silver_pos_transactions
WHERE anomaly_reason_code LIKE '%TAX_INCLUSION_MISMATCH%'
  AND COALESCE(resolution_applied, FALSE) = FALSE;

-- A4 — NL_SELLER_SOLD_AS_REVENUE --------------------------------------------
-- Detection      : anomaly_discovery.sql A4
-- Root cause     : legacy dashboard summed SELLER_SOLD events as confirmed revenue.
-- Business impact: ₹1.72 Cr unconfirmed inflation. Must be ESTIMATED (feeds B6 at 0.60).
-- Resolution     : 05 cell A4 — relabel certainty ESTIMATED; resolution_method
--                  RELABELLED_ESTIMATED_GMV. Excluded from Confirmed GMV.
-- Verify (expect 0 — no SELLER_SOLD event still counted as anything but ESTIMATED):
SELECT COUNT(*) AS still_confirmed
FROM silver_nl_listing_events
WHERE event_type_code = 'SELLER_SOLD' AND metric_certainty_level <> 'ESTIMATED';

-- A5 — ATP_POSITIVE_PHYSICAL_ZERO -------------------------------------------
-- Detection      : anomaly_discovery.sql A5
-- Root cause     : decrement event missing; ATP feed stale vs physical.
-- Business impact: orders accepted against zero physical stock (oversell risk).
-- Resolution     : 05 cell A5 — correct ATP to 0; resolution_method CORRECTED_ATP_TO_ZERO.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_wh_inventory_snapshots
WHERE atp_qty > 0 AND physical_qty = 0;

-- A6 — NEGATIVE_QTY ---------------------------------------------------------
-- Detection      : anomaly_discovery.sql A6
-- Root cause     : double-counting / out-of-sequence / missing receipt.
-- Business impact: breaks stockout analysis; physically impossible.
-- Resolution     : 05 cell A6 — set to 0 + oversell flag; resolution_method CORRECTED_ATP_TO_ZERO.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_si_inventory_snapshots
WHERE sellable_qty < 0 OR physical_qty < 0;

-- A7 — RESTOCK_BEFORE_INSPECTION --------------------------------------------
-- Detection      : anomaly_discovery.sql A7
-- Root cause     : auto-increment of sellable on receipt, before inspection grading.
-- Business impact: inflated ATP for ~3 days; damaged units sold as sellable.
-- Resolution     : 05 cell A7 — zero pre-inspection restock; resolution_method
--                  ZEROED_RESTOCK_PRE_INSPECTION. Document orders accepted in the window.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_rr_return_receipts
WHERE inspection_status = 'PENDING' AND restocked_qty > 0;

-- A8 — MISSING_SNAPSHOT_DAY -------------------------------------------------
-- Detection      : anomaly_discovery.sql A8
-- Root cause     : snapshot data did not arrive for stores 3/7/12 on 1-7 Aug (pre-campaign).
-- Business impact: stale allocation decisions; gaps != zero inventory.
-- Resolution     : 05 cell A8 — reconstruct (last-known + intervening transactions) into the
--                  sibling silver_store_inventory_snapshots_reconstructed; resolution_method
--                  RECONSTRUCTED_SNAPSHOT; data_quality_status RECONSTRUCTED, certainty INFERRED.
-- Verify (expect ~21 reconstructed store-days, all resolution-stamped):
SELECT COUNT(*) AS reconstructed_rows
FROM silver_store_inventory_snapshots_reconstructed
WHERE data_quality_status = 'RECONSTRUCTED'
  AND COALESCE(resolution_applied, FALSE) = TRUE;

-- A9 — SKU_PRODUCT_MISMATCH -------------------------------------------------
-- Detection      : anomaly_discovery.sql A9
-- Root cause     : legacy seller onboarding mapped a catalogue SKU to a different product.
-- Business impact: category revenue inflated/mis-attributed.
-- Resolution     : 05 cell A9 — canonical product rule (NexaMart catalogue wins) on
--                  silver_ts_seller_listings; resolution_method APPLIED_CANONICAL_PRODUCT.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_ts_seller_listings
WHERE listing_id = 42 AND nexamart_sku_ref = 'NX-TECH-0001'
  AND COALESCE(resolution_applied, FALSE) = FALSE;

-- A10 — OPEN_BOX_AS_NEW -----------------------------------------------------
-- Detection      : anomaly_discovery.sql A10
-- Root cause     : return-to-restock didn't update condition to open-box.
-- Business impact: open-box sold as NEW at full price (price premium wrongly charged).
-- Resolution     : 05 cell A10 — correct condition to OPEN_BOX; quantify price premium;
--                  resolution_method CORRECTED_CONDITION_OPEN_BOX.
-- Verify (expect 0 — corrected condition no longer NEW):
SELECT COUNT(*) AS unresolved
FROM silver_rr_return_receipts
WHERE condition_on_receipt = 'OPENED' AND restocked_as_condition = 'NEW';

-- A11 — PLACEHOLDER_ID_COLLISION --------------------------------------------
-- Detection      : anomaly_discovery.sql A11
-- Root cause     : guest placeholder 9999 collides with a real loyalty account number.
-- Business impact: 178 unrelated guest orders falsely linked to one real customer.
-- Resolution     : 05 cell A11 — rekey guests to GUEST-{session_id}; resolution_method
--                  REKEYED_GUEST_BUCKET.
-- Verify (expect 0 — no order left on the 9999 placeholder):
SELECT COUNT(*) AS unresolved
FROM silver_ec_orders
WHERE customer_id = '9999';

-- A12 — RELISTED_AFTER_SOLD -------------------------------------------------
-- Detection      : anomaly_discovery.sql A12
-- Root cause     : false SOLD event; item relisted days later (same seller/hash/price).
-- Business impact: inflates Estimated Classified GMV (double-counts the "sale").
-- Resolution     : 05 cell A12 — link pair; relisting_reliability=LOW; excluded_from_gmv=TRUE;
--                  resolution_method LINKED_RELISTING_EXCLUDED.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_nl_listings
WHERE anomaly_reason_code LIKE '%RELISTED_AFTER_SOLD%'
  AND COALESCE(resolution_applied, FALSE) = FALSE;

-- A13 — IMAGE_HASH_REUSED (ring) --------------------------------------------
-- Detection      : anomaly_discovery.sql A13
-- Root cause     : coordinated fraudulent listing ring across seller accounts.
-- Business impact: trust & safety; phone numbers exposed; demand signals fake.
-- Resolution     : 05 cell A13 — multi-signal flag; fraud_ring_flag=TRUE; resolution_method
--                  FLAGGED_FRAUD_RING.
-- Verify (expect 0):
SELECT COUNT(*) AS unresolved
FROM silver_nl_listings
WHERE anomaly_reason_code LIKE '%IMAGE_HASH_REUSED%'
  AND COALESCE(resolution_applied, FALSE) = FALSE;

-- A14 — DELIVERY_BEFORE_SHIP ------------------------------------------------
-- Detection      : anomaly_discovery.sql A14
-- Root cause     : courier vs warehouse clock mismatch.
-- Business impact: on-time delivery rate wrong.
-- Resolution     : 05 cell A14 — corrected_event_datetime = pickup_ts + 36h for |delta|<=72h
--                  (CORRECTED_DELIVERY_TS); |delta|>72h -> ESCALATED_MANUAL_REVIEW (not auto-fixed).
-- Verify (expect 0 auto-correctable left; residual = >72h manual-review only):
SELECT COUNT(*) AS uncorrected
FROM silver_dc_delivery_events
WHERE event_type_code = 'DELIVERED' AND delivered_ts < pickup_ts
  AND ABS(DATEDIFF('hour', pickup_ts, delivered_ts)) <= 72
  AND COALESCE(resolution_method, '') <> 'CORRECTED_DELIVERY_TS';

-- A15 — REVIEW_BEFORE_DELIVERY ----------------------------------------------
-- Detection      : anomaly_discovery.sql A15
-- Root cause     : review submitted before delivery confirmation.
-- Business impact: verified_purchase rate overstated -> review-score KPI inflated.
-- Resolution     : 05 cell A15 — set is_verified_purchase=FALSE; resolution_method
--                  SET_VERIFIED_PURCHASE_FALSE.
-- Verify (expect 0):
SELECT COUNT(*) AS still_verified
FROM silver_rv_reviews
WHERE days_post_delivery < 0 AND COALESCE(is_verified_purchase, 1) <> 0;

-- A16 — DUPLICATE_CASE ------------------------------------------------------
-- Detection      : anomaly_discovery.sql A16
-- Root cause     : same incident logged via chat + phone + email.
-- Business impact: complaint volume inflated (Support reported more than reality).
-- Resolution     : 05 cell A16 — resolve on is_duplicate_flag -> canonical_case_key; downstream
--                  KPIs count DISTINCT canonical_case_key; resolution_method DEDUPED_CANONICAL_CASE.
-- Verify (expect 0 — every duplicate case resolved):
SELECT COUNT(*) AS unresolved
FROM silver_cs_cases
WHERE is_duplicate_flag = TRUE
  AND COALESCE(resolution_applied, FALSE) = FALSE;

-- ===========================================================================
-- CATEGORY B — decision + DEFENCE + quantified alternative (brief §8.2)
-- ===========================================================================

-- B1 — ATTRIBUTION_SESSION_BRIDGE -------------------------------------------
-- Ambiguity      : promo-less in-window order with prior BTS2024 UTM session; post-window delivery.
-- Chosen         : ATTRIBUTE the 102 bridged orders (attribution_confidence=0.85).
-- Alternative+qty: NOT attributing would understate campaign revenue by ~₹1.11 Cr.
-- Resolution     : 05 cell B1 — b_classification='ATTRIBUTED'; resolution_method B_DECISION_APPLIED.
SELECT COUNT(*) AS classified FROM silver_ec_orders WHERE b_classification = 'ATTRIBUTED';  -- expect 102

-- B2 — PARTIAL_REFUND_PERIOD ------------------------------------------------
-- Ambiguity      : Aug sale, Sep partial refund — recognise reversal in Aug or Sep?
-- Chosen         : RETURN period (Sep), GAAP-style matching to the refund event.
-- Alternative+qty: original-period recognition would reduce campaign-month NCR by ~₹2.16 L.
-- Resolution     : 05 cell B2 — b_classification='RECOGNISE_IN_RETURN_PERIOD'; both period impacts exposed.
SELECT COUNT(*) AS classified FROM silver_rr_refund_events WHERE b_classification = 'RECOGNISE_IN_RETURN_PERIOD';  -- expect 1

-- B3 — MOVEMENT_NULL_REF ----------------------------------------------------
-- Ambiguity      : 175 PCK decrements with no reference order — adjustment? lag? error?
-- Chosen         : probable missing-reference (processing lag), INFERRED.
-- Alternative+qty: treating as shrinkage would overstate loss; document confidence level.
-- Resolution     : 05 cell B3 — b_classification='PROBABLE_MISSING_REF'.
SELECT COUNT(*) AS classified FROM silver_wh_inventory_movements WHERE b_classification = 'PROBABLE_MISSING_REF';  -- expect 175

-- B4 — LISTING_LOW_CONFIDENCE -----------------------------------------------
-- Ambiguity      : free-text NexaLocal titles -> catalogue match threshold.
-- Chosen         : match>=0.75; 0.65-0.75 manual review; <0.65 unmatched (avoid false matches).
-- Alternative+qty: lower threshold matches more but injects mis-linked demand signals.
-- Resolution     : 05 cell B4 — b_classification in {MATCHED, MANUAL_REVIEW, UNMATCHED}.
SELECT b_classification, COUNT(*) FROM silver_nl_listings WHERE b_classification IS NOT NULL GROUP BY 1;

-- B5 — IDENTITY_AMBIGUOUS ---------------------------------------------------
-- Ambiguity      : same person across channels, no shared exact key.
-- Chosen         : probabilistic merge at Identity Confidence Score >= 0.90.
-- Alternative+qty: 0.70 threshold over-merges distinct customers; 0.90 is conservative.
-- Resolution     : 05 cell B5 — b_classification='MERGED' for >=0.90.
SELECT COUNT(*) AS merged FROM silver_customer_master WHERE b_classification = 'MERGED';  -- expect 1

-- B6 — ESTIMATED_NL_GMV -----------------------------------------------------
-- Ambiguity      : no single correct GMV formula for offline NexaLocal.
-- Chosen         : SELLER_SOLD*0.60 + PHN_REVEAL*0.15 + CHAT*0.08 + OFFER_ACC*0.30, x confidence, +/-35%.
-- Alternative+qty: seller-sold-only model would over/under-state; band communicates uncertainty.
-- Resolution     : 05 cell B6 — label signal events ESTIMATED_NL_GMV; point + band in the KPI view.
SELECT COUNT(*) AS estimated_events,
       ROUND(SUM(offer_amount), 2) AS signal_amount
FROM silver_nl_listing_events
WHERE anomaly_reason_code LIKE '%ESTIMATED_NL_GMV%'
  AND metric_certainty_level = 'ESTIMATED';

-- B7 — BOPIS_NO_PICKUP_EVENT ------------------------------------------------
-- Ambiguity      : 25 BOPIS Completed without a pickup scan — collected? cancelled? never collected?
-- Chosen         : treat as fulfilled (scan miss, ~13% baseline); flag collection_unconfirmed=TRUE.
-- Alternative+qty: treating as not-collected would understate fulfilment; excluded from BOPIS SLA.
-- Resolution     : 05 cell B7 — b_classification='TREAT_AS_FULFILLED'; resolution_method B_DECISION_APPLIED.
SELECT COUNT(*) AS classified FROM silver_ec_orders WHERE b_classification = 'TREAT_AS_FULFILLED';  -- expect 25

-- B8 — SELLER_HIGH_RISK -----------------------------------------------------
-- Ambiguity      : trust score formula + weights (equal-weight unacceptable).
-- Chosen         : weighted composite (8 signals) -> 5 risk tiers; flagged sellers -> UNDER_REVIEW.
-- Alternative+qty: premature suspension harms legitimate sellers; UNDER_REVIEW is reversible.
-- Resolution     : 05 cell B8 — b_classification = risk tier; document weights in report S7.
SELECT b_classification AS risk_tier, COUNT(*) FROM silver_ts_sellers WHERE b_classification IS NOT NULL GROUP BY 1;

-- ###########################################################################
-- Cross-reference: report Section 1 narrates each block; Section 4 reconciliation
-- maps A1/A3/A4/B2/B6 to the team-number divergences.
-- ###########################################################################
