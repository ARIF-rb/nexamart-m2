# Databricks Free Edition — One-time Setup Checklist

> **Important:** Databricks **discontinued Community Edition (CE)** in 2024–2025 and replaced it with **Free Edition**. The assignment brief (Section 7.1, 7.4) assumed CE — which has been removed from Databricks' product catalogue. We adapt to Free Edition while preserving the brief's intent: PySpark transformations, Snowflake-as-storage, idempotent pipeline. The deviation is documented in Report Section 3.

**Lead does this once. ~30 minutes.**

## Differences from the brief

| Brief assumed (CE) | Free Edition reality | Our adaptation |
|---|---|---|
| General-purpose cluster with `Cluster → Libraries → Install New → Maven` | No clusters; serverless only | `%pip install snowflake-connector-python` at top of each notebook |
| `spark-snowflake_2.12:2.12.0-spark_3.4` JAR | Not installable on serverless | `snowflake-connector-python` (pure Python) via `write_pandas()` |
| `df.write.format('snowflake').save()` | spark-snowflake unavailable | Custom helper `write_to_snowflake(df, table)` in `notebooks/_shared/utils_snowflake.py` |
| `/dbfs/FileStore/nexamart_operations.db` | DBFS not user-accessible | Unity Catalog Volume at `/Volumes/workspace/default/nexamart/nexamart_operations.db` |
| `dbutils.secrets.get(...)` for credentials | Scope creation may be restricted in Free tier | Notebook widgets (`dbutils.widgets.text(...)`) — values entered per-run, never committed |

The intent — PySpark transforms in Databricks, all layers persisted in Snowflake, idempotent runs — is preserved exactly.

---

## Step 1 — Sign in to Databricks Free Edition

1. Sign up at <https://signup.databricks.com/?dbx_source=COMMUNITY> (Free Edition signup) using your school email.
2. After sign-in you land at `https://dbc-<workspace-id>.cloud.databricks.com/`.
3. The badge top-left should read **"Free Edition"**. If it reads anything else, you're on a different tier.

## Step 2 — Compute model: serverless (nothing to provision)

Free Edition runs notebooks on **serverless Spark Connect**. There is no cluster to create.

- The compute selector top-right of any notebook reads "Serverless" — that's the only option.
- First cell run after the workspace has been idle takes **2–5 minutes** (cold start).
- Subsequent cells run in seconds while the session is warm.
- The session goes idle after ~10 min of inactivity.

You don't need to install Maven JARs. Python libraries are installed per-notebook with `%pip install`.

## Step 3 — Upload the source `.db` to a Unity Catalog Volume

The brief said "upload to DBFS"; Free Edition replaces DBFS with Unity Catalog Volumes. Volumes are persistent file storage that all notebooks can read.

1. **Catalog** sidebar → expand `workspace` (the default catalog) → `default` (the default schema).
2. Right-click `default` → **Create** → **Volume**.
3. Name: `nexamart`. Type: **Managed**. Click **Create**.
4. Open the new volume → **Upload to this volume** → pick `nexamart_operations.db` from your **cloned repo** at `nexamart-m1/data/nexamart_operations.db` (~57 MB; the file is committed to the repo, so `git clone` already pulled it).
5. After upload, the file path inside Databricks is `/Volumes/workspace/default/nexamart/nexamart_operations.db` — this is what notebooks reference.

Verify in a notebook cell:
```python
import os
path = "/Volumes/workspace/default/nexamart/nexamart_operations.db"
print(os.path.exists(path), os.path.getsize(path))
# Should print: True 59154432
```

## Step 3.5 — Import the kit notebooks into your workspace

You need the `.ipynb` scaffolds in your Free Edition workspace before you can run them. Two routes — pick whichever matches your tooling.

### Route A — Workspace UI (no CLI needed)
1. Clone the repo locally: `git clone https://github.com/ARIF-rb/nexamart-m1.git` (or your fork).
2. In Databricks, click **Workspace** in the left sidebar → navigate to your user folder (`/Workspace/Users/<your-email>/`).
3. Right-click your user folder → **Import**.
4. In the dialog, choose **File** → click **Browse** → select all `.ipynb` files under `nexamart_m1/notebooks/` (you can multi-select). Also import the `_shared/` folder by right-clicking your user folder again → Create → Folder → name `_shared`, then import each `.py` file into it.
5. Open `01_bronze_ingestion.ipynb` from your workspace tree to confirm the import worked.

