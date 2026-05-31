# Anomaly Reason Code Registry

Every Silver row that fails a quality check gets `anomaly_flag = TRUE` and **one or more reason codes from this registry** in `anomaly_reason_code` (comma-separated for multiple).

**Rules:**
1. Use only codes registered here. If you need a new code, add it to this file in the same PR; the lead approves taxonomy changes.
2. Codes are `SCREAMING_SNAKE_CASE`, ≤ 32 chars.
3. Each code maps to one canonical `data_quality_status` (column 3) — but a member may downgrade if context demands (document why in the PR).
4. Each code suggests one canonical `metric_certainty_level` (column 4) — same rule.

---

## Universal codes (any domain may use)

| Code | Meaning | Canonical status | Canonical certainty |
|---|---|---|---|
| `DATE_PARSE_FAIL` | Source date string couldn't be parsed by any T1 converter | FLAGGED_ANOMALY | UNRELIABLE |
| `DATE_FUTURE` | Parsed date is after 2024-09-14 (project window end) | FLAGGED_AMBIGUOUS | INFERRED |
| `DATE_BEFORE_RANGE` | Parsed date is before 2024-03-01 (project window start) | FLAGGED_AMBIGUOUS | INFERRED |
| `STATUS_UNMAPPED` | Source status code doesn't appear in `silver_status_code_mapping` | FLAGGED_ANOMALY | UNRELIABLE |
| `ORPHAN_FK` | Logical FK to another table has no matching row | FLAGGED_ANOMALY | UNRELIABLE |
| `NEGATIVE_QTY` | A quantity column is negative where physically impossible | FLAGGED_ANOMALY | UNRELIABLE |
| `NEGATIVE_AMOUNT` | An amount column is negative where business-impossible | FLAGGED_ANOMALY | UNRELIABLE |
| `MISSING_REQUIRED_FIELD` | A non-nullable business field is null or empty | FLAGGED_ANOMALY | UNRELIABLE |

## Customer & identity (M2)

| Code | Meaning | Canonical status | Canonical certainty |
|---|---|---|---|
| `IDENTITY_AMBIGUOUS` | Match confidence in 0.70–0.89 band | FLAGGED_AMBIGUOUS | INFERRED |
| `PLACEHOLDER_ID_COLLISION` | Customer_id used as placeholder collides with a real customer | FLAGGED_ANOMALY | UNRELIABLE |
| `FUZZY_MATCH_LOW_CONF` | Match confidence < 0.65 (for B4 product fuzzy) or < 0.70 (for T4 identity); routed to anonymous bucket / unmatched | EXCLUDED_WITH_REASON | UNRELIABLE |
| `EMAIL_MALFORMED` | Email failed regex validation | FLAGGED_ANOMALY | UNRELIABLE |
| `PHONE_NORMALISATION_FAIL` | Phone couldn't be normalised to E.164 | FLAGGED_ANOMALY | UNRELIABLE |

## Product (M3)

| Code | Meaning | Canonical status | Canonical certainty |
|---|---|---|---|
| `SKU_PRODUCT_MISMATCH` | SKU resolves to different products in catalogue vs marketplace seller listing | FLAGGED_ANOMALY | UNRELIABLE |
| `SKU_NOT_IN_CATALOGUE` | Marketplace listing references a SKU absent from `pc_products` | FLAGGED_ANOMALY | UNRELIABLE |
| `PRODUCT_FUZZY_MATCH` | T5 fuzzy-matched, not exact SKU; carries `match_confidence`. **B4 tier (per instructor catalog):** accept ≥0.75, manual review queue 0.65–0.75, reject <0.65 | FLAGGED_AMBIGUOUS | INFERRED |
| `PRODUCT_NAME_CONFLICT` | Seller's `product_name` disagrees with catalogue (catalogue wins) | FLAGGED_ANOMALY | INFERRED |

## Inventory (M4)

