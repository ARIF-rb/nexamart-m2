# NexaMart DW — Assignment 4, Milestone 2: Detailed Understanding

> The M2 companion to M1's `UNDERSTANDING.md`. Cross-referenced from `Assignment 4.docx`,
> the M1 deliverables, `docs/glossary.md`, and the instructor's anomaly checkbook
> (`.private/sir_checkbook_dump.txt`). Read this first, then your task file in `docs/tasks/`.
> For a concrete trace of one anomaly through all 7 steps, see [`docs/worked_example_A1.md`](docs/worked_example_A1.md).

---

## 1. The 30-second summary

Milestone 1 built the warehouse and **flagged** 24 data-quality anomalies. Milestone 2 (this
assignment, 2 weeks, same 6-person group) **resolves** them and produces the single reconciled
business answer the CEO asked for:

> *"Was the Back-to-School Tech & Essentials campaign (8–28 Aug 2024) actually successful, or did
> it only look successful because every team counted different things?"*

The work is a strict 7-step pipeline across two platforms:

1. **Identify** every anomaly with a Snowflake SQL query against `NEXAMART_SILVER` → `sql/anomaly_discovery.sql`.
2. **Resolve** in Databricks PySpark → `notebooks/05_anomaly_resolution.ipynb` writes **corrected Silver** back to Snowflake (overwrite, idempotent, audit trail preserved).
3. **Rebuild** only the affected Gold dims/facts → `notebooks/06_gold_rebuild.ipynb`.
4. **Validate** with a 10-check suite → `sql/validation_suite.sql` (iterate until all pass; document every iteration honestly).
5. **Build KPI views** in a new `NEXAMART_MARTS` schema → `sql/kpi_views.sql` (every view labelled with `metric_certainty_level`).
6. **Dashboard** (Power BI / Tableau) connected to `NEXAMART_MARTS` only — 5 stakeholder pages, Confirmed vs Estimated visually separated.
7. **Reconcile + Conclude** — explain in business language why each team's number differed, then answer the campaign question with a defensible position.

**Pre-requisite:** M1 must be complete in the existing Snowflake account — `NEXAMART_BRONZE` (61 raw tables), `NEXAMART_SILVER` (flagged), `NEXAMART_GOLD` (13 dims + 14 facts). M2 uses the **same account** — do not create a new one.

---

## 2. What changed from M1 → M2

| Aspect | Milestone 1 | Milestone 2 |
|---|---|---|
| Anomalies | discover + **flag** (never delete) | **resolve** (fix + audit trail) + classify |
| Silver | cleaned, flagged | **corrected** (overwrite-in-place; flags retained, `resolution_applied`/`resolution_method` added) |
| Gold | built on flagged Silver | **rebuilt** on corrected Silver (only affected tables) |
| New schema | — | **`NEXAMART_MARTS`** (KPI views only) |
| Output | the warehouse | **KPI views + dashboard + reconciliation + a single answer** |
| LOs | LO1–LO11 | **LO10–LO16** (formal SQL ID, PySpark resolution, KPI views, validation, reconciliation, conclusion, dashboard) |

**Audit-trail contract (graded, brief §8.1/§8.2):** a resolved row keeps `anomaly_flag = TRUE` and its
original `anomaly_reason_code`, and gains `resolution_applied = TRUE` + `resolution_method`
(+ `b_classification` for Category B). Use `add_resolution_columns()` / `resolve()` in
`notebooks/_shared/utils_anomaly.py`.

---

## 3. The 7-step end-to-end workflow (brief §6.1)

| Step | Where | Action | Output |
|---|---|---|---|
| 1 | Snowflake worksheet | SQL detection vs `NEXAMART_SILVER` | `anomaly_discovery.sql` (count + scope + impact per anomaly) |
| 2 | Databricks PySpark | read Silver → correct → write back (overwrite) | corrected `NEXAMART_SILVER`; `05_anomaly_resolution.ipynb` |
| 3 | Snowflake worksheet | re-run detection on corrected Silver | unresolved count → 0 (or expected) |
| 4 | Databricks PySpark | rebuild affected Gold from corrected Silver | updated `NEXAMART_GOLD`; `06_gold_rebuild.ipynb` |
| 5 | Snowflake worksheet | run full validation suite | all 10 checks pass (iterate) |
| 6 | Snowflake worksheet | create KPI views | `NEXAMART_MARTS` views; `kpi_views.sql` |
| 7 | Power BI / Tableau | dashboards on MARTS only | dashboard file + screenshots |

