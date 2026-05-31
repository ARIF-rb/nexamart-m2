# NexaMart M1 — Member Onboarding

Welcome. Read this once before kickoff. Bookmark it.

## What you're building

NexaMart wants to know whether the **Back-to-School Tech & Essentials campaign** (8–28 Aug 2024) actually worked. Seven departments report seven different revenue numbers because every system defines "sold" differently. We're building the data warehouse that lets the CEO get one trusted view (Milestone 2 next semester resolves the conflicts; **this milestone makes them visible**).

You are **one of six engineers** on the build. Lead is the team coordinator. Your job is your assigned domain — see `docs/domain_assignments.md`.

> **Shared docs:** the live tracker and the Team Assembly report doc are linked in [`shared_links.md`](shared_links.md) (same folder). Bookmark them.

## Deadline

**Thu 21 May 2026, end of day.** Hard. There is no buffer day.

## Kickoff

- **Tue 12 May, 9:30 am** — 90-minute kickoff call (lead drives)
- **Daily standup** — 9:30 am, 15 min, every day until submission. Yesterday / today / blocker. That's it.
- **Sunday 17 May is a working day.** Not optional.

## Access checklist (do this before kickoff)

You should have received:
1. Snowflake login — username + temporary password. Test login at `<account>.snowflakecomputing.com` and reset password.
2. Databricks Free Edition account — your own (Free Edition doesn't share workspaces; CE was discontinued in 2024–2025). Sign up at <https://signup.databricks.com/?dbx_source=COMMUNITY> with your school email.
3. GitHub repo invite — accept it.
4. WhatsApp/Discord channel invite — join it.

If anything is missing by Tue 12 May 9 am, ping the lead.

## Repo layout

```
nexamart_m1/
├── README.md                          ← start here
├── docs/                              ← read these
│   ├── ONBOARDING.md                  ← this file
│   ├── domain_assignments.md          ← YOUR scope is here
│   ├── tasks/                         ← YOUR day-by-day task list
│   │   ├── README.md                  ← how to use the task files
│   │   └── {lead,M2,M3,M4,M5,M6}.md   ← open the one matching your role
│   ├── discovery_checklist.md         ← Day 1 task
│   ├── anomaly_taxonomy.md            ← reason codes you must use
│   ├── glossary.md                    ← KPI definitions (NexaMart-authoritative)
│   ├── date_formats.md                ← 6 date formats T1 must handle
│   ├── snowflake_setup.sql            ← lead runs once
│   ├── databricks_setup.md            ← lead runs once
│   └── bus_matrix.md                  ← Phase 5 fill-in
├── notebooks/
│   ├── 01_bronze_ingestion.ipynb      ← lead writes; you read
│   ├── 02_silver_<domain>.ipynb       ← YOUR scaffold
│   ├── 03_gold_dimensions.ipynb       ← shared, fill your dim section
│   ├── 04_gold_facts.ipynb            ← shared, fill your fact section
│   └── _shared/                       ← utilities; import from these
│       ├── utils_dates.py             ← T1 6-format date converters
│       ├── utils_keys.py              ← T3 SHA-256 surrogate keys
│       ├── utils_anomaly.py           ← 4 mandatory column helpers
│       ├── utils_snowflake.py         ← Free Edition Snowflake read/write
│       ├── silver_template.ipynb      ← copy this pattern
│       └── seed_status_mapping.ipynb
├── sql/
│   ├── bronze_validation.sql
│   └── silver_quality.sql
└── report/
    └── nexamart_m1_report.md          ← 9-section report; your domain section is here
```

## ⚠️ Platform note — Databricks Free Edition (not Community)

Databricks **discontinued Community Edition** in 2024–2025 and replaced it with **Free Edition**. The brief was written for CE; we adapt cleanly. Key differences (full list in `docs/databricks_setup.md`):

- **No clusters** — Free Edition runs notebooks on **serverless** Spark Connect (auto-attached, no setup)
- **No Maven JARs** — install Python libs per-notebook with `%pip install`
- **DBFS replaced by Unity Catalog Volumes** — source `.db` lives at `/Volumes/workspace/default/nexamart/`
- **Secrets API restricted** — credentials via notebook widgets (entered per session, never committed)

The intent (PySpark transforms, Snowflake-as-storage, idempotent runs) is preserved exactly.

## How to set up your workspace (Free Edition, ~10 min)

1. Sign up at <https://signup.databricks.com/?dbx_source=COMMUNITY> with your school email — you get your own Free Edition workspace (CE/Free Edition workspaces are not shared between users).
2. Catalog → `workspace` → `default` → right-click → Create → Volume → name `nexamart`. Upload `nexamart_operations.db` from your cloned repo (at `data/nexamart_operations.db`, ~57 MB) into that volume. Final path inside Databricks will be `/Volumes/workspace/default/nexamart/nexamart_operations.db`.
3. Clone the Git repo locally (`git clone https://github.com/ARIF-rb/nexamart-m1.git`), then import the `.ipynb` files into your Databricks workspace. Step-by-step (UI route + CLI route) in `docs/databricks_setup.md` Step 3.5.
4. Reset your Snowflake temporary password on first login at `https://<account-locator>.snowflakecomputing.com`. Step-by-step in `docs/databricks_setup.md` Step 3.6.

## How notebooks read Snowflake credentials

We use **notebook widgets** (Free Edition's secrets API is restricted). Every notebook has these cells at the top:

```python
%pip install -q snowflake-connector-python pandas rapidfuzz
dbutils.library.restartPython()
```
```python
dbutils.widgets.text('sf_account',   'rhxendw-yb24678')
dbutils.widgets.text('sf_user',      'NEXAMART_M2')      # YOUR Snowflake user
dbutils.widgets.text('sf_password',  '')                 # paste your password here at run time
dbutils.widgets.text('sf_warehouse', 'NEXAMART_WH')
dbutils.widgets.text('sf_role',      'NEXAMART_ENGINEER')
```

When the notebook opens, a widget bar appears at the top — paste your Snowflake password into the `sf_password` widget once per session. **Never paste passwords into code cells.** PRs with hardcoded credentials get rejected.

The shared helper `notebooks/_shared/utils_snowflake.py` reads widgets directly via `read_from_snowflake(spark, table)` and `write_to_snowflake(df, table, schema)`. You don't need to manage connections yourself.

## Repo conventions (read these — PRs that violate get rejected)

- **Branch naming:** `m<your-number>/silver-<domain>-<topic>`. Example: `m4/silver-inventory-atp-reconstruction`.
- **Commit at least daily.** Lead reviews same day.
- **Never DELETE rows from Silver.** If a row is bad, FLAG it: set `anomaly_flag = TRUE`, set an `anomaly_reason_code` from `docs/anomaly_taxonomy.md`, set `data_quality_status` appropriately. The brief explicitly tests for missing rows in M2.
- **Use only registered anomaly_reason_code values.** If you need a new one, add it to `docs/anomaly_taxonomy.md` in the same PR; lead approves.
- **Every Silver table must have these 4 columns populated:**
  - `anomaly_flag` (boolean)
  - `anomaly_reason_code` (string, comma-separated if multiple)
  - `data_quality_status` ∈ {CLEAN, FLAGGED_ANOMALY, FLAGGED_AMBIGUOUS, EXCLUDED_WITH_REASON, RECONSTRUCTED}
  - `metric_certainty_level` ∈ {CONFIRMED, INFERRED, ESTIMATED, UNRELIABLE}
- **Idempotence is non-negotiable.** Your notebook must produce the same output if run twice on the same Bronze. Use `mode("overwrite")` for Snowflake writes; use deterministic surrogate keys (utils_keys.py).
- **Date columns:** convert to ISO 8601 first thing using `notebooks/_shared/utils_dates.py`. See `docs/date_formats.md` for the 6 formats and which tables use which.

## What the lead is looking for in PR review

1. The 4 mandatory columns are present and populated
2. Surrogate keys via `surrogate_key()` from `utils_keys.py` (not raw natural keys)
3. No deleted rows; bad rows are flagged
4. Anomalies you found are documented in your domain section of `report/nexamart_m1_report.md` (Section 8)
5. The notebook runs end-to-end on a fresh cluster (idempotence test on Day 9)

## Escalation

- **Quick technical question:** WhatsApp/Discord channel
- **Blocked > 2 hours:** ping the lead directly
- **Snowflake / Databricks issue (account, billing, access):** lead only
- **Domain interpretation question (e.g., "should I treat this as ambiguous?"):** ask in PR comments, lead decides

## Your `.private/` folder warning

`.private/` is `.gitignore`d. The lead has anomaly acceptance contracts in there. **Do not look for them**, do not ask for the counts. The brief explicitly penalises generic / leaked answers. Your detective work is what's being graded.

---

If you read this far, you're ready. Open `docs/domain_assignments.md` to find your name + scope, then open `docs/tasks/<your-role>.md` (e.g. `M3.md` if you're M3, `lead.md` if you're me) — that's your day-by-day task list with acceptance criteria. Each task has a **Done when** line so you can self-pace and tick items off without waiting for handholding.