| Code | Meaning | Canonical status | Canonical certainty |
|---|---|---|---|
| `RECONSTRUCTED_SNAPSHOT` | Snapshot row produced by T6 ATP reconstruction (no original source row) | RECONSTRUCTED | INFERRED |
| `MISSING_SNAPSHOT_DAY` | Source had a gap day for a SKU/store/warehouse | FLAGGED_ANOMALY | UNRELIABLE |
| `ATP_POSITIVE_PHYSICAL_ZERO` | `atp_qty > 0` while `physical_qty = 0` | FLAGGED_ANOMALY | UNRELIABLE |
| `OPEN_BOX_AS_NEW` | Return receipt with `condition_on_receipt='OPENED'` but `restocked_as_condition='NEW'` (A10: 12 receipts) | FLAGGED_ANOMALY | UNRELIABLE |
| `RESTOCK_BEFORE_INSPECTION` | Return receipt with `inspection_status='PENDING'` but `restocked_qty > 0` (A7: 10 receipts). Stock re-entered sellable state before condition was verified. Distinct from A10 — overlap but not equal | FLAGGED_ANOMALY | UNRELIABLE |
| `MOVEMENT_NULL_REF` | Inventory movement has NULL `reference_number` (no source order) | FLAGGED_AMBIGUOUS | INFERRED |
| `OVERSELL` | ATP reported as 0 because raw computation went negative | FLAGGED_ANOMALY | INFERRED |

## Sales / orders / payments / delivery / returns (M5)

| Code | Meaning | Canonical status | Canonical certainty |
|---|---|---|---|
| `CANCELLED_WITH_REVENUE` | EC order is CANCELLED but `subtotal_excl_tax > 0` is still flowing into revenue | FLAGGED_ANOMALY | UNRELIABLE |
| `PAYMENT_AFTER_CANCEL` | Payment captured strictly after the order's cancellation timestamp | FLAGGED_ANOMALY | UNRELIABLE |
| `TAX_INCLUSION_MISMATCH` | Channel uses different tax-inclusion convention than canonical (POS incl, EC excl, marketplace mixed) | FLAGGED_AMBIGUOUS | INFERRED |
| `DELIVERY_BEFORE_SHIP` | Earliest delivery event predates `dc_shipments.created_datetime`, or DELIVERED event before SHIPPED/PICKED_UP | FLAGGED_ANOMALY | UNRELIABLE |
| `COURIER_CLOCK_DRIFT` | Material time inconsistency between courier's events and shipment metadata | FLAGGED_AMBIGUOUS | INFERRED |
| `BOPIS_NO_PICKUP_EVENT` | EC order with `delivery_method_code='BOPIS'` and `order_status='DELIVERED'` has no `BOPIS_COLLECTED` event in `dc_delivery_events` | FLAGGED_AMBIGUOUS | INFERRED |
| `REFUND_PARTIAL_PERIOD_AMBIGUITY` | Partial refund spans periods (B2 case) — exposed in both `revenue_impact_*_period` columns | FLAGGED_AMBIGUOUS | INFERRED |
| `ATTRIBUTION_SESSION_BRIDGE` | T9 inferred campaign attribution via session bridge (not promo code). Emits attribution_confidence = 0.85 on the row per instructor catalog | CLEAN | INFERRED |

## NL / Marketplace / T&S / Reviews / Support (M6)

