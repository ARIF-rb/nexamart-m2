-- ###########################################################################
-- NexaMart M2 — kpi_views.sql   (LO12 — KPI View Design)
-- ###########################################################################
-- All KPI views live in NEXAMART_MARTS. The dashboard connects to THIS schema ONLY.
--
-- MANDATORY on every view:
--   * a metric_certainty_level column (CONFIRMED / INFERRED / ESTIMATED)
--   * a business_definition comment block in the DDL (the comment lines above each view)
-- MANDATORY on every FINANCE-domain view (Check 9):
--   * an is_confirmed_transaction boolean column
-- RULES:
--   * Never mix ESTIMATED and CONFIRMED in the same numeric column.
--   * Estimated Classified GMV is a SEPARATE view with lower/point/upper band columns.
--   * ATP is SEMI-ADDITIVE — never SUM across dates (see vw_atp_sku_loc_date).
--
-- 28 KPIs: 8 Finance, 6 Inventory, 8 Ecommerce/Store, 6 NexaLocal/Seller.
-- Replace every `/* TODO */` with the real SELECT against NEXAMART_GOLD.
-- ###########################################################################

USE ROLE NEXAMART_ENGINEER;
USE WAREHOUSE NEXAMART_WH;
USE DATABASE NEXAMART_DW;
USE SCHEMA NEXAMART_MARTS;

-- ===========================================================================
-- FINANCE  (owners: M5 + M2 + Lead)   — all carry is_confirmed_transaction
-- ===========================================================================

-- vw_gsv — Gross Sale Value | Certainty: CONFIRMED | Owner: M5
-- business_definition: Sum of transaction values at completion, before any deductions
--   (price + tax + shipping), across all channels with a confirmed transaction event.
CREATE OR REPLACE VIEW vw_gsv AS
SELECT /* TODO: channel, period, */
       /* SUM(gross_sale_amount) AS gsv, */
       TRUE AS is_confirmed_transaction,
       'CONFIRMED' AS metric_certainty_level
FROM NEXAMART_GOLD.fact_ecommerce_order_line  /* TODO + fact_store_sale_line + marketplace */
WHERE 1=0 /* TODO group/aggregate */;

-- vw_ncr — Net Confirmed Revenue | Certainty: CONFIRMED | Owner: M5
-- business_definition: GSV minus cancellations, full + partial refunds, tax pass-through,
--   shipping pass-through. Excludes NexaLocal seller-marked transactions without platform payment.
CREATE OR REPLACE VIEW vw_ncr AS
SELECT /* TODO: GSV - deductions */
       TRUE AS is_confirmed_transaction,
       'CONFIRMED' AS metric_certainty_level
WHERE 1=0;

-- vw_revenue_leakage — GSV - NCR by leakage type | Certainty: CONFIRMED | Owner: M5
-- business_definition: GSV minus NCR, broken down by Cancellation / Refund / Tax / Shipping / Other.
CREATE OR REPLACE VIEW vw_revenue_leakage AS
SELECT /* TODO: leakage_type, leakage_amount */
       TRUE AS is_confirmed_transaction,
       'CONFIRMED' AS metric_certainty_level
WHERE 1=0;

-- vw_gross_margin_by_channel — | Certainty: CONFIRMED | Owner: M5
-- business_definition: NCR minus COGS by channel. Store numerator/denominator pair —
--   never a pre-divided ratio (non-additive).
CREATE OR REPLACE VIEW vw_gross_margin_by_channel AS
SELECT /* TODO: channel, margin_numerator, margin_denominator */
       TRUE AS is_confirmed_transaction,
       'CONFIRMED' AS metric_certainty_level
WHERE 1=0;

