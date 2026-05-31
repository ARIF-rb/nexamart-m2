-- ===========================================================================
-- NexaMart M2 — Snowflake setup (extends the M1 setup)
-- Run this ONCE in Snowflake console as ACCOUNTADMIN, on the SAME account as M1.
-- M1 already created NEXAMART_DW + BRONZE/SILVER/GOLD + NEXAMART_WH + the role
-- and users; the CREATE ... IF NOT EXISTS statements are idempotent, so this is
-- safe to re-run. The ONLY net-new object for M2 is the NEXAMART_MARTS schema
-- (section 1b) that holds the KPI views.
-- ===========================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------------
-- 1. Database + schemas (medallion layout — unchanged from M1)
-- ----------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS NEXAMART_DW
  COMMENT = 'NexaMart Data Warehouse — Milestone 1 + 2 (Bronze, Silver, Gold, Marts)';

CREATE SCHEMA IF NOT EXISTS NEXAMART_DW.NEXAMART_BRONZE
  COMMENT = 'Raw mirror of SQLite source. Zero transformations. +3 metadata cols only.';

CREATE SCHEMA IF NOT EXISTS NEXAMART_DW.NEXAMART_SILVER
  COMMENT = 'Cleaned, normalised, surrogate-keyed business entities. M2 writes CORRECTED Silver here (anomalies resolved, audit trail preserved).';

CREATE SCHEMA IF NOT EXISTS NEXAMART_DW.NEXAMART_GOLD
  COMMENT = 'Kimball dimensional model: 13 conformed dimensions + 14 fact tables. M2 rebuilds affected tables from corrected Silver.';

-- ----------------------------------------------------------------------------
-- 1b. NEW for M2 — Marts schema (KPI presentation layer; VIEWS ONLY)
-- ----------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS NEXAMART_DW.NEXAMART_MARTS
  COMMENT = 'M2 KPI presentation layer. Views only. Every view carries metric_certainty_level; Finance views also carry is_confirmed_transaction. The dashboard connects to THIS schema only — never to GOLD/SILVER directly.';

-- ----------------------------------------------------------------------------
-- 2. Warehouse (compute) — keep small to conserve trial credits
-- ----------------------------------------------------------------------------

CREATE WAREHOUSE IF NOT EXISTS NEXAMART_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
       AUTO_SUSPEND   = 60
       AUTO_RESUME    = TRUE
       INITIALLY_SUSPENDED = TRUE
       COMMENT = 'XS warehouse for the M1 build; auto-suspends after 60s idle.';

-- ----------------------------------------------------------------------------
-- 3. Role + grants
-- ----------------------------------------------------------------------------

CREATE ROLE IF NOT EXISTS NEXAMART_ENGINEER
  COMMENT = 'Build role for the 6-person M1 team.';

GRANT USAGE ON WAREHOUSE NEXAMART_WH TO ROLE NEXAMART_ENGINEER;
GRANT USAGE ON DATABASE NEXAMART_DW TO ROLE NEXAMART_ENGINEER;

-- Bronze: read-only after lead writes it (members only need SELECT)
GRANT USAGE ON SCHEMA NEXAMART_DW.NEXAMART_BRONZE TO ROLE NEXAMART_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA NEXAMART_DW.NEXAMART_BRONZE TO ROLE NEXAMART_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA NEXAMART_DW.NEXAMART_BRONZE TO ROLE NEXAMART_ENGINEER;

-- Silver: members write their own tables
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA NEXAMART_DW.NEXAMART_SILVER TO ROLE NEXAMART_ENGINEER;
GRANT ALL ON ALL TABLES IN SCHEMA NEXAMART_DW.NEXAMART_SILVER TO ROLE NEXAMART_ENGINEER;
GRANT ALL ON FUTURE TABLES IN SCHEMA NEXAMART_DW.NEXAMART_SILVER TO ROLE NEXAMART_ENGINEER;

-- Gold: members write their assigned dims/facts
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA NEXAMART_DW.NEXAMART_GOLD TO ROLE NEXAMART_ENGINEER;
GRANT ALL ON ALL TABLES IN SCHEMA NEXAMART_DW.NEXAMART_GOLD TO ROLE NEXAMART_ENGINEER;
GRANT ALL ON FUTURE TABLES IN SCHEMA NEXAMART_DW.NEXAMART_GOLD TO ROLE NEXAMART_ENGINEER;

-- Marts (NEW for M2): KPI views read from Gold; members create views here.
GRANT USAGE, CREATE VIEW ON SCHEMA NEXAMART_DW.NEXAMART_MARTS TO ROLE NEXAMART_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA NEXAMART_DW.NEXAMART_GOLD TO ROLE NEXAMART_ENGINEER;
GRANT ALL ON ALL VIEWS IN SCHEMA NEXAMART_DW.NEXAMART_MARTS TO ROLE NEXAMART_ENGINEER;
GRANT ALL ON FUTURE VIEWS IN SCHEMA NEXAMART_DW.NEXAMART_MARTS TO ROLE NEXAMART_ENGINEER;
-- The BI tool (Power BI / Tableau) should connect with a role that has USAGE on
-- NEXAMART_MARTS + SELECT on its views ONLY (not GOLD/SILVER). For the trial we
-- reuse NEXAMART_ENGINEER; in a graded handover, create a read-only NEXAMART_BI role.

