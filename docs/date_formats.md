# Date & Timestamp Formats — T1 Reference

NexaMart's six operational systems use **six different date/time encodings**. Silver T1 must convert all of them to ISO 8601 before any downstream transform.

**Rule:** failed parses do NOT throw. They null the column and append `DATE_PARSE_FAIL` to `anomaly_reason_code`, with `data_quality_status='FLAGGED_ANOMALY'`.

Use the helpers in `notebooks/_shared/utils_dates.py` — never call `to_date()` directly in domain notebooks.

---

## The six formats

| # | Format | Example | Source tables (date columns) | PySpark expression |
|---|---|---|---|---|
| 1 | `DD/MM/YYYY` | `08/08/2024` | `pos_transactions.txn_date`, `si_inventory_snapshots.snapshot_date`, `si_inventory_movements.movement_date` | `to_date(col, "dd/MM/yyyy")` |
| 2 | `YYYY-MM-DD` (ISO date) | `2024-08-08` | `ec_orders.order_date`, `ec_order_lines.*`, `wh_inventory_snapshots.snapshot_date`, `dc_shipments.created_date`, `rr_refund_events.refund_date`, `rr_return_receipts.received_date`, `ts_risk_signals.signal_date`, `ts_safety_reports.report_date` | `to_date(col, "yyyy-MM-dd")` (or no-op — Spark auto-parses) |
| 3 | `ISO 8601 with T` | `2024-08-08T14:23:00` | `dc_delivery_events.event_datetime`, `wh_inventory_movements.movement_datetime`, `nl_listings.created_datetime`, `nl_listings.updated_datetime`, `nl_listing_events.event_datetime`, `rv_reviews.review_datetime` | `to_timestamp(col)` (auto-parses) |
| 4 | `DD-Mon-YYYY` | `05-Sep-2024` | `rr_return_requests.return_request_date` (only) | `to_date(col, "dd-MMM-yyyy")` |
| 5 | `YYYY/MM/DD HH:MM` | `2024/08/08 14:23` | `cs_cases.case_open_datetime`, `cs_case_events.event_datetime` | `to_timestamp(col, "yyyy/MM/dd HH:mm")` |
| 6 | **Unix epoch (integer)** | `1723046400` | `pg_transactions.*` (all 4 timestamp cols: created_ts, captured_ts, settled_ts, refunded_ts) | `from_unixtime(col).cast("timestamp")` |

---

## ⚠️ Format ambiguity flag — verify on Day 2

The data dictionary's "Date Formats" sheet describes `pg_transactions` timestamps as `YYYY-MM-DD HH:MM:SS` strings. UNDERSTANDING.md and the column data type (INTEGER) say Unix epoch.

**M5 must run this on Day 2** before locking the T1 converter for `pg_*`:

```sql
-- In Snowflake on Bronze, or in PySpark on Bronze:
SELECT created_ts, TYPEOF(created_ts) FROM NEXAMART_BRONZE.pg_transactions LIMIT 5;
```

- If `created_ts` is INT/BIGINT and value looks like ~1.72e9, it's Unix epoch → use Format 6.
- If string and looks like `2024-08-08 14:23:00`, it's a string timestamp → use `to_timestamp(col, "yyyy-MM-dd HH:mm:ss")`.

Update `utils_dates.py` and post in the team channel which one applies.

---

## Common mistakes to avoid

1. **`MM/dd/yyyy` vs `dd/MM/yyyy`** — POS uses `dd/MM/yyyy`. `01/08/2024` is **8 January**, not **1 August**. Test with a value past day 12 to be sure.
2. **Calling `to_date` on already-parsed dates** — Spark may silently convert string→date→string; use the `parse_date(col, format_hint)` dispatcher in `utils_dates.py` to avoid double-conversion.
3. **Treating `from_unixtime` as a no-op** — it returns string; cast to timestamp explicitly.
4. **Forgetting timezone** — assume UTC for all timestamps. Don't apply `from_utc_timestamp` unless you have a documented requirement.
5. **Skipping the failure flag** — every Silver row that fails parse must keep its original Bronze value in a backup column (`<col>_raw`) and have `DATE_PARSE_FAIL` appended.

---

## Anomaly handling for date issues

| Symptom | reason_code | status |
|---|---|---|
| Format mismatch (parse returns null) | `DATE_PARSE_FAIL` | `FLAGGED_ANOMALY` |
| Parsed date in the future (after 2024-09-14) | `DATE_FUTURE` | `FLAGGED_AMBIGUOUS` |
| Parsed date before 2024-03-01 (project window start) | `DATE_BEFORE_RANGE` | `FLAGGED_AMBIGUOUS` |
| Delivery event timestamp earlier than shipment created | `DELIVERY_BEFORE_SHIP` | `FLAGGED_ANOMALY` (Lead detects this — see A14, lead.md Task 15) |
| Review datetime before delivery datetime | `REVIEW_BEFORE_DELIVERY` | `FLAGGED_ANOMALY` (M6 — see A15) |

All codes are registered in `docs/anomaly_taxonomy.md`.