-- vw_net_margin_after_fulfilment — | Certainty: CONFIRMED | Owner: M5
-- business_definition: Gross Margin minus fulfilment cost, return cost, payment fees, seller commission.
CREATE OR REPLACE VIEW vw_net_margin_after_fulfilment AS
SELECT /* TODO */ TRUE AS is_confirmed_transaction, 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_confirmed_gmv — | Certainty: CONFIRMED | Owner: M2
-- business_definition: Total platform-confirmed transaction value (store, ecommerce, marketplace
--   FBN + seller-fulfilled with platform payment). NexaLocal offline EXCLUDED.
CREATE OR REPLACE VIEW vw_confirmed_gmv AS
SELECT /* TODO */ TRUE AS is_confirmed_transaction, 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_estimated_classified_gmv — | Certainty: ESTIMATED | Owner: M2
-- business_definition: Modelled NexaLocal offline value (B6 formula). Lower/point/upper band.
--   NEVER summed with Confirmed GMV in the same column. is_confirmed_transaction = FALSE always.
CREATE OR REPLACE VIEW vw_estimated_classified_gmv AS
SELECT /* TODO: gmv_lower, gmv_point, gmv_upper */
       FALSE AS is_confirmed_transaction,
       'ESTIMATED' AS metric_certainty_level
FROM NEXAMART_GOLD.fact_classified_listing_event  /* TODO apply B6 weights + confidence */
WHERE 1=0;

-- vw_campaign_incremental_revenue — | Certainty: CONFIRMED | Owner: Lead
-- business_definition: NCR for campaign-attributed orders minus average NCR for an equivalent
--   non-campaign baseline period, normalised for campaign duration.
CREATE OR REPLACE VIEW vw_campaign_incremental_revenue AS
SELECT /* TODO: campaign_ncr - normalised_baseline_ncr */
       TRUE AS is_confirmed_transaction, 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- ===========================================================================
-- INVENTORY  (owners: M4 + M3)
-- ===========================================================================

-- vw_atp_sku_loc_date — | Certainty: CONFIRMED | Owner: M4
-- business_definition: Available-to-Promise at SKU x location x date. SEMI-ADDITIVE:
--   may be summed across SKUs on the SAME date, NEVER across dates. Do not SUM(atp) without
--   a single-date filter or per-date GROUP BY.
CREATE OR REPLACE VIEW vw_atp_sku_loc_date AS
SELECT /* sku, location_id, snapshot_date, atp_qty */
       'CONFIRMED' AS metric_certainty_level
FROM NEXAMART_GOLD.fact_warehouse_inventory_snapshot  /* TODO */
WHERE 1=0;

-- vw_stockout_rate — | Certainty: CONFIRMED | Owner: M4
-- business_definition: % of SKU-location-day combos where ATP = 0 while demand signals exist.
CREATE OR REPLACE VIEW vw_stockout_rate AS
SELECT /* TODO numerator/denominator */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_oversell_count — | Certainty: CONFIRMED | Owner: M4
-- business_definition: # orders accepted where ATP was zero/insufficient at order placement.
CREATE OR REPLACE VIEW vw_oversell_count AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_inventory_accuracy_rate — | Certainty: CONFIRMED | Owner: M4
-- business_definition: % of snapshot rows where derived balance (opening+movements) matches recorded.
CREATE OR REPLACE VIEW vw_inventory_accuracy_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_return_to_restock_cycle_time — | Certainty: CONFIRMED | Owner: M4
-- business_definition: Avg days from return receipt to first sellable increment (same SKU/location).
CREATE OR REPLACE VIEW vw_return_to_restock_cycle_time AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_open_box_conversion_rate — | Certainty: CONFIRMED | Owner: M3
-- business_definition: % of returned units restocked as open-box AND sold within 30 days.
CREATE OR REPLACE VIEW vw_open_box_conversion_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- ===========================================================================
-- ECOMMERCE / STORE  (owners: M6 + Lead + M5 + M4)
-- ===========================================================================