-- ----------------------------------------------------------------------------
-- 4. Users (one per team member)
--    Replace <password_X> with strong temporary passwords; share securely;
--    each member should reset on first login.
-- ----------------------------------------------------------------------------

-- Users already exist from M1; comments updated to M2 workstreams (re-running
-- CREATE USER IF NOT EXISTS leaves the existing passwords/roles untouched).

CREATE USER IF NOT EXISTS NEXAMART_LEAD
  PASSWORD = '<password_lead>'
  DEFAULT_ROLE = NEXAMART_ENGINEER
  DEFAULT_WAREHOUSE = NEXAMART_WH
  MUST_CHANGE_PASSWORD = TRUE
  COMMENT = 'M2 Lead — MARTS schema + infra; resolves A5/A7/A8/A12/A14/B1/B2/B3/B7; rebuilds fulfilment/inventory/clickstream/complaint facts; reconciliation + report assembly.';

CREATE USER IF NOT EXISTS NEXAMART_M2
  PASSWORD = '<password_m2>'
  DEFAULT_ROLE = NEXAMART_ENGINEER
  DEFAULT_WAREHOUSE = NEXAMART_WH
  MUST_CHANGE_PASSWORD = TRUE
  COMMENT = 'M2 Member 2 (heavy) — resolves A11/B5/B6/B8; rebuilds dim_customer/identity bridge, dim_seller_risk_tier, seller-perf fact; owns Confirmed/Estimated GMV + NexaLocal/seller KPI views.';

CREATE USER IF NOT EXISTS NEXAMART_M3
  PASSWORD = '<password_m3>'
  DEFAULT_ROLE = NEXAMART_ENGINEER
  DEFAULT_WAREHOUSE = NEXAMART_WH
  MUST_CHANGE_PASSWORD = TRUE
  COMMENT = 'M2 Member 3 (light) — resolves A9/B4; rebuilds dim_product; owns open-box-conversion KPI.';

CREATE USER IF NOT EXISTS NEXAMART_M4
  PASSWORD = '<password_m4>'
  DEFAULT_ROLE = NEXAMART_ENGINEER
  DEFAULT_WAREHOUSE = NEXAMART_WH
  MUST_CHANGE_PASSWORD = TRUE
  COMMENT = 'M2 Member 4 (light) — resolves A6/A10; rebuilds dim_store + warehouse-snapshot fact; owns inventory KPI views + BORIS count; validation checks 4,8.';

CREATE USER IF NOT EXISTS NEXAMART_M5
  PASSWORD = '<password_m5>'
  DEFAULT_ROLE = NEXAMART_ENGINEER
  DEFAULT_WAREHOUSE = NEXAMART_WH
  MUST_CHANGE_PASSWORD = TRUE
  COMMENT = 'M2 Member 5 — resolves A1/A2/A3; rebuilds fact_ecommerce_order_line (keystone) + store-sale/return facts; owns GSV/NCR/leakage/margin/payment-failure KPI views.';

CREATE USER IF NOT EXISTS NEXAMART_M6
  PASSWORD = '<password_m6>'
  DEFAULT_ROLE = NEXAMART_ENGINEER
  DEFAULT_WAREHOUSE = NEXAMART_WH
  MUST_CHANGE_PASSWORD = TRUE
  COMMENT = 'M2 Member 6 (light) — resolves A4/A13/A15/A16; rebuilds dim_seller, review + listing-event facts; owns ecommerce-funnel KPI views.';

GRANT ROLE NEXAMART_ENGINEER TO USER NEXAMART_LEAD;
GRANT ROLE NEXAMART_ENGINEER TO USER NEXAMART_M2;
GRANT ROLE NEXAMART_ENGINEER TO USER NEXAMART_M3;
GRANT ROLE NEXAMART_ENGINEER TO USER NEXAMART_M4;
GRANT ROLE NEXAMART_ENGINEER TO USER NEXAMART_M5;
GRANT ROLE NEXAMART_ENGINEER TO USER NEXAMART_M6;

-- ----------------------------------------------------------------------------
-- 5. Verification
-- ----------------------------------------------------------------------------

USE ROLE NEXAMART_ENGINEER;
USE WAREHOUSE NEXAMART_WH;
USE DATABASE NEXAMART_DW;

SHOW SCHEMAS IN DATABASE NEXAMART_DW;
-- Should list: NEXAMART_BRONZE, NEXAMART_SILVER, NEXAMART_GOLD, NEXAMART_MARTS, INFORMATION_SCHEMA, PUBLIC

SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE();
-- Should show: NEXAMART_ENGINEER, NEXAMART_WH, NEXAMART_DW

-- M2 pre-flight (P0): confirm M1 Gold is present before starting resolution.
SELECT COUNT(*) AS gold_table_count
FROM NEXAMART_DW.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'NEXAMART_GOLD';
-- Expect 27 (13 dims + 14 facts). If 0, M1 Gold is missing — see README "M1 Gold absent" risk.

-- ----------------------------------------------------------------------------
-- Notes for lead
-- ----------------------------------------------------------------------------
-- - Account locator (e.g. xy12345.ap-south-1, or the orgname-accountname form like
--   rhxendw-yb24678) needed for the `snowflake-connector-python` widget in Databricks.
--   Find it in Snowflake → Admin → Accounts.
-- - Trial credits last ~30 days / $400. XS warehouse + auto-suspend keeps usage low.
-- - To monitor credit burn: SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY;
