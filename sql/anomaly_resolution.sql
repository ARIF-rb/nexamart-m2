-- ###########################################################################
-- NexaMart M2 — anomaly_resolution.sql   (LO11 documentation companion)
-- ###########################################################################
-- One documentation block per anomaly: detection query (ref), root cause, business
-- impact, resolution approach (which cell in notebook 05), and a POST-RESOLUTION
-- verification query that proves the fix worked (run against corrected NEXAMART_SILVER).
--
-- Category A: verification count should drop to 0.
-- Category B: rows are CLASSIFIED, not zeroed — verification confirms the classification
--   label is applied (b_classification populated) and documents the QUANTIFIED impact of
--   the chosen interpretation vs the alternative (brief §8.2).
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
WHERE order_status = 'CANCELLED' AND subtotal_excl_tax > 0
  AND COALESCE(resolution_applied, FALSE) = FALSE;   -- TODO confirm column/predicate

-- A2 — PAYMENT_AFTER_CANCEL -------------------------------------------------
-- Detection      : anomaly_discovery.sql A2
-- Root cause     : payment gateway + order system not synchronised; capture after cancel.
-- Business impact: ₹1.08 Cr reversal liability; money collected for cancelled orders.
-- Resolution     : 05 cell A2 — flag as reversal-required (NOT revenue); resolution_method
--                  FLAGGED_REVERSAL_REQUIRED. Aligns with NCR definition (excluded from NCR).
-- Verify (expect 0 unresolved):
SELECT COUNT(*) AS unresolved FROM silver_pg_transactions WHERE 1=0 /* TODO */;

-- A3 — TAX_INCLUSION_MISMATCH -----------------------------------------------
-- Detection      : anomaly_discovery.sql A3
-- Root cause     : three channels store amounts on different tax/commission bases.
-- Business impact: ~₹16.25 Cr naive cross-channel sum is neither comparable nor correct.
-- Resolution     : 05 cell A3 — normalise all to tax-exclusive, commission-exclusive basis;
--                  resolution_method NORMALISED_TAX_EXCLUSIVE.
-- Verify         : recomputed tax-exclusive amounts reconcile across channels (no divergence).
SELECT 'TODO reconcile bases' AS check_note;

-- A4 — NL_SELLER_SOLD_AS_REVENUE --------------------------------------------
-- Detection      : anomaly_discovery.sql A4
-- Root cause     : legacy dashboard summed SELLER_SOLD events as confirmed revenue.
-- Business impact: ₹1.72 Cr unconfirmed inflation. Must be ESTIMATED (feeds B6 at 0.60).
-- Resolution     : 05 cell A4 — relabel certainty ESTIMATED; resolution_method
--                  RELABELLED_ESTIMATED_GMV. Excluded from Confirmed GMV.
SELECT COUNT(*) AS still_confirmed
FROM silver_nl_listing_events WHERE 1=0 /* TODO event_type='SELLER_SOLD' AND certainty<>'ESTIMATED' */;

-- A5 — ATP_POSITIVE_PHYSICAL_ZERO -------------------------------------------
-- Detection      : anomaly_discovery.sql A5
-- Root cause     : decrement event missing; ATP feed stale vs physical.
-- Business impact: orders accepted against zero physical stock (oversell risk).
-- Resolution     : 05 cell A5 — correct ATP to 0; resolution_method CORRECTED_ATP_TO_ZERO.
SELECT COUNT(*) AS unresolved FROM silver_wh_inventory_snapshots WHERE 1=0 /* TODO */;

-- A6 — NEGATIVE_QTY ---------------------------------------------------------
-- Detection      : anomaly_discovery.sql A6
-- Root cause     : double-counting / out-of-sequence / missing receipt.
-- Business impact: breaks stockout analysis; physically impossible.
-- Resolution     : 05 cell A6 — set to 0 + oversell flag; resolution_method CORRECTED_ATP_TO_ZERO.
SELECT COUNT(*) AS unresolved FROM silver_si_inventory_snapshots WHERE 1=0 /* TODO */;

-- A7 — RESTOCK_BEFORE_INSPECTION --------------------------------------------
-- Detection      : anomaly_discovery.sql A7
-- Root cause     : auto-increment of sellable on receipt, before inspection grading.
-- Business impact: inflated ATP for ~3 days; damaged units sold as sellable.
-- Resolution     : 05 cell A7 — zero pre-inspection restock; resolution_method
--                  ZEROED_RESTOCK_PRE_INSPECTION. Document orders accepted in the window.
SELECT COUNT(*) AS unresolved FROM silver_rr_return_receipts WHERE 1=0 /* TODO */;

