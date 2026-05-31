# Per-member day-by-day task files (Milestone 2)

Each member has their own task file. Open yours, work top to bottom. **You should not need to ask the
lead what to do next** — your file tells you, every day. First read [`../../UNDERSTANDING_M2.md`](../../UNDERSTANDING_M2.md).

## Find your file

| Member | File | Tier | Workstream | Est hours |
|---|---|---|---|---|
| Lead | [`lead.md`](lead.md) | Heavy | infra/MARTS, attribution+fulfilment+inventory-reconstruct, reconciliation, assembly | ~50–58 |
| M2 | [`M2.md`](M2.md) | Heavy | customer identity, seller trust, estimated GMV, NexaLocal/seller KPIs | ~38–46 |
| M3 | [`M3.md`](M3.md) | Light | product catalogue identity | ~16–20 |
| M4 | [`M4.md`](M4.md) | Light | inventory resolution + KPIs + BORIS | ~22–26 |
| M5 | [`M5.md`](M5.md) | Light→Med | sales pipeline + keystone EC fact + Finance KPIs | ~26–30 |
| M6 | [`M6.md`](M6.md) | Light | reviews/support/marketplace + ecommerce funnel KPIs | ~20–24 |

## How to use your file
1. Open it **Mon morning (Day 1)**. Scroll to "## Day 1 (Mon …)". Those are today's tasks.
2. Each task has: **Where** (file/notebook/cell) · **Est** (time) · **Done when** (measurable acceptance) · **Blocked by** (when present).
3. **Standup format** uses your file directly — Yesterday: Tasks N..; Today: Tasks N+x; Blocker: Task Y blocked by Lead's Task Z.

## Calendar reference (Day 1 = Monday; shift dates to your actual start)

| Day | Date | Phase | Notes |
|---|---|---|---|
| 0 | Sun | Pre-flight (Lead) | run `snowflake_setup_m2.sql` → NEXAMART_MARTS; confirm M1 Gold (27 tables) |
| 1 | Mon | Kickoff + detection | port seeds → `anomaly_discovery.sql` |
| 2 | Tue | Detection finalised | before-counts captured |
| 3 | Wed | Resolution Cat-A | `05` Cat-A cells |
| 4 | Thu | Resolution Cat-B + write Silver | **corrected Silver hard deadline EOD** |
| 5 | Sat (working) | Gold rebuild | `06` only-affected; **Gold rebuild hard deadline EOD** |
| 6 | Mon | Validation | `validation_suite.sql` all 10 pass (iterate) |
| 7 | Tue | KPI views | `kpi_views.sql`; **KPI views hard deadline EOD** |
| 8 | Wed | Dashboard + reconciliation | 5 pages on MARTS only; GSV→NCR waterfall |
| 9 | Thu | Report + presentation | 5 sections; 5–10 slides |
| 10 | Fri | Assemble + ZIP | `nexamart_m2_group_[N].zip` — **DEADLINE EOD** |

## Hard gates (the only true blockers)
**Corrected Silver → Day 4 EOD · Gold rebuild → Day 5 EOD · KPI views → Day 7 EOD.**
Resolution → rebuild → validation → KPI views → dashboard is strictly sequential.

## Cross-member dependencies
```
P0 Lead: NEXAMART_MARTS + grants ─────────────► everyone (needed Day 7)
Day 4 EOD — corrected Silver:
  M5 (A1/A2/A3) ┐  M4 (A6/A10) ┐  M3 (A9/B4) ┐  M2 (A11/B5/B6/B8) ┐  M6 (A4/A13/A15/A16) ┐  Lead (A5/A7/A8/A12/A14/B1/B2/B3/B7) ┘
  silver_ec_orders: M2 (A11) + Lead (B1) corrections must land before M5 rebuilds fact_ecommerce_order_line
  A12 (Lead) ──► B6 Estimated GMV exclusion (M2)
Day 5 EOD — Gold rebuild (dims first → dependent facts):
  M3 dim_product ─► product-joined facts ; M2 dim_customer ─► customer-joined facts
  Lead clickstream facts ─► M6 funnel KPI views (Day 7)
Day 7 EOD — KPI views in NEXAMART_MARTS
```

## Anomaly hint policy
Your file names the anomaly codes you resolve but **never gives the expected count**. The lead holds
verified counts in `.private/resolution_targets.md` and compares during PR review. Do the detective work.

## File-format conventions
- Day headers: `## Day N (Day-of-week)` · Task headers: `### Task N — short title`
- Bold-prefixed lines: **Where** / **Est** / **Done when** / **Blocked by**
- Tasks numbered globally per member (not reset per day)
- No co-author or external-tool attribution in any commit or pushed file — treat every commit as solo work.
