# Dashboard Specification (M2 — LO16)

**Tool:** TBD (Power BI Desktop `.pbix` or Tableau Public `.twbx` — decide at the dashboard phase).
**Connection:** `NEXAMART_MARTS` views **ONLY**. Never connect to `NEXAMART_GOLD` or `NEXAMART_SILVER`.

## Global rules (brief §11.1)
- **Label metric certainty everywhere** — every metric shows its certainty; Confirmed and Estimated are visually distinguishable (different colour / suffix / separate panel).
- **No engineering jargon in titles** — "Net Confirmed Revenue — Store Channel", not `fact_…net_sale_excl_tax`.
- **Campaign vs baseline on every chart** — every revenue / inventory / conversion visual shows **Baseline | Campaign | Post** side-by-side. Absolute numbers without context are meaningless.
- **Estimated Classified GMV visually separated** — separate panel / colour scheme / explicit "ESTIMATED" label. Never in the same chart as Confirmed GMV without clear separation.
- Readable by a non-technical executive in **three minutes**.

## The 5 required pages (brief §11.2)

| Page | Content | Driving views |
|---|---|---|
| **1. Executive Summary** | GSV → NCR waterfall; Confirmed GMV total; Estimated Classified GMV (separate, band); Campaign incremental revenue; Net margin; Revenue leakage breakdown | vw_gsv, vw_ncr, vw_revenue_leakage, vw_confirmed_gmv, vw_estimated_classified_gmv, vw_campaign_incremental_revenue, vw_net_margin_after_fulfilment |
| **2. Sales by Channel** | Store / Ecommerce / Marketplace revenue by period, tax-exclusive basis; promotion effectiveness | vw_gsv, vw_ncr, vw_gross_margin_by_channel, vw_payment_failure_rate |
| **3. Inventory Health** | ATP by location heat map; stockout events during campaign; inventory accuracy by week; return-to-restock cycle time | vw_atp_sku_loc_date, vw_stockout_rate, vw_oversell_count, vw_inventory_accuracy_rate, vw_return_to_restock_cycle_time, vw_boris_count |
| **4. Customer Journey** | Clickstream funnel (campaign vs baseline, via dim_step); cart abandonment; browse-online-buy-in-store; BOPIS readiness | vw_cart_abandonment_rate, vw_checkout_conversion_rate, vw_browse_online_buy_in_store_rate, vw_browse_online_contact_nexalocal_rate, vw_bopis_pickup_readiness_time, vw_on_time_delivery_rate |
| **5. NexaLocal & Seller Quality** | Estimated Classified GMV (with band); active listing count; listing contact rate; seller risk tier distribution | vw_estimated_classified_gmv, vw_active_listing_count, vw_listing_contact_rate, vw_relisting_rate, vw_duplicate_listing_inflation_factor, vw_seller_risk_score_distribution, vw_validated_report_rate |

## Deliverable
`dashboard/nexamart_dashboard.[pbix|twbx]` + `dashboard/screenshots/` (one PNG per page).