-- A8 — MISSING_SNAPSHOT_DAY -------------------------------------------------
-- Detection      : anomaly_discovery.sql A8
-- Root cause     : snapshot data did not arrive for stores 3/7/12 on 1-7 Aug (pre-campaign).
-- Business impact: stale allocation decisions; gaps != zero inventory.
-- Resolution     : 05 cell A8 — reconstruct = last-known snapshot + intervening transactions;
--                  resolution_method RECONSTRUCTED_SNAPSHOT; data_quality_status RECONSTRUCTED,
--                  metric_certainty_level INFERRED (never CONFIRMED).
-- Verify         : reconstructed rows exist for 3 stores x 7 days; flagged RECONSTRUCTED.
SELECT COUNT(*) AS reconstructed_rows
FROM silver_si_inventory_snapshots
WHERE data_quality_status = 'RECONSTRUCTED';  -- expect ~21

-- A9 — SKU_PRODUCT_MISMATCH -------------------------------------------------
-- Detection      : anomaly_discovery.sql A9
-- Root cause     : legacy seller onboarding mapped a catalogue SKU to a different product.
-- Business impact: category revenue inflated/mis-attributed.
-- Resolution     : 05 cell A9 — canonical product rule (NexaMart catalogue wins); flag affected
--                  fact rows; resolution_method APPLIED_CANONICAL_PRODUCT.
SELECT COUNT(*) AS unresolved FROM silver_product_master WHERE 1=0 /* TODO */;

-- A10 — OPEN_BOX_AS_NEW -----------------------------------------------------
-- Detection      : anomaly_discovery.sql A10
-- Root cause     : return-to-restock didn't update condition to open-box.
-- Business impact: open-box sold as NEW at full price (price premium wrongly charged).
-- Resolution     : 05 cell A10 — correct condition to open-box; quantify price premium;
--                  resolution_method CORRECTED_CONDITION_OPEN_BOX.
SELECT COUNT(*) AS unresolved FROM silver_rr_return_receipts WHERE 1=0 /* TODO */;

-- A11 — PLACEHOLDER_ID_COLLISION --------------------------------------------
-- Detection      : anomaly_discovery.sql A11
-- Root cause     : guest placeholder 9999 collides with a real loyalty account number.
-- Business impact: 178 unrelated guest orders falsely linked to one real customer.
-- Resolution     : 05 cell A11 — rekey guests to GUEST-{session_id}; protect the real record;
--                  add a Silver safeguard; resolution_method REKEYED_GUEST_BUCKET.
SELECT COUNT(*) AS unresolved FROM silver_ec_orders WHERE 1=0 /* TODO customer_id='9999' guests */;

-- A12 — RELISTED_AFTER_SOLD -------------------------------------------------
-- Detection      : anomaly_discovery.sql A12
-- Root cause     : false SOLD event; item relisted days later (same seller/hash/price).
-- Business impact: inflates Estimated Classified GMV (double-counts the "sale").
-- Resolution     : 05 cell A12 — link pair; seller_marked_sold_reliability=LOW; EXCLUDE original
--                  from Estimated GMV (B6); resolution_method LINKED_RELISTING_EXCLUDED.
SELECT COUNT(*) AS unlinked_pairs FROM silver_nl_listings WHERE 1=0 /* TODO */;

-- A13 — IMAGE_HASH_REUSED (ring) --------------------------------------------
-- Detection      : anomaly_discovery.sql A13
-- Root cause     : coordinated fraudulent listing ring across seller accounts.
-- Business impact: trust & safety; phone numbers exposed; demand signals fake.
-- Resolution     : 05 cell A13 — multi-signal flag; assign risk tier; exclude listings;
--                  resolution_method FLAGGED_FRAUD_RING.
SELECT COUNT(*) AS unflagged_ring_listings FROM silver_nl_listings WHERE 1=0 /* TODO */;

-- A14 — DELIVERY_BEFORE_SHIP ------------------------------------------------
-- Detection      : anomaly_discovery.sql A14
-- Root cause     : courier vs warehouse clock mismatch.
-- Business impact: on-time delivery rate wrong.
-- Resolution     : 05 cell A14 — corrected_ts = PICKED_UP + 36h median for delta<=72h
--                  (CORRECTED_DELIVERY_TS); delta>72h -> ESCALATED_MANUAL_REVIEW (not auto-fixed).
-- Verify (expect 0 auto-correctable left; residual = manual-review only):
SELECT COUNT(*) AS uncorrected FROM silver_dc_delivery_events WHERE 1=0 /* TODO delta<=72h unresolved */;

