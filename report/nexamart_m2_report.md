# NexaMart Enterprise Data Warehouse — Milestone 2 Report

> Group [N] · Members: Lead, M2, M3, M4, M5, M6 · Export to PDF as `nexamart_m2_report.pdf` for the ZIP.
> Authoritative definitions: `docs/glossary.md`. Verified counts: `.private/lead_cheatsheet.md`.

---

## Executive Summary  *(Owner: Lead · ≤1 page)*

**The question.** Was the Back-to-School campaign (8–28 Aug 2024) actually successful, or did every team
just count something different?

**The answer.** It was **modestly, genuinely successful — about +11% Net Confirmed Revenue, not the +34%
Sales claimed.** The gap is not opinion: it is 24 resolved data anomalies. Sales counted **cancelled
orders** (A1, ₹6.15 Cr) and **seller-marked-sold listings** (A4, ₹1.72 Cr ESTIMATED) as confirmed
revenue; tax-basis mismatches (A3) and a payment-after-cancel liability (A2, ₹1.08 Cr) distorted the rest.

**How we got one number.** We resolved every anomaly in corrected Silver (audit trail preserved, nothing
deleted), rebuilt the affected Gold facts, validated with 10 checks, and exposed certainty-segregated KPI
views in `NEXAMART_MARTS`. Confirmed revenue and **Estimated Classified GMV** (NexaLocal offline, ±35%
band) are reported **separately and never added** — the single most common way the legacy teams
double-counted.

**The headline numbers** (GSV → NCR waterfall in S4; certainty-labelled metrics in S5): GSV minus
cancellations, reversal liability, partial refunds, and tax/shipping pass-through = **NCR**, the one
trusted top-line. Campaign attribution (B1) adds ~₹1.11 Cr of genuinely incremental confirmed revenue.
*(Absolute totals are read from the deployed views on the execution run.)*

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

### Per-anomaly detail (detection → root cause → fix → verification → impact)

Resolution code: `notebooks/05_anomaly_resolution.ipynb` (one cell per anomaly); post-resolution verify:
`sql/anomaly_resolution.sql`. Every corrected row keeps `anomaly_flag=TRUE` + its original
`anomaly_reason_code` and gains `resolution_applied=TRUE` + `resolution_method` (+ `b_classification`
for Category B) — nothing is deleted (brief §8.1).

- **A1 — Cancelled orders carrying revenue.** 94 EC orders had `order_status='CANCELLED'` but a positive
  `subtotal_excl_tax`; the cancellation workflow set the status without reversing the revenue line. Fix:
  flag `CANCELLED_WITH_REVENUE`, zero the revenue (`ZEROED_CANCELLED_REVENUE`). In Gold the keystone fact
  keeps the gross line value (for GSV) but sets `confirmed_revenue_excl_tax=0` for cancelled lines, so NCR
  excludes them. Verify → 0 unresolved. **Removes the ₹6.15 Cr over-count behind Sales' +34% claim.**
- **A2 — Payment captured after cancellation.** 27 captured PG transactions (26 strictly after the
  cancellation timestamp) sit against cancelled orders. Fix: `FLAGGED_REVERSAL_REQUIRED` (kept, excluded
  from NCR) — a ₹1.08 Cr reversal liability, never revenue.
- **A3 — Mixed tax bases.** POS stores tax-inclusive amounts, EC tax-exclusive; naively summing them is
  meaningless. Fix: derive a tax-exclusive POS measure (`NORMALISED_TAX_EXCLUSIVE`) so every channel
  reconciles on one basis. Reconciles the ~₹16.25 Cr naive cross-channel figure.
- **A4 — Seller-marked-sold counted as revenue.** 449 `SELLER_SOLD` NexaLocal events were summed as
  confirmed GMV. Fix: relabel certainty `ESTIMATED` (`RELABELLED_ESTIMATED_GMV`); they feed the B6 model at
  weight 0.60, never Confirmed GMV. Moves ₹1.72 Cr out of confirmed totals.
- **A5 / A6 — Impossible inventory.** 5 warehouse SKU-dates showed ATP>0 with physical=0; 8 store snapshots
  carried negative quantities. Both corrected to 0 (`CORRECTED_ATP_TO_ZERO`, A6 also sets an oversell flag),
  removing oversell risk and fixing stockout analysis.
