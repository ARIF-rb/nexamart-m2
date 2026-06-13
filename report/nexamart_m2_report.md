# NexaMart Enterprise Data Warehouse — Milestone 2 Report

> Group [N] · Members: Lead, M2, M3, M4, M5, M6 · Export to PDF as `nexamart_m2_report.pdf` for the ZIP.
> Authoritative definitions: `docs/glossary.md`. Verified counts: `.private/lead_cheatsheet.md`.

---

## Executive Summary  *(Owner: Lead · ≤1 page)*

The Back-to-School campaign question, the headline reconciled numbers (GSV → NCR, Confirmed GMV,
Estimated Classified GMV with band, Net Margin), and the one-line verdict. Written for the CEO/CFO/CDO.

*(TODO: fill after S4/S5 are final.)*

---

## Section 1 — Anomaly Resolution Report  *(All members; owner per anomaly)*

For **each Category A** anomaly: detection method, root cause, the specific PySpark fix logic, the
post-fix verification result (**affected row count before → after**), and the business impact in
financial/operational terms. For **each Category B**: precise description of the ambiguity, the
chosen interpretation, the PySpark implementation, the business justification for choosing it over
alternatives, **and the quantified impact had the alternative been chosen** (brief §8.2).

Cross-references: detection = `sql/anomaly_discovery.sql`; resolution code = `notebooks/05_anomaly_resolution.ipynb`; per-anomaly docs = `sql/anomaly_resolution.sql`.

**Detection verified (run 14 Jun 2026 as `NEXAMART_ENGINEER` against live `NEXAMART_SILVER`).** **18 of 24
anomalies matched the expected fingerprints EXACTLY:** A1=94, A2=27, A4=449, A5=5, A6=8, A7=10, A8=21, A9=1,
A10=12, A11=178, A12=3, A13=3 rings, A14=18 strict, A15=25, A16=7, B1=126, B3=175, B7=25. The remaining six are,
by design, **not single-count SQL detections**: A3 (schema-wide tax-basis comparison), B4 (catalogue-match
threshold), B6 (Estimated-GMV signal model), and B5/B8 (probabilistic identity-merge / seller-trust scores) are
computed in the `05` PySpark resolution; B2 (cross-period partial refund, 1 row) is finalised there too.
Schema notes baked into the predicates: member-built Silver tables use base column names (`created_at`,
`snapshot_date`), not the lead-built `_parsed` variants; `captured_ts` is a TIMESTAMP while `status_ts_parsed`
is epoch-NUMBER; A9 is the cross-source `silver_ts_seller_listings` catalogue mismatch.

### Category A
| ID | Detection (live Silver predicate) | Root cause | Fix (method) | Before → After | Business impact | Owner |
|---|---|---|---|---|---|---|
| A1 | `order_status='CANCELLED' AND subtotal_excl_tax>0` ✓94 | cancelled orders left revenue on the line | ZEROED_CANCELLED_REVENUE | 94 → 0 | ₹6.15 Cr over-count removed | M5 |
| A2 | captured PG txn (`captured_ts` not null) after earliest CANCELLED status | capture fired post-cancel | FLAGGED_REVERSAL_REQUIRED | 27 → 0 | ₹1.08 Cr reversal liability | M5 |
| A3 | POS incl-tax vs EC excl-tax basis differ | mixed tax bases summed naively | NORMALISED_TAX_EXCLUSIVE | schema-wide | ₹16.25 Cr comparable basis | M5 |
| A4 | `event_type_code='SELLER_SOLD'` ✓449 | seller-sold counted as confirmed revenue | RELABELLED_ESTIMATED_GMV | 449 → 0 confirmed | ₹1.72 Cr moved to ESTIMATED | M6 |
| A5 | `atp_qty>0 AND physical_qty=0` ✓5 | ATP not decremented to physical | CORRECTED_ATP_TO_ZERO | 5 → 0 | oversell risk removed | Lead |
| A6 | `sellable_qty<0 OR physical_qty<0` ✓8 | negative inventory written | CORRECTED_ATP_TO_ZERO | 8 → 0 | stockout analysis fixed | M4 |
| A7 | `inspection_status='PENDING' AND restocked_qty>0` ✓10 | restock before inspection | ZEROED_RESTOCK_PRE_INSPECTION | 10 → 0 | ATP inflation removed | Lead |
| A8 | stores 3/7/12 × (1–7 Aug) absent from snapshots | snapshots not captured in ramp-up | RECONSTRUCTED_SNAPSHOT | ~21 reconstructed | allocation accuracy (1–7 Aug) | Lead |
| A9 | `silver_ts_seller_listings`: listing 42 / NX-TECH-0001 catalogue mismatch | seller feed contradicts catalogue | APPLIED_CANONICAL_PRODUCT | 1 → 0 | category revenue corrected | M3 |
| A10 | `condition_on_receipt='OPENED' AND restocked_as_condition='NEW'` | open-box restocked as NEW | CORRECTED_CONDITION_OPEN_BOX | 12 → 0 | price premium quantified | M4 |
| A11 | `customer_id='9999'` ✓178 | guest placeholder collides w/ real loyalty | REKEYED_GUEST_BUCKET | 178 → 0 | customer profile de-collided | M2 |
| A12 | self-join `image_hash`+seller, prior SOLD/EXPIRED, ACTIVE relist | listing relisted after sold | LINKED_RELISTING_EXCLUDED | 3 pairs | GMV double-count removed | Lead |
| A13 | `image_hash` shared by ≥2 seller accounts ✓3 rings | coordinated listing ring | FLAGGED_FRAUD_RING | rings flagged | trust & safety | M6 |
| A14 | `delivered_ts<pickup_ts` (strict) ✓18 | courier clock drift | CORRECTED_DELIVERY_TS / ESCALATED_MANUAL_REVIEW | 18 (>72h escalated) | on-time rate corrected | Lead |
| A15 | `days_post_delivery<0` | review before delivery | SET_VERIFIED_PURCHASE_FALSE | 25 → 0 verified | review-score KPI corrected | M6 |
| A16 | `is_duplicate_flag=TRUE` ✓7 | same complaint via many channels | DEDUPED_CANONICAL_CASE | 7 → deduped | complaint volume corrected | M6 |