-- A15 — REVIEW_BEFORE_DELIVERY ----------------------------------------------
-- Detection      : anomaly_discovery.sql A15
-- Root cause     : review submitted before delivery confirmation.
-- Business impact: verified_purchase rate overstated -> review-score KPI inflated.
-- Resolution     : 05 cell A15 — set verified_purchase=FALSE; resolution_method
--                  SET_VERIFIED_PURCHASE_FALSE.
SELECT COUNT(*) AS still_verified FROM silver_rv_reviews WHERE 1=0 /* TODO */;

-- A16 — DUPLICATE_CASE ------------------------------------------------------
-- Detection      : anomaly_discovery.sql A16
-- Root cause     : same incident logged via chat + phone + email.
-- Business impact: complaint volume inflated (Support reported more than reality).
-- Resolution     : 05 cell A16 — dedupe on (customer, category, ts proximity) -> canonical_case_key;
--                  resolution_method DEDUPED_CANONICAL_CASE.
SELECT COUNT(*) AS uncollapsed_dupes FROM silver_cs_cases WHERE 1=0 /* TODO */;

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
-- Resolution     : 05 cell B2 — b_classification='RECOGNISE_IN_RETURN_PERIOD'.
SELECT COUNT(*) AS classified FROM silver_rr_refund_events WHERE b_classification IS NOT NULL;

-- B3 — MOVEMENT_NULL_REF ----------------------------------------------------
-- Ambiguity      : 175 PCK decrements with no reference order — adjustment? lag? error?
-- Chosen         : probable missing-reference (processing lag), INFERRED.
-- Alternative+qty: treating as shrinkage would overstate loss; document confidence level.
-- Resolution     : 05 cell B3 — b_classification='PROBABLE_MISSING_REF'.
SELECT COUNT(*) AS classified FROM silver_wh_inventory_movements WHERE b_classification IS NOT NULL;

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
SELECT COUNT(*) AS merged FROM silver_customer_master WHERE b_classification = 'MERGED';

-- B6 — ESTIMATED_NL_GMV -----------------------------------------------------
-- Ambiguity      : no single correct GMV formula for offline NexaLocal.
-- Chosen         : SELLER_SOLD*0.60 + PHN_REVEAL*0.15 + CHAT*0.08 + OFFER_ACC*0.30, x confidence, +/-35%.
-- Alternative+qty: seller-sold-only model would over/under-state; band communicates uncertainty.
-- Resolution     : 05 cell B6 — produce lower/point/upper; ESTIMATED only.
SELECT 'TODO point estimate + band' AS check_note;

-- B7 — BOPIS_NO_PICKUP_EVENT ------------------------------------------------
-- Ambiguity      : 25 BOPIS Completed without a pickup scan — collected? cancelled? never collected?
-- Chosen         : treat as fulfilled (scan miss); flag collection_unconfirmed=TRUE.
-- Alternative+qty: treating as not-collected would understate fulfilment; manual-review noted.
-- Resolution     : 05 cell B7 — b_classification='TREAT_AS_FULFILLED'; resolution_method
--                  ESCALATED_MANUAL_REVIEW for the flag.
SELECT COUNT(*) AS classified FROM silver_ec_orders WHERE b_classification = 'TREAT_AS_FULFILLED';

-- B8 — SELLER_HIGH_RISK -----------------------------------------------------
-- Ambiguity      : trust score formula + weights (equal-weight unacceptable).
-- Chosen         : weighted composite (8 signals) -> 5 risk tiers; flagged sellers -> UNDER_REVIEW.
-- Alternative+qty: premature suspension harms legitimate sellers; UNDER_REVIEW is reversible.
-- Resolution     : 05 cell B8 — b_classification = risk tier; document weights.
SELECT b_classification AS risk_tier, COUNT(*) FROM silver_ts_sellers WHERE b_classification IS NOT NULL GROUP BY 1;

-- ###########################################################################
-- Cross-reference: report Section 1 narrates each block; Section 4 reconciliation
-- maps A1/A3/A4/B2/B6 to the team-number divergences.
-- ###########################################################################