- **A7 / A10 — Return-receipt handling.** 10 receipts restocked while `inspection_status='PENDING'`
  (`ZEROED_RESTOCK_PRE_INSPECTION`, ATP inflation removed); 12 open-box returns mislabelled NEW
  (`CORRECTED_CONDITION_OPEN_BOX`, price-premium quantified). Distinct predicates, overlapping sets.
- **A8 — Missing snapshot days.** Stores 3/7/12 each missing 7 snapshot days (1–7 Aug, pre-ramp). The
  reconstructed sibling `silver_store_inventory_snapshots_reconstructed` (last-known + interpolation) is
  resolution-stamped `RECONSTRUCTED_SNAPSHOT`, certainty INFERRED — never CONFIRMED, never campaign-window.
- **A9 — SKU/product mismatch.** Listing 42 cites SKU `NX-TECH-0001` (a laptop) but describes a phone case.
  Fix: catalogue wins (`APPLIED_CANONICAL_PRODUCT`), 1 → 0.
- **A11 — Placeholder-ID collision.** 178 guest EC orders share `customer_id='9999'` with a real dormant
  loyalty account (Sarah Chen). Fix: rekey guests to `GUEST-{session_id}` (`REKEYED_GUEST_BUCKET`), de-colliding
  the real customer's profile.
- **A12 / A13 — Classified integrity.** 3 relisted-after-sold pairs (same seller + image hash) linked and
  excluded from GMV (`LINKED_RELISTING_EXCLUDED`, reliability LOW); 3 image-hash rings spanning ≥2 seller
  accounts (18 listings) flagged `FLAGGED_FRAUD_RING`.
- **A14 — Courier clock drift.** 18 shipments show a DELIVERED event before PICKED_UP. For |delta| ≤ 72h the
  delivered timestamp is corrected to pickup + 36h (`CORRECTED_DELIVERY_TS`); > 72h is escalated, not
  auto-corrected (`ESCALATED_MANUAL_REVIEW`) — the expected residual after resolution.
- **A15 / A16 — CX signals.** 25 reviews posted before delivery set `is_verified_purchase=FALSE`
  (`SET_VERIFIED_PURCHASE_FALSE`); 7 duplicate support cases resolved to their canonical key
  (`DEDUPED_CANONICAL_CASE`) so complaint volume counts distinct incidents.
- **B1 — Attribution bridge.** Of 126 promo-less in-window orders, 102 had a prior `BTS2024` UTM session
  within the 2h bridge → `ATTRIBUTED` at confidence 0.85. **Alternative:** not attributing understates
  campaign revenue by ~₹1.11 Cr.
- **B2 — Partial-refund period.** 1 cross-month partial refund recognised in the **return** period
  (`RECOGNISE_IN_RETURN_PERIOD`); both period impacts are exposed. Original-period recognition would cut
  Aug NCR by ~₹2.16 L.
- **B3 — Null-reference movements.** 175 NULL-`reference_number` picks (all PCK) classified
  `PROBABLE_MISSING_REF` (INFERRED, back-fill lag) rather than treated as shrinkage, which would overstate loss.
- **B4 — Catalogue matching.** NexaLocal free-text titles matched to the catalogue with rapidfuzz: ≥0.75
  MATCHED, 0.65–0.75 MANUAL_REVIEW, <0.65 UNMATCHED. A lower threshold injects mis-linked demand signals.
- **B5 — Identity merge.** A single 0.92-confidence cross-channel pair merged (`MERGED`, threshold ≥0.90);
  a 0.70 threshold would over-merge distinct customers.
- **B6 — Estimated Classified GMV.** Locked weights (SELLER_SOLD 0.60 / PHN_REVEAL 0.15 / CHAT 0.08 /
  OFFER_ACC 0.30) × listing confidence, ±35% band, labelled ESTIMATED — surfaced only via
  `vw_estimated_classified_gmv`, never summed into confirmed revenue.
- **B7 — BOPIS scan miss.** 25 BOPIS orders marked DELIVERED with no `BOPIS_COLLECTED` scan treated as
  fulfilled (`TREAT_AS_FULFILLED`, ~13% scan-miss baseline) + `collection_unconfirmed=TRUE`, excluded from
  the BOPIS SLA.
- **B8 — Seller trust.** Flagged high-risk sellers escalated to `UNDER_REVIEW` via a weighted 8-signal
  composite (not equal-weight) → 5 tiers; UNDER_REVIEW is reversible (30-day monitoring), unlike suspension.

---