Steps are sequential: resolution → rebuild → validation → KPI views → dashboard.

---

## 4. The anomaly catalogue — carry-forward (M1 flag → M2 resolve)

24 anomalies (16 Category A "clear correct answer" + 8 Category B "ambiguous — defend in writing").
Verified before-counts are the acceptance contracts; full detail + ₹ impacts in
`.private/lead_cheatsheet.md` and `.private/sir_checkbook_dump.txt`. Each anomaly gets a detection
query (`anomaly_discovery.sql`), a resolution (notebook 05 + `anomaly_resolution.sql`), and a report S1 entry.

### Category A — resolve deterministically

| ID | Anomaly | Before-count | Owner | Resolution method | Affected Gold |
|---|---|---|---|---|---|
| A1 | Cancelled EC order still in revenue | 94 EC orders (instructor "~178" incl. POS; ₹6.15 Cr) | M5 | zero cancelled revenue | fact_ecommerce_order_line |
| A2 | Payment captured after cancellation | 27 (26 strictly after; ₹1.08 Cr) | M5 | flag reversal-required | fact_ecommerce_order_line |
| A3 | Tax/shipping inclusion mismatch | schema-wide (₹16.25 Cr naive-mix) | M5 | normalise to tax-exclusive | fact_ecommerce_order_line, fact_store_sale_line |
| A4 | NexaLocal seller-marked-sold as confirmed revenue | 449 events (₹1.72 Cr, ESTIMATED) | M6 | relabel ESTIMATED (feeds B6 @0.60) | fact_classified_listing_event |
| A5 | Website ATP>0 while warehouse physical=0 | 5 SKU-date | Lead | correct ATP to 0 | fact_warehouse_inventory_snapshot |
| A6 | Negative ATP / sellable qty | 8 snapshots | M4 | correct to 0 + oversell flag | fact_store_inventory_snapshot |
| A7 | Returned stock sellable before inspection | 10 receipts | Lead | zero pre-inspection restock | fact_inventory_transaction |
| A8 | Missing snapshot days (**1–7 Aug ramp-up**, pre-campaign) | stores 3/7/12 × 7 days (~21) | Lead | reconstruct → `RECONSTRUCTED` + INFERRED | fact_store_inventory_snapshot |
| A9 | Same SKU → different products | 1 | M3 | canonical product (catalogue wins) | dim_product, product-joined facts |
| A10 | Open-box restocked as NEW | 12 receipts | M4 | correct condition to open-box | fact_inventory_transaction |
| A11 | Placeholder customer 9999 collision | 178 EC orders + 1 real loyalty | M2 | rekey guests to GUEST-{session} | dim_customer, fact_ecommerce_order_line |
| A12 | Listing marked sold then relisted | 3 pairs (instructor headline "1") | Lead | link + exclude original from GMV; `seller_marked_sold_reliability=LOW` | fact_classified_listing_snapshot |
| A13 | Coordinated fake listing ring | hash rings (5/8, 4/5) | M6 | flag risk tier; exclude | fact_classified_listing_event, dim_seller |
| A14 | Delivered before shipped | 18 strict / 68 broad | Lead | `corrected_ts = PICKED_UP + 36h median`; **>72h → REQUIRES_MANUAL_REVIEW** | fact_order_fulfilment |
| A15 | Review before delivery | 25 (all unverified) | M6 | `verified_purchase = FALSE` | fact_customer_review |
| A16 | Duplicate complaint cases | 7 | M6 | dedupe to canonical case key | fact_customer_complaint |

### Category B — choose, implement, defend (with quantified alternative)

