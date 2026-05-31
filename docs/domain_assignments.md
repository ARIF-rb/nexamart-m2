# Domain Assignments

The team is split into **2 heavy members** (Lead + M2, who absorb the genuinely complex pieces) and **4 light members** (M3–M6, who each get a small but **complete** vertical slice — Bronze read → Silver write → Gold dim or fact → anomaly flag → report sections).

Every member touches every layer. Light members typically get 1 dim or 1 fact + 2–3 anomalies + a slice of Silver. Lead + M2 absorb the complex transforms (T4 identity, T6 ATP reconstruction, T7 NL confidence, T9 attribution bridge, T10 seller trust score), the SCD2 dims, the accumulating snapshot fact, and the judgment-call B-anomalies.

---

## Allocation table

| # | Member | Tier | Source slice (Silver write) | Silver T# | Gold dims | Gold facts | Anomalies | Est hrs |
|---|---|---|---|---|---|---|---|---|
| **1** | **Lead** | **Heavy** | `ec_*` (5), `dc_*` (4), T&S remainder (4 — see below), `ws_*` (3), plus a derived `silver_store_inventory_snapshots_reconstructed` | T1 / T2 / T3 utilities for everyone; **T6** ATP reconstruction; **T9** campaign attribution bridge | dim_date, dim_channel, dim_step, dim_payment_method, dim_delivery_method (5) | fact_ecommerce_order_line, **fact_order_fulfilment** (accumulating snapshot), fact_inventory_transaction, fact_store_inventory_snapshot (UNIONs M4's clean Silver + lead's reconstructed Silver), fact_classified_listing_snapshot, fact_web_session, fact_web_page_event, fact_customer_complaint (8) | A5, A7, A8, A12, A14, B1, B2, B3, B7 (9) | 50–60 |
| **2** | M2 | **Heavy** | `cl_*` (3) + `ts_sellers`, `ts_seller_status_codes`, `ts_seller_types` (3) | **T4** identity (4-pass); **T7** NL listing confidence; **T10** seller trust score | dim_customer (SCD2 + identity bridge), dim_seller_risk_tier (2) | fact_seller_performance_snapshot (1) | A11 (9999), B5, B6, B8 (4) | 35–45 |
| **3** | M3 | Light | `pc_*` (5) | **T5** product master (exact SKU pass only — fuzzy goes to lead/M2) | dim_product (SCD2), dim_listing_condition (2) | — (no fact; M3 leads Bus Matrix justifications for dim_product joins, which appear on most facts) | A9, B4 (2) | 15 |
| **4** | M4 | Light | `si_*` (3 — clean Silver only; lead does T6 reconstruction in a sibling table), `wh_*` (5) = 8 | apply T1/T2/T3 to owned tables | dim_store (SCD1) (1) | fact_warehouse_inventory_snapshot (gapless, easy) (1) | A6, A10 (2) | 18 |
| **5** | M5 | Light | `pos_*` (6), `pg_*` (3), `rr_*` (4) = 13 | **T8** return revenue period (formula) | dim_promotion (1) | fact_store_sale_line, fact_return_line (2) | A1, A2, A3 (3 — A3 is documentation-only, no row flag) | 22 |
| **6** | M6 | Light | `rv_*` (1), `cs_*` (4), `nl_*` (5), `ts_marketplace_orders` + `ts_seller_listings` + `ts_fulfilment_events` (3) = 13 | apply T1/T2/T3 + flag-only anomaly work | dim_seller (SCD1), dim_return_reason (2) | fact_customer_review, fact_classified_listing_event (2) | A4, A13, A15, A16 (4) | 22 |

**Verified totals:** 61 source tables · 10 Silver transforms · 13 dims · 14 facts · 16 A + 8 B = 24 anomalies. All covered, no duplicates.

### `ts_*` table breakdown (10 total)
- **M2** owns: `ts_sellers`, `ts_seller_status_codes`, `ts_seller_types` (3) — feeds dim_seller_risk_tier work
- **M6** owns: `ts_marketplace_orders`, `ts_seller_listings`, `ts_fulfilment_events` (3)
- **Lead** owns: `ts_safety_reports`, `ts_risk_signals`, `ts_signal_types`, `ts_report_reasons` (4)