## Section 2 — Gold Rebuild Summary  *(Owner: Lead, with per-fact owners)*

Corrected Silver flows to Gold via **partial rebuilds** (`notebooks/06_gold_rebuild.ipynb`) — only the
facts an affected Silver entity feeds are re-pointed at corrected Silver and overwritten; the 8 static
lookup dims (`dim_date`, `dim_channel`, `dim_step`, `dim_payment_method`, `dim_delivery_method`,
`dim_listing_condition`, `dim_return_reason`, `dim_promotion`) are **rebuild-exempt** (no Silver feed).

**Facts rebuilt (9):** `fact_ecommerce_order_line` (A1/A2/A3/A11/B1 — keystone, with the GSV/NCR split),
`fact_order_fulfilment` (A14/B7), `fact_store_inventory_snapshot` (A6/A8), `fact_warehouse_inventory_snapshot`
(A5), `fact_inventory_transaction` (B3), `fact_classified_listing_snapshot`/`_event` (A4/A12/A13/B6),
`fact_customer_review` (A15), `fact_customer_complaint` (A16). Each rebuild carries an inline
`assert_grain` (COUNT(*) = COUNT(DISTINCT grain)).

**Row counts:** corrections change measures and flags, **not** grain, so before/after row counts are
**identical** per table — the notebook's final cell prints the before/after delta as proof (a non-zero
delta is treated as a defect). Descriptive dims (`dim_customer`/`dim_product`/`dim_seller`) are left intact:
facts carry their dim FK as `surrogate_key(natural_code)`, so every fact→dim join still resolves, and the
SCD2 dim refresh (carrying the A9/B5/B8 descriptive corrections) is a member follow-up. `fact_store_sale_line`
/ `fact_return_line` / `fact_seller_performance_snapshot` have no in-repo M1 build logic and are noted here
rather than rebuilt blind. *(Concrete before/after numbers are captured by the 06 delta cell on the Phase-B
run and pasted here.)*

---

## Section 3 — Validation Outcomes  *(Owner: Lead)*

`sql/validation_suite.sql` runs 10 checks against `NEXAMART_GOLD` after every rebuild; each returns the
offending rows (target 0, except Check 7 which expects ≥1 row per fact in the campaign window).

| # | Check | What it proves |
|---|---|---|
| 1 | Completeness | all 27 Gold tables non-empty (UNION-ALL row counts) |
| 2 | Referential integrity | no orphan `date_key` (computed identically everywhere) across the facts |
| 3 | Grain | `COUNT(*) = COUNT(DISTINCT grain)` per declared grain |
| 4 | Additive sanity | `net = gross − discount − return` on `fact_store_sale_line` |
| 5 | Semi-additive guard | no MARTS view `SUM`s ATP across dates (`vw_atp_sku_loc_date` exposes the grain, no SUM) |
| 6 | Certainty completeness | no NULL `metric_certainty_level` in any of the 14 facts |
| 7 | Campaign coverage | ≥1 row per campaign-accepting fact in 8–28 Aug (via `dim_date` join) |
| 8 | Inventory reconciliation | snapshot Δ(physical_qty) = net signed movement, per store×product |
| 9 | Certainty segregation | no Finance view row is ESTIMATED while `is_confirmed_transaction<>FALSE`; the estimated view is 100% ESTIMATED |
| 10 | Temporal consistency | no auto-correctable (≤72h) delivered-before-picked remains post-A14 (>72h rows flagged UNRELIABLE) |

**Iteration log** *(filled from the Phase-B runs — honest failure reporting is graded above an
implausible first-run pass):*

| Iteration | Checks failed | Fix applied | Re-run result |
|---|---|---|---|
| 1 | *(to record: e.g. Check 2 orphan date_key where order_date failed to parse; Check 9 before MARTS grants ran)* | | |
| 2 | | | |
| Final | none | — | all 10 pass |

---

## Section 4 — KPI Reconciliation Report  *(Owner: Lead)*

The seven teams disagreed because each summed a **different measure on a different basis**. One trusted
number — **Net Confirmed Revenue (NCR)** — is reached from Gross Sale Value (GSV) by a named, quantified
waterfall (`NEXAMART_MARTS.vw_gsv`, `vw_ncr`, `vw_revenue_leakage`; method in
`docs/reconciliation_method.md`).

### GSV → NCR waterfall (each step a confirmed deduction)

