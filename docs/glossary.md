# NexaMart Business Glossary — Authoritative KPI Definitions

Where industry usage differs from this document, **NexaMart's definition wins**. The brief is explicit about this.

This glossary applies across all six domains. Members must use these terms consistently in code (column names), tests, and the report.

---

## Revenue & transaction terms

| Term | Definition |
|---|---|
| **GSV** — Gross Sale Value | Full face value at the moment of completion, before any deductions. Includes price + tax + shipping. **Counted regardless of payment capture.** |
| **NCR** — Net Confirmed Revenue | GSV − discounts − cancellations − full refunds − partial refunds − tax (pass-through) − shipping fees (pass-through). **Excludes** NexaLocal seller-marked-sold *unless* a confirmed platform payment exists. |
| **Paid Revenue** | Revenue from orders with a confirmed payment gateway capture. Excludes pending / failed / disputed / reversed. |
| **Fulfilled Revenue** | Revenue from orders that have been physically delivered or BOPIS-picked-up. |
| **Gross Margin** | Fulfilled Revenue − COGS (from catalogue). **Excludes** fulfilment, return, shipping, commission costs. |
| **Net Margin** | Gross Margin − fulfilment labour − return processing − shipping subsidy − seller commission − payment fees − support cost share. |
| **Revenue Leakage** | GSV − NCR. High leakage during the campaign window is a warning signal. |

---

## GMV (Gross Merchandise Value) terms

| Term | Definition |
|---|---|
| **Confirmed GMV** | Total GMV via NexaMart payment platform: POS + EC + Marketplace FBN + Seller-fulfilled with platform payment. **Never includes NexaLocal offline transactions.** |
| **Estimated Classified GMV** | Modelled NexaLocal estimate from engagement signals. **Must always carry a confidence band** and be labelled `ESTIMATED`. **Never summed with Confirmed GMV unlabelled.** |

---

## Inventory terms

| Term | Definition |
|---|---|
| **POH** — Physical units On Hand | Physical units present (any status: sellable, damaged, quarantined, in-transit-inbound). |
| **ATP** — Available To Promise | Units available for sale right now. Negative results are reported as `0` plus an `oversell` flag. |
| **Reserved** | Units allocated to an open order but not yet shipped. |
| **Return-to-Restock** | Units physically returned by customer, inspected, deemed sellable, and put back into ATP pool. |

ATP is **semi-additive**: valid to sum across SKU/location on a single date, **invalid to sum across dates**. Document this in every fact comment that includes ATP.

---

## Channel & fulfilment terms

| Term | Definition |
|---|---|
| **BOPIS** — Buy Online, Pickup In-Store | Sale = **Online** channel. Fulfilment = **Store** channel. The fact carries both. |
| **BORIS** — Buy Online, Return In-Store | Return at store of an online purchase. Attributed to original **online** channel; store workload tracked separately as a store-ops metric. |
| **FBN** — Fulfilled By NexaMart | Marketplace seller's inventory but NexaMart picks/packs/ships. Counts as platform fulfilment. |
| **Seller Fulfilled** | Marketplace seller handles fulfilment themselves. May or may not use platform payment. |

---

## NexaLocal classified marketplace terms

| Term | Definition |
|---|---|
| **Active Listing** | Listing with status `ACTIVE` and last engagement event within trailing 30 days. |
| **Seller-Marked Sold** | Self-declaration by seller that their listing transacted. **Does NOT confirm money or item changed hands.** |
| **Listing Confidence Score** | 0.00–1.00 score from T7 formula. Inputs: listing age, response rate, price reasonableness, relist count (negative), report count (negative). |
| **Estimated Classified GMV** | See above. Always carries lower / point / upper bounds. |

---

## Customer identity & data quality terms

| Term | Definition |
|---|---|
| **Identity Confidence Score** | 0.00–1.00. **≥ 0.90** = deterministic merge; **0.70–0.89** = probabilistic merge with audit trail; **< 0.70** = do not merge without manual review (route to `anonymous_customer_key`). |
| **Metric Certainty Level** | Every metric carries one of `CONFIRMED` / `INFERRED` / `ESTIMATED` / `UNRELIABLE`. **Mixing without labels is a critical error.** |
| **CONFIRMED** | Backed by a platform-recorded transaction (POS receipt, EC order with payment capture, etc.). |
| **INFERRED** | Derived from indirect signals (e.g., reconstructed inventory snapshot, attribution via session bridge with high probability). |
| **ESTIMATED** | Modelled from engagement (e.g., Estimated Classified GMV). Always carries a confidence band. |
| **UNRELIABLE** | Source data quality unfit for reporting (e.g., row failed FK validation, source system known broken for that period). |

---

## Campaign attribution

**Campaign Attribution Window:** an order is attributed to the BTS campaign if **any** of:

- (a) A valid campaign promo code is applied, **OR**
- (b) Order placed 8–28 Aug 2024 AND the customer's prior session (within 2h of order) carried a campaign UTM tag (`BTS2024`), **OR**
- (c) BOPIS order in window for a campaign-eligible product.

T9 (campaign attribution bridge) implements rule (b). Rules (a) and (c) are direct joins, no bridge needed.

---

## Status canonical values (T2)

After T2 status code normalisation, every Silver table with a status column must produce a `canonical_status` from this set:

| canonical_status | Source examples |
|---|---|
| `OPEN` | EC `pending`/`processing`, POS `OPN`, Marketplace `PENDING` |
| `CONFIRMED` | EC `confirmed`, POS `CMP` (completed), Marketplace `CONFIRMED` |
| `IN_FULFILMENT` | EC `picked`/`packed`/`shipped`, Marketplace `IN_TRANSIT` |
| `DELIVERED` | EC `delivered`, POS implicit (no separate state), BOPIS `BOPIS_COLLECTED` |
| `CANCELLED` | EC `cancelled`, POS `ABT` (aborted), Marketplace `CANC` |
| `RETURNED` | rr_return_requests `APPROVED`+receipt, EC `returned` |
| `REFUNDED` | rr_refund_events `COMPLETED` |

The mapping table `silver_status_code_mapping` in Silver is built by `notebooks/_shared/seed_status_mapping.ipynb` after Bronze ingestion.

---

## Anomaly handling cardinal rules

1. **Never delete.** Bad rows stay; they get `anomaly_flag = TRUE`.
2. **Use only registered reason codes** from `docs/anomaly_taxonomy.md`. New codes go in via PR.
3. **Every Silver row** has `anomaly_flag`, `anomaly_reason_code`, `data_quality_status`, `metric_certainty_level`. Always populated, never null.
4. **Anomalies are not confined to the campaign window.** Pre-ramp (1–7 Aug) and post-campaign tail (29 Aug – 14 Sep) carry distinct DQ patterns.