### Category B
| ID | Ambiguity | Chosen interpretation | Quantified alternative | Owner |
|---|---|---|---|---|
| B1 | promo-less in-window + prior UTM | attribute 102 (conf 0.85) | not attributing understates ~₹1.11 Cr | Lead |
| B2 | Aug sale / Sep refund | recognise in return period | original-period reduces Aug NCR ~₹2.16 L | Lead |
| B3 | 175 PCK null-ref movements | probable missing-ref (INFERRED) | shrinkage reading overstates loss | Lead |
| B4 | NL title → catalogue | ≥0.75 match / 0.65–0.75 review | lower threshold injects false matches | M3 |
| B5 | cross-channel identity | merge ≥0.90 | 0.70 over-merges distinct customers | M2 |
| B6 | Estimated GMV formula | weighted signals + ±35% band | seller-sold-only mis-states | M2 |
| B7 | BOPIS no pickup event | treat as fulfilled (scan miss) | not-collected understates fulfilment | Lead |
| B8 | seller trust score | weighted 8-signal → 5 tiers | equal-weight unacceptable | M2 |

---

## Section 2 — Gold Rebuild Summary  *(Owner: Lead, with per-fact owners)*

Which Gold tables were affected by Silver corrections, which notebook sections were re-run, and
**row counts before vs after** rebuild. State which tables were **rebuild-exempt** (static lookups)
and why. Reference the affected → rebuild map in `notebooks/06_gold_rebuild.ipynb`. Reference
`dim_step` / clickstream for the Ch-15 funnel.

*(TODO: fill from 06 delta cells.)*

---

## Section 3 — Validation Outcomes  *(Owner: Lead)*

Results of all **10 validation checks across all iterations**. **How many iterations were required**,
what failed in each iteration, what was fixed, and the final state. Honest reporting of failures
found and fixed is graded higher than an implausible first-run pass.

| Iteration | Checks failed | Fix applied | Re-run result |
|---|---|---|---|
| 1 | *(TODO e.g. Check 2 orphan FKs, Check 4 net≠gross−disc−return)* | | |
| 2 | | | |
| Final | none | — | all 10 pass |

---

## Section 4 — KPI Reconciliation Report  *(Owner: Lead)*

Plain-business-language explanation of **why all seven teams reported different numbers** — Sales,
Finance, Inventory, Ecommerce, Store Operations, Marketplace, Support — with the reconciliation path
from each team's number to the single correct number. Include the **GSV → NCR waterfall** naming and
quantifying each deduction step. See `docs/reconciliation_method.md`.

*(TODO: waterfall chart + per-team narrative.)*

---

## Section 5 — Campaign Performance Conclusion  *(Owner: Lead)*

Was the Back-to-School campaign successful? Answer using **NCR, Net Margin, Inventory impact,
Fulfilment performance, Customer satisfaction signals, and Classified engagement — each with its
metric certainty level, never conflated**. Take a direct, defensible position.

*(TODO: the verdict, evidence, and the certainty-labelled KPI table.)*