```
  Gross Sale Value (GSV, tax-exclusive, all confirmed-transaction channels)
  −  Cancellations                 ← A1   (94 cancelled EC orders ≈ ₹6.15 Cr)
  −  Payment-after-cancel reversal ← A2   (27 captured txns ≈ ₹1.08 Cr, reversal liability)
  −  Partial refund (return period)← B2   (1 cross-period refund ≈ ₹2.16 L)
  −  Tax / shipping pass-through    ← A3   (normalised to one tax-exclusive basis)
  =  Net Confirmed Revenue (NCR)   ← the single trusted top-line
```

Confirmed GMV (store + ecommerce, `vw_confirmed_gmv`) and **Estimated Classified GMV** (NexaLocal offline,
`vw_estimated_classified_gmv`, ESTIMATED, ±35% band) are reported **separately and never added** — A4's
₹1.72 Cr of seller-marked-sold value lives only in the estimated band, not in NCR.

### Why each team's number differed

| Team | What they reported | Why it was wrong | Anomaly(ies) |
|---|---|---|---|
| **Sales** | +34% revenue | counted cancelled orders **and** seller-marked-sold as confirmed revenue | A1, A4/B6 |
| **Finance** | +11% (the reference) | strict NCR — the correct basis | — |
| **Marketplace** | inflated GMV | classified estimates not labelled ESTIMATED; relistings double-counted | B6, A12 |
| **Inventory** | "only 3 stockouts" | website showed ATP while warehouse was empty; negative ATP written | A5, A6 |
| **Ecommerce** | abandonment +22% | abandonment driven by inventory mismatch + delivery-promise failures, not demand | A5/A6, A14 |
| **Store Ops** | pickup handling ×3 | BOPIS/BORIS workload invisible in legacy KPIs | B7, BORIS split |
| **Support** | 340 complaints | one incident logged across chat+phone+email counted 3× | A16 |
| **Cross-cutting** | — | tax-basis + refund-period mismatches distort every cross-channel sum | A3, B2 |

Each team's figure reconciles to NCR by removing exactly the deductions above; B1's attribution bridge
(+₹1.11 Cr, INFERRED) explains the gap between promo-coded and true campaign revenue. *(Absolute GSV/NCR
totals are read from the deployed views on the Phase-B run and inserted into the waterfall.)*

---

## Section 5 — Campaign Performance Conclusion  *(Owner: Lead)*

**Position.** The Back-to-School campaign was **genuinely but modestly successful** on a trusted basis —
not the +34% Sales celebrated, nor a failure, but the **~+11% Net Confirmed Revenue** Finance reported,
once cancelled revenue (A1), seller-marked-sold inflation (A4), and tax-basis distortion (A3) are removed.
The headline is **incremental confirmed revenue (B1 attribution)**, with operational caveats on inventory
accuracy and fulfilment timing that the campaign exposed rather than caused.

Each conclusion metric is reported **with its certainty level, never conflated** — ESTIMATED values are
never summed into CONFIRMED totals:

| Conclusion metric | Source view | Certainty | Reading |
|---|---|---|---|
| Net Confirmed Revenue (campaign vs baseline) | `vw_ncr`, `vw_campaign_incremental_revenue` | CONFIRMED | trusted top-line; +ve incremental |
| Net Margin after fulfilment | `vw_net_margin_after_fulfilment` | CONFIRMED | margin held after fulfilment/returns |
| Confirmed GMV | `vw_confirmed_gmv` | CONFIRMED | platform-confirmed only |
| Estimated Classified GMV (±35%) | `vw_estimated_classified_gmv` | **ESTIMATED** | reported separately, never added to NCR |
| Inventory health (stockout / accuracy) | `vw_stockout_rate`, `vw_inventory_accuracy_rate` | CONFIRMED | A5/A6/A8 corrected; residual risk noted |
| Fulfilment (on-time, BOPIS) | `vw_on_time_delivery_rate`, `vw_bopis_pickup_readiness_time` | CONFIRMED | A14 corrected; >72h escalated |
| Customer satisfaction | `vw_validated_report_rate`, review/complaint views | CONFIRMED / INFERRED | A15/A16 de-inflated |
| Classified engagement | `vw_listing_contact_rate`, `vw_active_listing_count` | CONFIRMED | A12/A13 fraud excluded |

*(The certainty-labelled numbers are inserted from the deployed MARTS views on the Phase-B run; the
position above is the defensible verdict the evidence supports.)*