---

## Member 1 — Lead (you) — Heavy

**Source tables you write Silver for (16 source + 2 derived = 18 total Silver outputs):**
- `ec_*` (5): ec_orders, ec_order_lines, ec_order_status_history, ec_order_status_codes, ec_delivery_methods
- `dc_*` (4): dc_shipments, dc_delivery_events, dc_event_types, dc_carriers
- `ts_*` T&S (4): ts_safety_reports, ts_risk_signals, ts_signal_types, ts_report_reasons
- `ws_*` (3): ws_sessions, ws_page_events, ws_event_types
- Derived: `silver_store_inventory_snapshots_reconstructed` (T6 gap-fill rows)
- Plus `silver_campaign_attribution_bridge` (T9 output)

**Plus you also:** ingest all 61 tables to Bronze (one-shot, mechanical loop), publish T1/T2/T3 utilities + the anomaly taxonomy registry + the silver_template, build 7 of the 8 cross-cutting dims, build 8 facts including the accumulating snapshot.

**Silver transforms owned:**
- T1, T2, T3 — utilities every member uses (publish to `notebooks/_shared/`)
- **T6** — ATP reconstruction for stores 3, 7, 12 (and any others that show gaps); writes to `silver_store_inventory_snapshots_reconstructed`
- **T9** — campaign attribution bridge

**Gold dims (5 static):** dim_date, dim_channel, dim_step, dim_payment_method, dim_delivery_method — mostly hand-coded lookups + dim_date calendar generator.

