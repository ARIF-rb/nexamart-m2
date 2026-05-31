# NexaMart Enterprise Data Warehouse — Milestone 2

**Validate · Fix · Analyse · Conclude.** M2 resolves the 24 anomalies M1 flagged, rebuilds the
affected Gold, builds a validated KPI mart layer, and answers the CEO's question:

> *"Was the Back-to-School campaign (8–28 Aug 2024) actually successful, or did every team just count different things?"*

This repo is **self-contained** but operates on the **same Snowflake account as M1** (it does not
re-ingest Bronze unless M1 Gold is missing). Start with [`UNDERSTANDING_M2.md`](UNDERSTANDING_M2.md),
then open your task file in [`docs/tasks/`](docs/tasks/).

---

## The 7-step workflow

```
Identify (Snowflake SQL)  →  Resolve (Databricks PySpark, write corrected Silver)
   →  Rebuild affected Gold  →  Validate (10 checks)  →  KPI views (NEXAMART_MARTS)
   →  Dashboard (MARTS only)  →  Reconcile + Conclude
```

## Repo layout

```
nexamart_m2/
├── UNDERSTANDING_M2.md      ← read first: deep orientation
├── data/nexamart_operations.db   ← SQLite source (~59 MB; only for full rebuild fallback)
├── notebooks/
│   ├── 05_anomaly_resolution.ipynb   ← M2: fix Silver, write back (idempotent)
│   ├── 06_gold_rebuild.ipynb         ← M2: rebuild only affected Gold
│   ├── 01–04 *.ipynb                 ← M1 build logic (reused by 06; reference)
│   └── _shared/                      ← utils_* (incl. M2 resolve() helpers), templates
├── sql/
│   ├── anomaly_discovery.sql    ← 1 detection query per anomaly (vs NEXAMART_SILVER)
│   ├── anomaly_resolution.sql   ← per-anomaly docs + post-resolution verification
│   ├── validation_suite.sql     ← 10 required checks
│   ├── kpi_views.sql            ← all KPI view DDL (NEXAMART_MARTS)
│   ├── snowflake_setup_m2.sql   ← extends M1 setup with NEXAMART_MARTS
│   └── _m1_seed/                ← M1 verified detection SQL (porting reference; NOT submitted)
├── docs/   ← glossary, anomaly_taxonomy, bus_matrix, kpi_register, reconciliation_method,
│             dashboard_spec, date_formats, domain_assignments, ONBOARDING, tasks/
├── report/nexamart_m2_report.md      ← 5-section report → PDF for submission
├── dashboard/                        ← .pbix/.twbx (tool TBD) + screenshots/
└── presentation/                     ← 5–10 slide outline → PPTX/PDF for submission
```

## Quick start

| Role | Do this |
|---|---|
| **Everyone** | Read `UNDERSTANDING_M2.md` → open your `docs/tasks/<you>.md` → work top to bottom |
| **Lead (P0)** | Run `sql/snowflake_setup_m2.sql` as ACCOUNTADMIN (adds `NEXAMART_MARTS`); confirm M1 Gold present (27 tables) |
| **Resolution** | `notebooks/05_anomaly_resolution.ipynb` — `%pip install snowflake-connector-python`, set widgets, read Silver via `utils_snowflake`, correct, write back `overwrite=True` |
| **Validation** | Run `sql/validation_suite.sql`; iterate Silver/Gold until all 10 pass; log iterations in report S3 |
| **Dashboard** | Connect BI tool to `NEXAMART_MARTS` views ONLY — never Gold/Silver |

## Phase calendar (Day 1 = Monday; 2-week build)

| Day | Phase | Output |
|---|---|---|
| 0 | Pre-flight (Lead) | `NEXAMART_MARTS` created; M1 Gold confirmed |
| 1–2 | Detection | `anomaly_discovery.sql` |
| 3–4 | Resolution (Cat-A then Cat-B) | corrected Silver; `05` |
| 5 | Gold rebuild | `06` |
| 6 | Validation | all 10 checks pass |
| 7 | KPI views | `kpi_views.sql` |
| 8 | Dashboard + reconciliation | 5-page dashboard; waterfall |
| 9–10 | Report + presentation + ZIP | `nexamart_m2_group_[N].zip` |

Hard gates: corrected Silver **Day 4 EOD** → Gold rebuild **Day 5 EOD** → KPI views **Day 7 EOD**.

## Submission

Single ZIP `nexamart_m2_group_[N].zip` containing `/report` (PDF), `/notebooks` (05, 06),
`/sql` (anomaly_discovery, anomaly_resolution, validation_suite, kpi_views), `/dashboard`
(file + screenshots), `/presentation`. The `sql/_m1_seed/` and `.private/` folders are NOT submitted.
