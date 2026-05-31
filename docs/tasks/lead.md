# Lead — infra, reconciliation & assembly (Heavy tier, ~50–58 hrs)

You own M2 infrastructure (MARTS schema), the cross-cutting anomalies (attribution, fulfilment,
inventory reconstruction), the reconciliation narrative, and final report/ZIP assembly.

**Your scope at a glance:**
- Anomalies: A5, A7, A8 (→RECONSTRUCTED), A12, A14, B1, B2, B3, B7
- Gold rebuild: fact_order_fulfilment, fact_inventory_transaction, fact_store_inventory_snapshot, fact_classified_listing_snapshot, fact_web_session, fact_web_page_event, fact_customer_complaint
- KPI views: vw_campaign_incremental_revenue, vw_on_time_delivery_rate, vw_bopis_pickup_readiness_time
- Validation checks: 1, 2, 5, 7, 10 + suite orchestration
- Dashboard: Page 1 Executive Summary
- Report: Exec summary + S4 Reconciliation + S5 Conclusion

---

## Day 0 (Sun) — Pre-flight

### Task 1 — Create NEXAMART_MARTS + confirm M1 Gold
**Where:** Snowflake worksheet, run `sql/snowflake_setup_m2.sql` as ACCOUNTADMIN
**Est:** 0.5 hr
**Done when:**
- `SHOW SCHEMAS` lists NEXAMART_MARTS
- Gold confirmation query returns 27 (13 dims + 14 facts). If 0, trigger full rebuild plan (06 from corrected Silver).

---

## Day 1 (Mon) — Kickoff + detection

### Task 2 — Run 9:30 kickoff; assign anomaly owners
**Where:** team channel; `docs/tasks/`
**Est:** 1.5 hrs
**Done when:** every member confirms their anomaly set + has Snowflake/Databricks access.

### Task 3 — Detection SQL for your anomalies
**Where:** `sql/anomaly_discovery.sql` (A5, A7, A8, A12, A14, B1, B2, B3, B7)
**Est:** 3 hrs
**Done when:** each block returns a count; ports the seed predicate (where one exists) to NEXAMART_SILVER.

---

## Day 2 (Tue) — Detection finalised

### Task 4 — Capture before-counts + scope/impact
**Where:** `sql/anomaly_discovery.sql` header comments; check vs `.private/lead_cheatsheet.md`
**Est:** 2 hrs
**Done when:** A5=5, A7=10, A8≈21 (1–7 Aug), A12=3 pairs, A14=18/68, B1=126/102, B3=175, B7=25 all reproduce.

---

## Day 3 (Wed) — Resolution Cat-A

### Task 5 — A5 (ATP→0), A7 (zero pre-inspection restock)
**Where:** `notebooks/05_anomaly_resolution.ipynb` cells A5, A7
**Est:** 2.5 hrs
**Done when:** corrected rows carry resolution_applied + method; detection re-run → 0.

### Task 6 — A8 snapshot reconstruction (1–7 Aug, stores 3/7/12)
**Where:** `05` cell A8
**Est:** 3 hrs
**Done when:** ~21 rows reconstructed (last snapshot + intervening txns), flagged RECONSTRUCTED + INFERRED; decide on merging the M1 sibling reconstructed table.

### Task 7 — A14 delivery-clock fix (+36h; >72h escalate)
**Where:** `05` cell A14
**Est:** 2 hrs
**Done when:** delta≤72h corrected; delta>72h → REQUIRES_MANUAL_REVIEW (not auto-fixed).

---

## Day 4 (Thu) — Resolution Cat-B + write Silver  ⏰ HARD GATE EOD

### Task 8 — B1 attribution (102 orders), B2 refund period, B3 null-ref, B7 BOPIS
**Where:** `05` cells B1, B2, B3, B7; A12 relisting link
**Est:** 4 hrs
**Done when:** each carries b_classification; A12 links pair + excludes original from B6 GMV (notify M2).

### Task 9 — Write corrected Silver back + idempotency asserts
**Where:** `05` write-back cells; `sql/anomaly_resolution.sql` docs
**Est:** 2 hrs
**Done when:** overwrite writes for your tables succeed; re-run is stable; **corrected Silver done (gate).**

---

## Day 5 (Sat, working) — Gold rebuild  ⏰ HARD GATE EOD

### Task 10 — Rebuild your facts (fulfilment, inventory txn, store snapshot, classified snapshot, clickstream, complaint)
**Where:** `notebooks/06_gold_rebuild.ipynb`
**Est:** 4 hrs
**Blocked by:** member dim rebuilds (M3 dim_product, M2 dim_customer) where your facts join them
**Done when:** only affected tables changed; grain asserts pass; before/after deltas captured for S2.

---

## Day 6 (Mon) — Validation

### Task 11 — Orchestrate the 10-check suite; own checks 1,2,5,7,10
**Where:** `sql/validation_suite.sql`
**Est:** 3 hrs
**Done when:** all 10 return 0 offending rows (Check 7 ≥1/fact); failures logged for report S3 iteration table.

---

## Day 7 (Tue) — KPI views  ⏰ HARD GATE EOD

### Task 12 — Build your 3 views + review all 28 for certainty/segregation
**Where:** `sql/kpi_views.sql` (vw_campaign_incremental_revenue, vw_on_time_delivery_rate, vw_bopis_pickup_readiness_time)
**Est:** 3 hrs
**Done when:** 28 views deployed (`INFORMATION_SCHEMA.VIEWS` count = 28); Checks 5 + 9 pass.

---

## Day 8 (Wed) — Dashboard Page 1 + reconciliation

### Task 13 — GSV→NCR waterfall + 7-team reconciliation narrative
**Where:** `docs/reconciliation_method.md` → report S4; dashboard Page 1
**Est:** 4 hrs
**Done when:** waterfall ties out; each of the 7 teams' numbers mapped to its resolving anomaly.

---

## Day 9 (Thu) — Report + presentation

### Task 14 — Write Exec summary + S5 Conclusion; assemble all members' sections
**Where:** `report/nexamart_m2_report.md`; `presentation/`
**Est:** 4 hrs
**Done when:** report sections 1–5 present; campaign verdict is direct + certainty-labelled; slides 1–7 drafted.

---

## Day 10 (Fri) — Assemble + ZIP  ⏰ DEADLINE EOD

### Task 15 — Export PDF; build submission ZIP; final checks
**Where:** repo root
**Est:** 2 hrs
**Done when:**
- ZIP `nexamart_m2_group_[N].zip` has /report (PDF), /notebooks (05,06), /sql (4 files), /dashboard (+screenshots), /presentation
- `.private/` and `sql/_m1_seed/` excluded from ZIP
- grep tree for any co-author/external-tool attribution → 0 hits before push.
