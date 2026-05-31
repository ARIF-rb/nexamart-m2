# KPI Register (M2)

28 KPIs implemented as views in `NEXAMART_MARTS` (`sql/kpi_views.sql`). Every view carries
`metric_certainty_level`; Finance views also carry `is_confirmed_transaction`. Certainty totals:
**24 CONFIRMED, 3 INFERRED, 1 ESTIMATED**.

| # | KPI | View | Group | Certainty | Owner | Source fact(s) |
|---|---|---|---|---|---|---|
| 1 | Gross Sale Value | vw_gsv | Finance | CONFIRMED | M5 | fact_ecommerce_order_line, fact_store_sale_line |
| 2 | Net Confirmed Revenue | vw_ncr | Finance | CONFIRMED | M5 | as GSV − deductions |
| 3 | Revenue Leakage | vw_revenue_leakage | Finance | CONFIRMED | M5 | GSV − NCR by type |
| 4 | Gross Margin by Channel | vw_gross_margin_by_channel | Finance | CONFIRMED | M5 | facts + COGS (num/den) |
| 5 | Net Margin after Fulfilment | vw_net_margin_after_fulfilment | Finance | CONFIRMED | M5 | margin − costs |
| 6 | Confirmed GMV | vw_confirmed_gmv | Finance | CONFIRMED | M2 | store+ec+marketplace |
| 7 | Estimated Classified GMV | vw_estimated_classified_gmv | Finance | **ESTIMATED** | M2 | fact_classified_listing_event |
| 8 | Campaign Incremental Revenue | vw_campaign_incremental_revenue | Finance | CONFIRMED | Lead | NCR campaign − baseline |
| 9 | ATP by SKU-Location-Date | vw_atp_sku_loc_date | Inventory | CONFIRMED (semi-additive) | M4 | fact_warehouse_inventory_snapshot |
| 10 | Stockout Rate | vw_stockout_rate | Inventory | CONFIRMED | M4 | snapshot + demand |
| 11 | Oversell Count | vw_oversell_count | Inventory | CONFIRMED | M4 | order vs ATP |
| 12 | Inventory Accuracy Rate | vw_inventory_accuracy_rate | Inventory | CONFIRMED | M4 | snapshot vs derived |
| 13 | Return-to-Restock Cycle Time | vw_return_to_restock_cycle_time | Inventory | CONFIRMED | M4 | returns + inventory txn |
| 14 | Open-Box Conversion Rate | vw_open_box_conversion_rate | Inventory | CONFIRMED | M3 | returns + sales |
| 15 | Cart Abandonment Rate | vw_cart_abandonment_rate | Ecom/Store | CONFIRMED | M6 | fact_web_session |
| 16 | Checkout Conversion Rate | vw_checkout_conversion_rate | Ecom/Store | CONFIRMED | M6 | fact_web_session |
| 17 | Browse-Online-Buy-In-Store | vw_browse_online_buy_in_store_rate | Ecom/Store | **INFERRED** | M6 | session + store sale |
| 18 | Browse-Online-Contact-NexaLocal | vw_browse_online_contact_nexalocal_rate | Ecom/Store | **INFERRED** | M6 | session + NL contact |
| 19 | BOPIS Pickup Readiness Time | vw_bopis_pickup_readiness_time | Ecom/Store | CONFIRMED | Lead | fact_order_fulfilment |
| 20 | BORIS Count | vw_boris_count | Ecom/Store | CONFIRMED | M4 | returns at store |
| 21 | On-Time Delivery Rate | vw_on_time_delivery_rate | Ecom/Store | CONFIRMED | Lead | fact_order_fulfilment |
| 22 | Payment Failure Rate | vw_payment_failure_rate | Ecom/Store | CONFIRMED | M5 | payment attempts |
| 23 | Active Listing Count | vw_active_listing_count | NexaLocal/Seller | CONFIRMED | M2 | fact_classified_listing_snapshot |
| 24 | Listing Contact Rate | vw_listing_contact_rate | NexaLocal/Seller | CONFIRMED | M2 | fact_classified_listing_event |
| 25 | Relisting Rate | vw_relisting_rate | NexaLocal/Seller | CONFIRMED | M2 | listings |
| 26 | Duplicate Listing Inflation Factor | vw_duplicate_listing_inflation_factor | NexaLocal/Seller | CONFIRMED | M2 | listings |
| 27 | Seller Risk Score Distribution | vw_seller_risk_score_distribution | NexaLocal/Seller | CONFIRMED | M2 | dim_seller_risk_tier |
| 28 | Validated Report Rate | vw_validated_report_rate | NexaLocal/Seller | **INFERRED** | M2 | reports + risk signals |

## Locked Category-B formulas (cite verbatim; do not re-derive)

- **B6 Estimated Classified GMV** = `Σ (SELLER_SOLD×0.60 + PHN_REVEAL×0.15 + CHAT×0.08 + OFFER_ACC×0.30) × listing_confidence`, reported with a **±35% confidence band** (lower / point / upper). Exclude A12 relisted originals. Labelled **ESTIMATED** everywhere, never summed into Confirmed GMV.
- **B8 Seller Trust Score** = weighted composite of 8 signals (order-cancellation rate, late-fulfilment rate, return rate, complaints/100 orders, NL duplicate-listing rate, NL report rate, buyer-contact response rate, moderation actions) → 5 risk tiers in `dim_seller_risk_tier`; flagged sellers → `UNDER_REVIEW`. Equal-weight averaging is explicitly unacceptable; weights defended in report S1.