**Gold facts (8):**
1. fact_ecommerce_order_line
2. **fact_order_fulfilment** (accumulating snapshot — Kimball's hardest)
3. fact_inventory_transaction
4. fact_store_inventory_snapshot (UNIONs M4's silver + lead's reconstructed)
5. fact_classified_listing_snapshot
6. fact_web_session
7. fact_web_page_event
8. fact_customer_complaint (with dedup via canonical_case_key)

**Anomalies (9):**
- A5 (WH ATP>0 with physical=0), A7 (returned stock counted sellable before inspection), A8 (missing snapshot days — drives T6), A12 (NL relisting via image_hash + 30d window), A14 (delivery clock drift)
- B1, B2, B3, B7 (judgment calls — defend in writing)

**Cross-cutting:** Bronze ingestion, anomaly taxonomy curator, scaffolded notebooks for members, daily PR review, Bus Matrix master document, report assembly, validation SQL, idempotence test.

---

## Member 2 — Heavy / Strongest member

**Source tables you write Silver for (6):**
- `cl_*` (3): cl_customers, cl_loyalty_tiers, cl_loyalty_transactions
- `ts_*` seller-identity (3): ts_sellers, ts_seller_status_codes, ts_seller_types

**Silver transforms owned (3 — all complex):**
- **T4** — Customer identity resolution (4-pass: loyalty→email→phone→fuzzy). The single hardest piece in the assignment.
  - Pass 1: exact loyalty_id (confidence 1.00)
  - Pass 2: exact email lowercase+trim (0.95)
  - Pass 3: exact phone E.164 (0.90)
  - Pass 4: fuzzy name+address Jaccard via rapidfuzz (0.70–0.89)
  - Anonymous bucket: shared SK, confidence 0.0
- **T7** — NL listing confidence score (formula; defend weights)
- **T10** — Seller trust score (composite from 8 inputs; defend weights; map to 5 risk tiers)

**Gold dims (2):**
- **dim_customer** (SCD2 + identity bridge — most complex dim; supports identity_confidence_score per row, anonymous SK routing)
- dim_seller_risk_tier (SCD1, 5 tiers)

**Gold facts (1):**
- fact_seller_performance_snapshot (periodic, per seller per week; store ratios as numerator/denominator pairs)

**Anomalies (4):**
- **A11** (placeholder customer_id 9999 collision — well-documented detection)
- B5 (cross-channel customer match without exact key — defend probabilistic threshold)
- B6 (Estimated Classified GMV formula — must include lower/point/upper bands)
- B8 (Seller trust score formula defence)

**Hint script (no counts revealed):**
- A11: profile customer_id values in ec_orders by frequency. The most-used placeholder will stand out. Then check cl_customers for a real loyalty record sharing the same id. If both exist, that's the collision — flag affected rows with `PLACEHOLDER_ID_COLLISION`.
- T4: use rapidfuzz for the fuzzy pass. Tokenize names + address → Jaccard on token sets.

**Touchpoints:** your `silver_customer_master` (output of T4) is read by lead (EC fact, complaint fact, attribution bridge), M5 (POS/return facts), M6 (review fact). Hard deadline: **dim_customer done by Day 7 EOD (Mon 18 May)**.

---

## Member 3 — Product (Light)

**Source tables you write Silver for (5):**
- `pc_*`: pc_products, pc_brands, pc_categories, pc_condition_codes, pc_price_history (empty, schema-only)

**Silver transforms owned:**
- **T5** simplified — exact SKU match between `pc_products` and `ts_seller_listings` only. The fuzzy second pass is **deferred to lead/M2** to keep your scope light. Catalogue still wins all conflicts.

**Gold dims (2):**
- dim_product (SCD2) — second-most-complex dim after dim_customer; uses SCD2 mechanics (valid_from/valid_to/is_current/version_number)
- dim_listing_condition (static, 10 condition codes)

**Gold facts (0):** You don't own a fact directly. Your compensation: **dim_product is the single most-shared dim** — it joins to most facts (sales, returns, inventory, listings, reviews). You'll fill the most Bus Matrix Y-cell justifications during Phase 5, and your dim_product enables everyone else's joins.

**Anomalies (2):**
- **A9** (SKU mapped to different products in catalogue vs marketplace) — single row to flag, well-defined
- B4 (NL free-text titles fuzzy-match to catalogue — you defend the confidence threshold)

**Hint script:**
- A9: profile every distinct SKU in `ts_seller_listings`. For each, look up its catalogue product_name. If a seller's `product_name` is wildly different from the catalogue's, flag with `SKU_PRODUCT_MISMATCH`.
- B4: fuzzy-match `nl_listings.product_title` to `pc_products.product_name`. Defend your confidence threshold.

**Hands-on of everything:** Bronze read (you'll read pc_* + sample ts_seller_listings) ✓ • Silver write (5 tables + product_master) ✓ • Gold dims (2, including SCD2) ✓ • Anomaly (2) ✓ • Bus Matrix (cells for dim_product across many facts) ✓ • Report Sections 1, 2, 7 (T5), 8 (A9, B4), 9 (your dims).

**Touchpoints:** your `silver_product_master` is needed by M5 (sale_line + return_line facts), M6 (review/listing_event facts), lead (EC + inventory facts). **Hard deadline: Day 5 EOD (Sat 16 May)**.

---

## Member 4 — Inventory (Light)

**Source tables you write Silver for (8):**
- `si_*` (3): si_inventory_movements (438K rows — biggest), si_inventory_snapshots (217K), si_movement_types
- `wh_*` (5): wh_inbound_receipts, wh_inventory_movements, wh_inventory_snapshots, wh_movement_types, wh_warehouses

**Important:** you write the **clean Silver** of these tables. T6 ATP reconstruction is **lead's work** — they write a sibling Silver table `silver_store_inventory_snapshots_reconstructed` and the fact UNIONs both.

**Silver transforms owned:** apply T1/T2/T3 utilities + flag obvious anomalies. No T# of your own.

**Gold dims (1):**
- dim_store (SCD1) — includes `campaign_zone_activation_date` (per-store BTS counter activation timing)

**Gold facts (1):**
- fact_warehouse_inventory_snapshot (gapless, easy — periodic snapshot, SKU × warehouse × calendar day)

**Anomalies (2):**
- **A6** (negative store sellable/physical qty — simple filter)
- **A10** (open-box returns restocked as new — simple cross-table check on rr_return_receipts)

**Hint script:**
- A6: profile si_inventory_snapshots for `physical_qty < 0` or `sellable_qty < 0`. Physical can never be negative; ATP can but reports as 0 + oversell flag.
- A10: in rr_return_receipts, find rows where `condition_on_receipt='OPENED'` AND `restocked_as_condition='NEW'`. Flag with `OPEN_BOX_AS_NEW`.

**Hands-on of everything:** Bronze read ✓ • Silver write (8 tables) ✓ • Gold dim (dim_store) ✓ • Gold fact (fact_warehouse_inventory_snapshot) ✓ • Anomaly (2) ✓ • Bus Matrix (1 fact row + cells where dim_store joins) ✓ • Report Sections 1, 2, 7, 8, 9.

**Touchpoints:** your clean `silver_store_inventory_snapshots` is needed by lead for T6 reconstruction. **Hard deadline: Day 5 EOD (Sat 16 May)** so lead can begin reconstruction Day 6.

---

## Member 5 — Sales pipeline core (Light)

**Source tables you write Silver for (13 — mostly small lookups):**
- `pos_*` (6): pos_transactions (10,868), pos_transaction_lines (24,507), pos_cashiers, pos_payment_methods, pos_status_codes, pos_stores
- `pg_*` (3): pg_transactions, pg_instrument_types, pg_status_codes
- `rr_*` (4): rr_return_requests, rr_return_receipts, rr_refund_events, rr_return_reasons

**Silver transforms owned:**
- **T8** — Return revenue period logic. For partial refunds processed in September for August purchases (B2 case), produce BOTH `revenue_impact_original_period` and `revenue_impact_return_period` columns. Don't choose; let downstream marts choose.

**Gold dims (1):**
- dim_promotion (SCD1, includes promotion_channel_scope)

**Gold facts (2):**
- fact_store_sale_line (one row per product scanned per POS receipt — clean transactional grain)
- fact_return_line (one row per returned product per return authorisation — uses your T8 output for revenue impact)

**Anomalies (3):**
- **A1** (cancelled EC orders carrying revenue — simple WHERE filter)
- **A2** (payment captured AFTER cancellation timestamp — join + timestamp compare)
- **A3** (tax/shipping inclusion mismatch: POS=incl, EC=excl, marketplace=mixed — **document in report Section 7**, no row-level flag)

**Hint script:**
- A1: profile `ec_orders` where `order_status='CANCELLED'`. Does `subtotal_excl_tax > 0` for those? Sales dashboards probably sum that without filtering. Flag with `CANCELLED_WITH_REVENUE`.
- A2: for the cancelled orders from A1, join `pg_transactions` on order id. When were payments captured relative to the cancellation timestamp? Compare against `ec_order_status_history`.
- A3: schema-confirmed (`pos_transactions.total_amount_incl_tax` vs `ec_orders.subtotal_excl_tax`). Document the inconsistency in your Section 7 write-up; no rows to flag.

**⚠️ Day 2 task:** verify `pg_transactions` date format. UNDERSTANDING.md says Unix epoch; xlsx dictionary says `YYYY-MM-DD HH:MM:SS`. Run `SELECT created_ts, TYPEOF(created_ts) FROM pg_transactions LIMIT 5` and update `_shared/utils_dates.py::parse_pg_timestamp()` if needed. Post in team channel.

**Hands-on of everything:** Bronze read ✓ • Silver write (13 tables) ✓ • Gold dim (dim_promotion) ✓ • Gold facts (2) ✓ • Anomalies (3) ✓ • Bus Matrix (2 fact rows + cells for dim_promotion) ✓ • Report Sections 1, 2, 7 (T8), 8 (A1/A2/A3), 9.

**Touchpoints:** your `silver_pg_transactions` and `silver_dc_delivery_events` (lead writes the latter) are joined for B7 BOPIS gap analysis (which is lead's anomaly).

---

## Member 6 — Reviews + Support + NL + Marketplace (Light)

**Source tables you write Silver for (13):**
- `rv_*` (1): rv_reviews
- `cs_*` (4): cs_cases, cs_case_events, cs_agents, cs_complaint_categories
- `nl_*` (5): nl_listings, nl_listing_events, nl_user_accounts, nl_categories, nl_event_types
- `ts_*` marketplace transactional (3): ts_marketplace_orders, ts_seller_listings, ts_fulfilment_events

**Silver transforms owned:** apply T1/T2/T3 + flag-only anomaly work. No T# of your own (T7 NL confidence and T10 seller trust are M2's because they require defended weights).

**Gold dims (2):**
- dim_seller (SCD1) — includes seller_risk_score from M2's T10 output (you read M2's silver_seller_trust_score and join in)
- dim_return_reason (static, with reason_group + channel_fault_attribution)

**Gold facts (2):**
- fact_customer_review (one row per review; star_rating, days_post_delivery)
- fact_classified_listing_event (one row per NL engagement event; CONFIRMED for platform events, **INFERRED for SELLER_SOLD per A4**)

**Anomalies (4):**
- **A4** (NL seller-marked-sold counted as confirmed revenue — type filter)
- **A13** (image hash reused across multiple sellers — group-by hash, count distinct sellers)
- **A15** (review posted before delivery — simple negative-days check)
- **A16** (duplicate complaint cases — schema flag already exists)

**Hint script:**
- A4: in `nl_listing_events`, count events with `event_type='SELLER_SOLD'`. These are NOT confirmed revenue. Flag with `NL_SELLER_SOLD_AS_REVENUE`.
- A13: group `nl_listings` by `image_hash`, count distinct sellers per hash. Hashes used by ≥2 different sellers indicate coordination. Flag with `IMAGE_HASH_REUSED`.
- A15: filter `rv_reviews` for `days_post_delivery < 0`. Cross-reference `is_verified_purchase` and document the pattern.
- A16: in `cs_cases`, look at `is_duplicate_flag` and `canonical_case_ref` — the dedup pattern is implied. Flag with `DUPLICATE_CASE`. The `canonical_case_ref` becomes the dedup key for lead's `fact_customer_complaint`.

**Hands-on of everything:** Bronze read ✓ • Silver write (13 tables) ✓ • Gold dims (2) ✓ • Gold facts (2) ✓ • Anomalies (4) ✓ • Bus Matrix (2 fact rows + cells for dim_seller) ✓ • Report Sections 1, 2, 8 (4 anomalies — most of any light member), 9.

**Touchpoints:** your A16 dedup output (canonical_case_key) is consumed by lead's `fact_customer_complaint`. Your `silver_seller` rows feed M2's seller trust score work (M2 reads sellers + adds trust_score).

---

## Coordination touchpoints (cross-member dependencies)

| What | From → To | Hard deadline |
|---|---|---|
| `silver_customer_master` (M2's T4 output) | M2 → M5 (return facts), M6 (reviews), Lead (EC fact, complaint fact, attribution bridge) | M2 finishes by **Day 7 EOD (Mon 18 May)** |
| `silver_product_master` (M3's T5 output) | M3 → M5 (sale/return facts), M6 (review/listing facts), Lead (EC + inventory facts) | M3 finishes by **Day 5 EOD (Sat 16 May)** |
| `silver_store_inventory_snapshots` (M4's clean Silver) | M4 → Lead (T6 reconstruction starts Day 6) | M4 finishes by **Day 5 EOD (Sat 16 May)** |
| `silver_dc_delivery_events` (Lead) | Lead → M6 (review-before-delivery check uses this) | Lead finishes by **Day 6 EOD (Sun 17 May)** |
| `silver_status_code_mapping` (Lead's seed) | Lead → all members (T2 mapping for everyone) | Lead finishes by **Day 3 lunch (Thu 14 May 1pm)** |
| Anomaly taxonomy registry adds | Anyone → Lead approves PR | As needed throughout Phase 4 |
| Bus Matrix cell justifications | Each member fills cells for their facts | Phase 5 (Sat-Sun 17–18 May) |

**Cross-domain blockers go to lead immediately in standup.**