| ID | Ambiguity | Before-count | Owner | Chosen interpretation (M1-locked) |
|---|---|---|---|---|
| B1 | Campaign-window order, promo-less, prior UTM session, post-window delivery | 126 candidate / 102 attributed (instructor col-dict says 91) | Lead | attribute the 102 with `attribution_confidence=0.85` |
| B2 | Partial refund (Aug sale, Sep refund) period attribution | 1 refund (₹2.16 L) | Lead | recognise reversal in **return period** (Sep), GAAP-style |
| B3 | Inventory decrement without reference order | 175 (all PCK) | Lead | classify `MOVEMENT_NULL_REF` (probable missing ref), INFERRED |
| B4 | NexaLocal free-text → catalogue match | threshold call | M3 | match ≥0.75; 0.65–0.75 manual; <0.65 unmatched |
| B5 | Cross-channel identity, no shared key | 1 (0.92 confidence) | M2 | probabilistic merge at ≥0.90 |
| B6 | Estimated Classified GMV model | campaign listings | M2 | `SELLER_SOLD×0.60 + PHN_REVEAL×0.15 + CHAT×0.08 + OFFER_ACC×0.30` × confidence, ±35% band, ESTIMATED |
| B7 | BOPIS Completed without pickup event | 25 | Lead | treat as fulfilled (scan miss); flag `collection_unconfirmed` |
| B8 | Seller trust composite score | flagged sellers → UNDER_REVIEW | M2 | weighted composite → 5 risk tiers (not equal-weight) |

> **Seed availability:** M1 verified-SQL seeds (`sql/_m1_seed/`) exist for A01–A02, A04–A16, B01, B03, B07.
> **No seed for A03** (schema-convention) nor **B2/B4/B5/B6/B8** — those detection queries are net-new in M2.

---

## 5. KPI register (28 KPIs → `NEXAMART_MARTS` views)

Every view carries `metric_certainty_level`; **Finance views also carry `is_confirmed_transaction`**.
Certainty: 24 CONFIRMED, 3 INFERRED, 1 ESTIMATED. Full owner/source map in `docs/kpi_register.md`.

- **Finance (8, M5+M2+Lead):** GSV, NCR, Revenue Leakage, Gross Margin by Channel, Net Margin after Fulfilment, Confirmed GMV, **Estimated Classified GMV** (ESTIMATED + band), Campaign Incremental Revenue.
- **Inventory (6, M4+M3):** ATP by SKU-Location-Date (**semi-additive**), Stockout Rate, Oversell Count, Inventory Accuracy Rate, Return-to-Restock Cycle Time, Open-Box Conversion Rate.
- **Ecommerce/Store (8, M6+Lead+M5+M4):** Cart Abandonment, Checkout Conversion, Browse-Online-Buy-In-Store (INFERRED), Browse-Online-Contact-NexaLocal (INFERRED), BOPIS Pickup Readiness, BORIS Count, On-Time Delivery, Payment Failure.
- **NexaLocal/Seller (6, M2):** Active Listing Count, Listing Contact Rate, Relisting Rate, Duplicate Listing Inflation Factor, Seller Risk Score Distribution, Validated Report Rate (INFERRED).

---

## 6. The 10-check validation suite (brief §10)

1. **Completeness** — each Gold table non-zero, matches expected Silver count.
2. **Referential Integrity** — zero orphan FKs (left-anti join per fact).
3. **Grain** — no duplicate rows at declared grain (`COUNT(*)=COUNT(DISTINCT grain)`).
4. **Additive Fact Sanity** — `net = gross − discount − return` in `fact_store_sale_line`.
5. **Semi-Additive Guard** — no mart view SUMs ATP across dates.
6. **Metric Certainty Completeness** — no NULL `metric_certainty_level` in any fact.
7. **Campaign Period Coverage** — ≥1 row per fact in 8–28 Aug 2024.
8. **Inventory Balance Reconciliation** — sample SKU-location-week; list failures with SKU + location.
9. **Classified Certainty Segregation** — no Finance-mart row is `ESTIMATED` without `is_confirmed_transaction = FALSE`.
10. **Temporal Consistency** — no delivered-before-shipped beyond the >72h correction threshold.

Expect failures on the first run; the iterative loop is the point. Record every iteration in report S3.