### Route B — Databricks CLI (faster for re-imports)
1. Install the Databricks CLI on your local machine: `pip install databricks-cli` (legacy) or `pip install databricks-sdk` (newer).
2. Configure it with a Free Edition personal access token: **User Settings** → **Developer** → **Access tokens** → **Generate new token**. Then `databricks configure --token` and paste your workspace URL + token.
3. Sync the whole notebook directory in one shot:
   ```bash
   databricks workspace import_dir nexamart_m1/notebooks /Workspace/Users/<your-email>/nexamart_m1 --overwrite
   ```
4. Re-run the same command after every `git pull` to keep your workspace in sync.

> **Note:** the `_shared/*.py` files must end up at the same workspace path the notebooks expect. The scaffolds use `sys.path.append('/Workspace/Repos/<your-org>/nexamart-m1/notebooks/_shared')` — change that path in your local copy if you imported elsewhere.

## Step 3.6 — Reset your Snowflake temporary password (each member)

The lead created your user with `MUST_CHANGE_PASSWORD = TRUE`. Reset it once before kickoff:

1. Go to `https://<account-locator>.snowflakecomputing.com` (lead shares the locator in the kickoff message; e.g. `rhxendw-yb24678.snowflakecomputing.com`).
2. Sign in with your username (`NEXAMART_LEAD` or `NEXAMART_M2..M6`) and the temporary password.
3. Snowflake forces a password change on the first login — pick a new password (≥ 8 chars, mixed case + digit + symbol).
4. After reset, you land on the Snowsight home. Run a sanity check in a worksheet:
   ```sql
   SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE();
   -- Expect: NEXAMART_M? | NEXAMART_ENGINEER | NEXAMART_WH | NEXAMART_DW
   ```
5. Paste the new password into the `sf_password` widget when you open a notebook (Step 4 below). Never commit the password.

## Step 4 — Snowflake credentials via notebook widgets

Free Edition's `dbutils.secrets.createScope(...)` is restricted on most accounts, so we use **widgets** instead. Widgets are notebook-scoped UI inputs — values are entered per session and never committed to Git.

Every notebook starts with:
```python
dbutils.widgets.text("sf_account",   "rhxendw-yb24678")
dbutils.widgets.text("sf_user",      "NEXAMART_LEAD")
dbutils.widgets.text("sf_password",  "")  # paste at run time
dbutils.widgets.text("sf_warehouse", "NEXAMART_WH")
dbutils.widgets.text("sf_role",      "NEXAMART_ENGINEER")
```

When you open a notebook, the widget bar appears at the top. Paste your Snowflake password into the `sf_password` widget once per session. The shared helper (`utils_snowflake.py::get_connection`) reads widgets directly — your scaffolds don't need code changes.

> **Each member uses their own Snowflake user (NEXAMART_M2..M6).** They reset the temp password on first login then paste the new password into the `sf_password` widget.

> **Bronze ingestion override (lead only).** `01_bronze_ingestion.ipynb` writes to `NEXAMART_BRONZE`, where `NEXAMART_ENGINEER` only has SELECT (not CREATE TABLE). The lead overrides two widget values for that one notebook: `sf_user` to their personal admin Snowflake account (the one that has `ACCOUNTADMIN` role granted) and `sf_role` to `ACCOUNTADMIN`. The `NEXAMART_LEAD` service user only has `NEXAMART_ENGINEER` per `snowflake_setup.sql` line 113 and so cannot write Bronze on its own.

## Step 5 — Smoke test

Create a scratch notebook → attach to Serverless → paste these cells and run:

```python
# Cell 1: install the connector
%pip install -q snowflake-connector-python
dbutils.library.restartPython()
```

```python
# Cell 2: widgets
dbutils.widgets.text("sf_account",   "rhxendw-yb24678")
dbutils.widgets.text("sf_user",      "NEXAMART_LEAD")
dbutils.widgets.text("sf_password",  "")
dbutils.widgets.text("sf_warehouse", "NEXAMART_WH")
dbutils.widgets.text("sf_role",      "NEXAMART_ENGINEER")
```

