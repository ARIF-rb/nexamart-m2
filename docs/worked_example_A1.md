# Worked Example — One Anomaly End-to-End (A1)

A concrete trace of a single anomaly through all 7 M2 steps, so the workflow clicks. Every other
anomaly is a variation on this exact loop. Read alongside `../UNDERSTANDING_M2.md`.

**A1 — Cancelled orders still counted as revenue.** This is the headline bug that explains why Sales
reported *"+34%"* while Finance reported *"+11%."*

---

## The problem in plain words

When an e-commerce order is cancelled, the system sets `order_status = 'CANCELLED'` but **never zeroed
the revenue amount**. So cancelled orders still sum into the sales total. Sales' dashboard includes
them (inflated); Finance excludes them (lower, correct).

**Verified scale:** 94 EC orders in `silver_ec_orders` with `order_status = 'CANCELLED'` AND
`subtotal_excl_tax > 0`, worth ≈ ₹6.15 Cr. (Instructor catalogue quotes "~178" = 94 EC + ~84 POS
cancelled-incl-tax; the team defends the 94-EC figure — see `.private/resolution_targets.md`.)

---

## Step 1 — DETECT  (Snowflake SQL → `sql/anomaly_discovery.sql`, block A1)

One query that finds and counts the bad rows — this is your **before-count** and proof of scale.

```sql
SELECT COUNT(*) AS affected_rows,
       ROUND(SUM(subtotal_excl_tax), 2) AS revenue_at_risk
FROM silver_ec_orders
WHERE order_status = 'CANCELLED' AND subtotal_excl_tax > 0;
-- expect: affected_rows = 94, revenue_at_risk ≈ ₹6.15 Cr
```

---

## Step 2 — FIX  (Databricks PySpark → `notebooks/05_anomaly_resolution.ipynb`, cell A1)

Read Silver, zero the revenue on cancelled rows, **keep the audit trail**, write Silver back.

```python
cond = (F.col('order_status') == 'CANCELLED') & (F.col('subtotal_excl_tax') > 0)

# 1. correct the data
ec = ec.withColumn('subtotal_excl_tax',
                   F.when(cond, F.lit(0)).otherwise(F.col('subtotal_excl_tax')))

# 2. stamp the audit trail (flag + original reason stay; resolution added)
ec = ua.resolve(ec, cond, 'ZEROED_CANCELLED_REVENUE')

# 3. write corrected Silver back (overwrite — idempotent)
sf.write_to_snowflake(ec, 'silver_ec_orders', 'NEXAMART_SILVER', overwrite=True)
```

**Never delete the row.** After the fix it still carries `anomaly_flag = TRUE` and the original
`anomaly_reason_code = 'CANCELLED_WITH_REVENUE'`, and now also `resolution_applied = TRUE` +
`resolution_method = 'ZEROED_CANCELLED_REVENUE'`. The correction is visible and auditable.

**Verify:** re-run the Step 1 query against corrected Silver → it must return **0**.

---

## Step 3 — REBUILD GOLD  (Databricks → `notebooks/06_gold_rebuild.ipynb`)

`silver_ec_orders` feeds the keystone fact `fact_ecommerce_order_line`. Since Silver changed, rebuild
**only that fact** (not all 27 Gold tables — partial rebuilds are expected, brief §8.3).

```python
# re-run M1's fact_ecommerce_order_line build logic against corrected Silver
sf.write_to_snowflake(fact_ec, 'fact_ecommerce_order_line', 'NEXAMART_GOLD', overwrite=True)
```

Record before-vs-after row/revenue counts to prove only the intended table changed (report S2).

---

## Step 4 — VALIDATE  (Snowflake → `sql/validation_suite.sql`)

Run all 10 checks. The ones A1 touches:
- **Check 4 (additive sanity):** `net = gross − discount − return` should now hold.
- **Check 7 (campaign coverage):** campaign window still has rows.
- **Check 6 (certainty completeness):** no NULL `metric_certainty_level`.

Expect failures on the first run — that's normal. Iterate (fix → re-run) and **log every iteration
honestly** in report S3. Honest failure-and-fix logging is graded higher than a fake clean first run.

---

## Step 5 — KPI VIEW  (Snowflake → `sql/kpi_views.sql`, `NEXAMART_MARTS`)

With Gold clean, the revenue KPIs are correct. A1 directly affects **GSV** and **NCR**.

```sql
CREATE OR REPLACE VIEW vw_ncr AS
SELECT channel, period,
       SUM(net_revenue)            AS ncr,
       TRUE                        AS is_confirmed_transaction,  -- Finance-domain rule (Check 9)
       'CONFIRMED'                 AS metric_certainty_level     -- mandatory label
FROM NEXAMART_GOLD.fact_ecommerce_order_line
/* ... GROUP BY channel, period */;
```

Cancelled revenue is now zeroed, so `vw_ncr` no longer over-counts. The view is labelled CONFIRMED and
feeds the dashboard (marts only).

---

## Step 6 — DASHBOARD  (Power BI / Tableau → Executive Summary page)

A1 appears as the first deduction step of the **GSV → NCR waterfall**: *"GSV − Cancellations = …"*.
The executive sees ₹6.15 Cr of cancellations falling out — visible, not hidden. Connect to
`vw_ncr` / `vw_gsv` only, never to raw Gold.

---

## Step 7 — RECONCILE & CONCLUDE  (Report S4 + S5)

In business language:

> *"Sales reported +34% because their query included 94 cancelled orders worth ₹6.15 Cr that were
> never collected. Removing them (A1) is the single largest reason Sales and Finance disagreed. The
> reconciled figure is Finance's NCR."*

That one sentence is the point of the whole milestone — A1 is one named, quantified line in the story
of why the teams differed.

---

## The lifecycle in one picture

```
detect (94 rows, ₹6.15 Cr)  →  fix in PySpark (zero + audit trail)  →  re-detect (0)
   →  rebuild fact_ecommerce_order_line  →  validation passes
   →  vw_ncr now correct  →  waterfall on dashboard  →  "this is why Sales over-counted"
```

---

## How a Category B anomaly differs (e.g. B1 — campaign attribution)

Same 7 steps, but **Step 2 has no single right answer**. 126 promo-less orders in the campaign window
had a prior campaign-banner session — do they count as campaign sales?

- You don't zero anything. You **decide** ("attribute the 102 orders that have a UTM session, with
  `attribution_confidence = 0.85`"), tag them `b_classification = 'ATTRIBUTED'`, and **defend the
  choice in writing** — including how the number would change under the alternative (~₹1.11 Cr if not
  attributed). The defence is the deliverable, weighted as much as the code.

Every one of the other 23 anomalies is a variation on this A1 loop (Category A = fix deterministically;
Category B = decide + defend).