-- vw_cart_abandonment_rate — | Certainty: CONFIRMED | Owner: M6
-- business_definition: Sessions with add-to-cart but no checkout completion / sessions with add-to-cart.
CREATE OR REPLACE VIEW vw_cart_abandonment_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_checkout_conversion_rate — | Certainty: CONFIRMED | Owner: M6
-- business_definition: Sessions with a completed purchase / sessions with checkout initiated.
CREATE OR REPLACE VIEW vw_checkout_conversion_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_browse_online_buy_in_store_rate — | Certainty: INFERRED | Owner: M6
-- business_definition: Sessions w/o online purchase where same customer (loyalty or match>0.90)
--   completes a store POS sale for the same SKU within 48h. INFERRED (cross-channel inference).
CREATE OR REPLACE VIEW vw_browse_online_buy_in_store_rate AS
SELECT /* TODO */ 'INFERRED' AS metric_certainty_level WHERE 1=0;

-- vw_browse_online_contact_nexalocal_rate — | Certainty: INFERRED | Owner: M6
-- business_definition: Product views followed within 24h by a NexaLocal contact in the same category.
CREATE OR REPLACE VIEW vw_browse_online_contact_nexalocal_rate AS
SELECT /* TODO */ 'INFERRED' AS metric_certainty_level WHERE 1=0;

-- vw_bopis_pickup_readiness_time — | Certainty: CONFIRMED | Owner: Lead
-- business_definition: Avg hours from BOPIS order placement to pickup-ready notification.
CREATE OR REPLACE VIEW vw_bopis_pickup_readiness_time AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_boris_count — | Certainty: CONFIRMED | Owner: M4
-- business_definition: Count of online-channel returns processed at physical stores. Separated
--   from store-origin returns in all store performance reporting.
CREATE OR REPLACE VIEW vw_boris_count AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_on_time_delivery_rate — | Certainty: CONFIRMED | Owner: Lead
-- business_definition: % of home-delivery orders delivered on/before the promised date.
CREATE OR REPLACE VIEW vw_on_time_delivery_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_payment_failure_rate — | Certainty: CONFIRMED | Owner: M5
-- business_definition: % of payment attempts that failed/declined, by channel and method.
CREATE OR REPLACE VIEW vw_payment_failure_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- ===========================================================================
-- NEXALOCAL / SELLER  (owner: M2)
-- ===========================================================================

-- vw_active_listing_count — | Certainty: CONFIRMED | Owner: M2
-- business_definition: Count of NexaLocal listings with active status on a given date.
CREATE OR REPLACE VIEW vw_active_listing_count AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_listing_contact_rate — | Certainty: CONFIRMED | Owner: M2
-- business_definition: Avg buyer contact events (chat + phone reveal + offer) per active listing per week.
CREATE OR REPLACE VIEW vw_listing_contact_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_relisting_rate — | Certainty: CONFIRMED | Owner: M2
-- business_definition: % of listings relisted within 14 days of prior expiry/sold event.
CREATE OR REPLACE VIEW vw_relisting_rate AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_duplicate_listing_inflation_factor — | Certainty: CONFIRMED | Owner: M2
-- business_definition: total listing count / deduplicated listing count. >1.0 = duplicate inflation.
CREATE OR REPLACE VIEW vw_duplicate_listing_inflation_factor AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_seller_risk_score_distribution — | Certainty: CONFIRMED | Owner: M2
-- business_definition: Distribution of sellers across the five risk tiers at a weekly snapshot date.
CREATE OR REPLACE VIEW vw_seller_risk_score_distribution AS
SELECT /* TODO */ 'CONFIRMED' AS metric_certainty_level WHERE 1=0;

-- vw_validated_report_rate — | Certainty: INFERRED | Owner: M2
-- business_definition: % of user-submitted reports corroborated by >=1 automated risk signal
--   on the same entity. INFERRED (corroboration inference).
CREATE OR REPLACE VIEW vw_validated_report_rate AS
SELECT /* TODO */ 'INFERRED' AS metric_certainty_level WHERE 1=0;

-- ###########################################################################
-- 28 views total. Verify after deploy:
--   SELECT COUNT(*) FROM NEXAMART_DW.INFORMATION_SCHEMA.VIEWS WHERE table_schema='NEXAMART_MARTS';  -- expect 28
-- Then run validation_suite.sql Check 5 (semi-additive) + Check 9 (certainty segregation).
-- ###########################################################################
