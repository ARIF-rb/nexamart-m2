# Enterprise Bus Matrix — 14 facts × 13 dimensions

**Owner:** All members fill in cells for **their** facts during Phase 5 (Sat–Sun 17–18 May).

## ⚠️ Grading rule (per brief Section 11.1)

> Every Y cell must be **justified in writing**. Tick marks alone fail.

For each Y cell, write ONE sentence answering:
- *Why this fact needs this dimension*, AND
- *What business question that join enables*

Use the format: `Y — <reason + question>`. Use `N` (no further explanation needed) for cells the fact doesn't use. Use `D` for **degenerate dimensions** that stay in the fact (receipt no, EC order no, return auth no, NL listing ref) — note these in the notes column instead.

Example justification (lead has written one for the team to copy):
> `fact_ecommerce_order_line × dim_customer`: **Y** — Marketing must answer "what is repeat-purchase rate during campaign vs baseline by customer cohort"; without dim_customer FK we cannot identify repeat customers across orders.

---

## The matrix

| Fact ↓ \\ Dim → | dim_date | dim_product | dim_store | dim_customer | dim_seller | dim_promotion | dim_channel | dim_payment_method | dim_delivery_method | dim_listing_condition | dim_return_reason | dim_step | dim_seller_risk_tier | Degenerate dims |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **fact_store_sale_line** (M5) |  |  |  |  | N |  |  |  | N | N | N | N | N | receipt_no, line_no |
| **fact_ecommerce_order_line** (Lead) | Y — order_date role; campaign-vs-baseline revenue by day | Y — which SKUs drove BTS revenue | Y — BOPIS pickup store; BOPIS volume by store | Y — repeat-purchase rate by cohort | N | Y — promo vs organic attribution split | Y — EC vs BOPIS channel mix | N | Y — delivery-mode revenue mix | N | N | N | N | order_id, line_no |
| **fact_return_line** (M5) |  |  |  |  |  | N |  |  |  | N |  | N | N | return_auth_id |
| **fact_store_inventory_snapshot** (Lead — UNIONs M4 clean + Lead reconstructed) | Y — snapshot_date; ATP trend over campaign ramp | Y — per-SKU stock position | Y — per-store oversell/stockout analysis | N | N | N | N | N | N | N | N | N | N | snapshot_id |
| **fact_warehouse_inventory_snapshot** (M4) |  |  | N | N | N | N | N | N | N |  | N | N | N | snapshot_id |
| **fact_inventory_transaction** (Lead) | Y — movement_date; daily in/out flow | Y — per-SKU movement audit | Y — store/warehouse node of the movement | N | N | N | N | N | N | N | N | N | N | movement_id, ref_no |
| **fact_order_fulfilment** (Lead, accumulating) | Y — role-played placed/captured/shipped/delivered/returned dates; pipeline SLA analysis | N | N | Y — fulfilment SLA by customer cohort | N | N | N | N | N | N | N | N | N | order_id |
| **fact_web_session** (Lead) | Y — session_start; daily traffic/conversion trend | N | N | Y — logged-in journey vs anonymous | N | Y — UTM-tagged campaign sessions (BTS2024) | Y — acquisition channel mix | N | N | N | N | N | N | session_id |
| **fact_web_page_event** (Lead) | Y — event_datetime; intraday funnel timing | Y — PDP product views drive demand signal | N | N | N | N | N | N | N | N | N | Y — funnel-stage drop-off analysis | N | session_id, event_id |
| **fact_classified_listing_event** (M6) |  |  | N | N |  | N |  | N | N |  | N | N |  | listing_ref, event_id |
| **fact_classified_listing_snapshot** (Lead) | Y — listing created date; active-inventory over time | Y — category-level NL supply | N | N | Y — listings per seller account (ring detection) | N | N | N | N | N | N | N | N | listing_ref |
| **fact_seller_performance_snapshot** (M2) |  | N | N | N |  | N | N | N | N | N | N | N |  | (period bucket) |
| **fact_customer_review** (M6) |  |  |  |  |  | N |  | N | N | N | N | N |  | review_id |
| **fact_customer_complaint** (Lead) | Y — case open date; complaint volume trend | N | N | Y — complaints per customer; CLV impact | N | N | Y — attributed contact channel mix | N | N | N | N | N | N | canonical_case_key |

Cells pre-marked `N` are non-applicable per fact grain. Cells pre-marked with degenerate dim notes (last column) are NOT separate dimensions. **Empty cells are for owners to fill** with `Y — <justification>` or `N`.

---

## Conformance principles to keep in mind

- **dim_date** is role-played: a single physical `dim_date` table services every date FK on every fact. Note in justification which role (e.g. "as `picked_date`").
- **dim_customer** is shared across POS, EC, NL, reviews, complaints — that's why M2's identity resolution is the keystone.
- **dim_product** is shared across catalogue/marketplace/NL — that's why M3's product master is the keystone.
- **dim_seller** appears on every fact that touches a marketplace or NL transaction.
- **dim_seller_risk_tier** is a separate dim (NOT just a column on dim_seller) because it has slowly-changing tier definitions independent of seller identity.

## Workflow for filling cells

1. Open this file in Phase 5 (Sun 17 May).
2. Each owner writes `Y — <reason>` or `N` in their fact's row.
3. Lead reviews on Mon 18 May; pushes back on tick-only or weak justifications.
4. Final matrix becomes Report Section 4.

## Cross-process value

The whole point of the Bus Matrix is showing CEO/finance that — with conformed dimensions — Sales (POS+EC+marketplace) and Inventory and Support data can all be sliced by the SAME date / product / store / customer. That's how reconciliation becomes possible in M2.