```python
# Cell 3: read 4 rows from SQLite, write to Snowflake
import sqlite3, shutil, pandas as pd
from snowflake.connector import connect
from snowflake.connector.pandas_tools import write_pandas

# Volumes are object-storage-backed and don't support SQLite POSIX file locking.
# Copy to /tmp first, then read with sqlite3 from there.
shutil.copy("/Volumes/workspace/default/nexamart/nexamart_operations.db", "/tmp/nx.db")
con = sqlite3.connect("/tmp/nx.db")
pdf = pd.read_sql("SELECT * FROM cl_loyalty_tiers", con)
print(pdf)
print(f"Read {len(pdf)} rows from cl_loyalty_tiers")

pdf.columns = [c.upper() for c in pdf.columns]
with connect(
    account=dbutils.widgets.get("sf_account"),
    user=dbutils.widgets.get("sf_user"),
    password=dbutils.widgets.get("sf_password"),
    warehouse=dbutils.widgets.get("sf_warehouse"),
    role=dbutils.widgets.get("sf_role"),
    database="NEXAMART_DW",
    schema="NEXAMART_SILVER",
) as ctx:
    success, _, n, _ = write_pandas(
        ctx, pdf,
        table_name="SMOKE_TEST",
        schema="NEXAMART_SILVER",
        database="NEXAMART_DW",
        auto_create_table=True,
        overwrite=True,
        quote_identifiers=False,
    )
    print(f"Wrote SMOKE_TEST: success={success}, rows={n}")
```

> The smoke test writes to `NEXAMART_SILVER` because that is where `NEXAMART_ENGINEER` has `CREATE TABLE` per `snowflake_setup.sql` lines 52-54. `NEXAMART_BRONZE` is intentionally read-only for member roles. Bronze is written only by `01_bronze_ingestion.ipynb` (lead, with ACCOUNTADMIN override).

Then in Snowflake console (sign in as your `NEXAMART_M{2..6}` user with role `NEXAMART_ENGINEER` so you can see the table you just created):
```sql
SELECT * FROM NEXAMART_DW.NEXAMART_SILVER.SMOKE_TEST;
DROP TABLE NEXAMART_DW.NEXAMART_SILVER.SMOKE_TEST;
```

If 4 rows appear and drop, plumbing works end-to-end.

## Step 6 — Member onboarding

Each member needs their own Free Edition workspace (it doesn't share like CE didn't either):
1. Send them the Free Edition signup link from Step 1.
2. They each upload `nexamart_operations.db` (in the cloned repo at `data/nexamart_operations.db`, ~57 MB) to their own `/Volumes/workspace/default/nexamart/`.
3. They each clone the Git repo and import notebooks from there.
4. They use their own Snowflake user (`NEXAMART_M2`..`M6`).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| First cell takes 5+ min "Waiting" | Free tier serverless cold start. Subsequent cells are fast. Patience required for the first run. |
| `ModuleNotFoundError: snowflake.connector` | Run `%pip install snowflake-connector-python` then `dbutils.library.restartPython()` in a cell BEFORE the import |
| `dbutils.widgets.get('sf_password')` returns empty | You forgot to paste the value in the widget bar at the top of the notebook |
| `Failed to connect: 250001 (08001): Could not connect to Snowflake backend after 0 attempt(s)` | Wrong account locator format. Use `<orgname>-<accountname>` (e.g. `rhxendw-yb24678`), NOT the legacy `xxxxx.region.cloud` format |
| `MUST_CHANGE_PASSWORD: please change your password` | Snowflake users were created with that flag. Log into Snowflake web UI once and set a new password, then use the new password in the widget |
| `auto_create_table` infers wrong types | For Bronze it doesn't matter (everything stays as ingested); for Silver/Gold pre-create the table with explicit DDL |
| Cell hangs on `toPandas()` for large table | Expected for `si_inventory_movements` (438k rows) — takes ~1–2 min on Free Edition serverless. Don't cancel. |
| `DatabaseError: Execution failed on sql ...: disk I/O error` reading SQLite from `/Volumes/...` | **Unity Catalog Volumes are object-storage-backed and don't support SQLite's POSIX file locking.** Fix: copy the .db to `/tmp/` first, then read with sqlite3 from there. Pattern: `import shutil; shutil.copy('/Volumes/workspace/default/nexamart/nexamart_operations.db', '/tmp/nx.db'); con = sqlite3.connect('/tmp/nx.db')`. Already baked into `notebooks/01_bronze_ingestion.ipynb`. |
| Cell stays "Waiting" for 5+ min after `dbutils.library.restartPython()` | Free tier serverless kernel reboots are slow/unreliable. **Workaround**: skip `restartPython()` — `%pip install snowflake-connector-python` works without it on a fresh kernel. Re-runs only need restart if you're upgrading an existing version. |

Lead is the contact for any setup blocker > 30 min.