| Code | Meaning | Canonical status | Canonical certainty |
|---|---|---|---|
| `NL_SELLER_SOLD_AS_REVENUE` | NexaLocal seller-marked-sold event being treated as confirmed revenue (must NOT be). Feeds B6 Estimated NL GMV model with weight 0.60 | FLAGGED_ANOMALY | ESTIMATED |
| `RELISTED_AFTER_SOLD` | Same seller + same image_hash + listing was previously SOLD or EXPIRED | FLAGGED_ANOMALY | INFERRED |
| `IMAGE_HASH_REUSED` | Same `image_hash` appears across ≥ 2 different sellers (coordination signal). Row-level certainty is `INFERRED` (we observed the coordination but coordination ≠ provable fraud); business resolution per instructor's catalog is `UNRELIABLE→EXCLUDED` (accounts suspended, listings removed) — see Report Section 8 A13 | FLAGGED_ANOMALY | INFERRED |
| `REVIEW_BEFORE_DELIVERY` | `rv_reviews.days_post_delivery < 0` | FLAGGED_ANOMALY | UNRELIABLE |
| `DUPLICATE_CASE` | `cs_cases.is_duplicate_flag=1` with a populated `canonical_case_ref` | FLAGGED_ANOMALY | INFERRED |
| `ESTIMATED_NL_GMV` | NL listing event/snapshot value is modelled via B6 GMV formula (T7b): `SELLER_SOLD×0.60 + PHN_REVEAL×0.15 + CHAT×0.08 + OFFER_ACC×0.30`, each multiplied by `listing_confidence_score` (T7), with ±35% confidence band | CLEAN | ESTIMATED |
| `LISTING_LOW_CONFIDENCE` | T7 listing confidence score < 0.30 | FLAGGED_AMBIGUOUS | UNRELIABLE |
| `SELLER_HIGH_RISK` | T10 seller trust score < 0.30 (placed in 5th risk tier) | FLAGGED_ANOMALY | INFERRED |
| `MANUAL_CHANNEL_ATTRIBUTION` | `cs_cases` channel field was free-text manually entered (error-prone) | FLAGGED_AMBIGUOUS | INFERRED |

---

## Documentation-only anomalies (no row-level codes)

Some anomalies are **architectural / schema observations or judgement calls** that get written up in the Report (Sections 7 or 8) rather than flagged on individual Silver rows.

**A-series documentation-only:**

| ID | Theme | Owner | Where it lives |
|---|---|---|---|
| **A3** | Tax / shipping inclusion mismatch (schema convention — POS incl, EC excl, marketplace mixed) | M5 | Report Section 7 (T8 narrative) |

The `TAX_INCLUSION_MISMATCH` code is registered above (line 62) — use it on Gold facts that mix sources, but the row-level Silver flagging is not required for A3 per M5.md Task 13.

**B-series documentation-only (judgement calls):**

| ID | Theme | Owner | Where it lives |
|---|---|---|---|
| **B1** | Campaign attribution edge cases (orders in BTS window without promo OR T9 bridge match) | Lead | Report Section 8 (Lead Task 27 + 37) |
| **B4** | NL fuzzy-match confidence threshold for product master | M3 | Report Section 7 (T5 design narrative) |
| **B5** | Cross-channel customer match probabilistic threshold | M2 | Report Section 7 (T4 design narrative) |
| **B8** | Seller trust score formula weights + tier boundaries | M2 | Report Section 7 (T10 design narrative) |

**B-anomalies that DO have row-level codes (use them):**

- **B2** → `REFUND_PARTIAL_PERIOD_AMBIGUITY` (M5, refund_events that span periods)
- **B3** → `MOVEMENT_NULL_REF` (Lead, inventory movements with NULL ref)
- **B6** → `ESTIMATED_NL_GMV` (M6, NL revenue rows that are modelled not platform-recorded)
- **B7** → `BOPIS_NO_PICKUP_EVENT` (Lead, EC BOPIS DELIVERED orders without pickup event)

---

## How to use multiple codes

Comma-separate, no spaces:
```
DATE_PARSE_FAIL,STATUS_UNMAPPED
```

When multiple codes apply to one row, set `data_quality_status` to the **most severe** of the suggested statuses (rank: `EXCLUDED_WITH_REASON > FLAGGED_ANOMALY > FLAGGED_AMBIGUOUS > RECONSTRUCTED > CLEAN`).

When multiple codes apply, `metric_certainty_level` follows the **least certain** (rank: `UNRELIABLE > ESTIMATED > INFERRED > CONFIRMED`).

---

## Adding a new code

1. Add the row to the appropriate domain table above.
2. In the same PR, update any Silver notebook that uses it.
3. Lead approves PR (taxonomy changes get scrutiny).
4. Note in the report Section 8 (Anomaly Discovery) which codes you added and why.