---

## 7. Certainty segregation rules (the spine of the conclusion)

NexaLocal's defining problem is **certainty**: the platform may never know a sale happened. Every metric
carries a `metric_certainty_level ∈ {CONFIRMED, INFERRED, ESTIMATED, UNRELIABLE}` (M1 glossary).
**Estimated Classified GMV is never summed into Confirmed GMV** in the same column. The dashboard
visually separates Confirmed vs Estimated on every page. A warehouse that presents ESTIMATED as
CONFIRMED is misleading, not just wrong — modelling uncertainty honestly is the higher-order skill.

---

## 8. Reconciliation framing — why teams disagreed (report S4)

GSV → NCR waterfall, each deduction a named step (cancellations, refunds, tax pass-through, shipping
pass-through). Map each of the seven teams' divergent numbers to the resolving anomaly:

- **Sales (+34%)** over-counted cancelled orders (**A1**) and NexaLocal seller-marked-sold (**A4/B6**).
- **Finance (+11%)** excluded everything Sales over-counted (the strict NCR).
- **Marketplace** counted classified estimates that should be ESTIMATED-labelled (**B6**).
- **Inventory** saw website-available/warehouse-empty (**A5/A6**).
- **Ecommerce** abandonment driven by inventory mismatch + broken delivery promises.
- **Store Ops** BOPIS/BORIS workload was invisible (separated in M2).
- **Support** complaint volume inflated by duplicate cases (**A16**).
- Cross-cutting: tax-basis mismatch (**A3**), refund-period attribution (**B2**).

---

## 9. Tooling & environment conventions (carried from M1)

- **Snowflake:** existing M1 account; `NEXAMART_DW` db; WH `NEXAMART_WH` (XSMALL, AUTO_SUSPEND=60). New schema `NEXAMART_MARTS`. Setup: `sql/snowflake_setup_m2.sql`.
- **Databricks Free Edition (serverless):** no Maven JAR — use `notebooks/_shared/utils_snowflake.py` (`snowflake-connector-python` + `write_pandas`). Widget credentials, never hardcoded. `%pip install` then `dbutils.library.restartPython()`.
- **Idempotent overwrite writes**; re-running 05 then 06 produces identical row counts.
- **Source db** committed at `data/nexamart_operations.db` (~59 MB).
- **No co-author or external-tool attribution** in any commit, PR, or pushed file — treat every commit as the team's solo work.

---

## 10. The campaign question — answer template (report S5)

Answer with multiple KPIs, **each with its certainty level, never conflated**:
- **NCR** (CONFIRMED) campaign vs baseline → the revenue verdict.
- **Net Margin** (CONFIRMED) → was it profitable, not just big?
- **Inventory** impact (stockouts/oversell during campaign).
- **Fulfilment** performance (on-time delivery, BOPIS readiness).
- **Customer satisfaction** signals (verified reviews, complaints after dedup).
- **Estimated Classified** engagement (ESTIMATED, labelled, with band).

Take a direct, defensible position. "It depends" without a conclusion is not acceptable.

---

## 11. LO → deliverable cross-reference (brief §5 body: LO10–LO16)

| LO | Deliverable |
|---|---|
| LO10 Formal SQL identification | `sql/anomaly_discovery.sql` |
| LO11 PySpark resolution | `notebooks/05_anomaly_resolution.ipynb` + `sql/anomaly_resolution.sql` |
| LO12 KPI views | `sql/kpi_views.sql` (NEXAMART_MARTS) |
| LO13 Validation | `sql/validation_suite.sql` + report S3 iteration log |
| LO14 KPI reconciliation | report S4 + `docs/reconciliation_method.md` |
| LO15 Campaign conclusion | report S5 |
| LO16 Stakeholder dashboard | `dashboard/` (5 pages, MARTS-only, certainty-separated) |

*(The §5 header says "LO10–LO13" but its body enumerates LO10–LO16; LO14/15/16 are unambiguously M2.)*

---

*"In a real omnichannel marketplace, data warehousing is about connecting physical sales, digital
behaviour, inventory reality, and uncertain marketplace signals into one trusted business view."*
