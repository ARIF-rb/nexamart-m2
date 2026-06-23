# NexaMart M2 — Presentation Outline (24 slides: 13 core + 11 back-up appendix)

**Audience:** CEO, CFO, Chief Data Officer. Answer the business question with evidence; no engineering
jargon in titles. Built from the professor's template; figures trace to live `NEXAMART_MARTS` views.
File: `nexamart_m2_presentation.pptx`. The 12-slide presented deck = title + 11 numbered content slides;
the Q&A slide and the Evidence Appendix are back-up and **do not** count toward the 12-slide limit.

## Core deck (design-matched template slides; on-slide numbering in the title)

| # | Slide | Content |
|---|---|---|
| 1 | **Title** | NexaMart Enterprise Data Warehouse — Milestone 2 · Assignment 4 · Group Arif. 6-member table (name, roll no, role, 100%). Mini Source→Pipeline→KPIs→Business-Answer flow. |
| 2 | **1. Business Problem** | Why a DW was needed: each department reported a different number. Was the Back-to-School campaign actually successful, or were the numbers misleading? |
| 3 | **2. Overall Architecture** | SQLite → Databricks → Snowflake Bronze → Silver → Gold → Marts → Power BI. Per-layer purpose + evidence (Bronze 61 tables / 843,304 rows; Gold 27 = 13 dim + 14 fact; Marts 28 views). |
| 4 | **3. Assignment 3 / Milestone 1 Completion** | What M1 delivered (Bronze load, Silver notebooks, 13 dims + 14 facts, Bus Matrix, grains, anomaly flags). M1 *preserves* anomalies in Silver — it did not solve them. |
| 5 | **4. Assignment 4 / Milestone 2 Completion** | SQL anomaly ID → PySpark fix → Gold rebuild → validation 9/10 → 28 KPI views → BI dashboard → campaign conclusion. Every claim linked to evidence (E2–E6). |
| 6 | **5. Anomalies Found** | 24 total = 16 Category A (clear bugs) + 8 Category B (judgment calls). Representative: A1, A3, A4→ESTIMATED, A6, A16, B6. |
| 7 | **6. How We Detected the Anomalies** | Detection logic + tool + evidence: A1 `status='CANCELLED' AND subtotal_excl_tax>0`→94; A6 negative qty→8; A16 duplicate flag→7; A4 `SELLER_SOLD`→449; B6 GMV model. |
| 8 | **7. How We Solved the Anomalies** | Before → fix → after → validation: 94→0, tax normalised, 8→0, 7 deduped, A4 449 relabelled ESTIMATED (C9 segregation PASS). |
| 9 | **8. Gold Rebuild and Validation** | What changed after the fix: 16 Silver tables corrected, 9 of 14 facts rebuilt, validation 9/10 (C8 documented). GSV 141.51 / NCR 138.35 Cr. |
| 10 | **9. BI Dashboard Analysis** | Executive / Sales / Inventory / Customer-Journey / NexaLocal cards. GSV ₹141.51 Cr vs NCR ₹138.35 Cr; leakage ₹0.41 Cr cancel + ₹0.65 Cr refunds; inventory 99.47% accurate; Estimated GMV never added to NCR. |
| 11 | **10. Final Business Conclusion** | Verdict: **Successful — clearly positive** (certainty-segregated, anomaly-corrected). Campaign-window confirmed revenue +₹1.27 Cr above baseline; legacy +34% headline inflated by A1+A4. Net Margin = **Deferred** (COGS unpopulated). |
| 12 | **11. Member-Wise Contribution and Final Proof** | Per-member assigned work, output, 100%, evidence; required-proof checklist (all Shown=Yes). |
| 13 | **Appendix: Questions** | Likely-question prep cards (anomaly impact, detection proof, fix logic, rebuild scope, certainty, member work). Back-up — not in the 12-slide limit. |

## Evidence Appendix (back-up proof; live SQL cards + real Power BI pages)

| # | Slide | Content |
|---|---|---|
| 14 | **Evidence Appendix — divider** | States provenance: figures trace to live `NEXAMART_MARTS`; SQL run as NEXAMART_ENGINEER on NEXAMART_DW, 24 Jun 2026; dashboard pages exported from `nexamart_dashboard.pbix`. |
| 15 | Bronze ingestion + Gold Kimball model | `sf_e1_bronze.png` (61 tables / 843,304 rows) + `sf_e1_gold.png` (2-column: 13 dimensions \| 14 facts = 27). |
| 16 | Marts KPI views + Silver anomaly flags | `sf_e5_marts.png` (28 views) + `sf_e2_silver_flags.png` (ANOMALY_FLAG counts per Silver table). |
| 17 | Anomaly resolution + validation suite | `sf_e3_resolution.png` (detected counts + reason codes) + `sf_e4_validation.png` (9/10 PASS, C8 documented). |
| 18 | Reconciled KPIs — GSV/NCR + revenue leakage | `sf_e5_gsv_ncr.png` (GSV 1,415,087,895 / NCR 1,383,506,490) + `sf_e5_leakage.png` (refunds 6,450,710 + cancel 4,078,605). |
| 19 | Reconciled KPIs — Estimated Classified GMV | `sf_e5_estgmv.png` (point 12,603,544; band 8.19M–17.01M; ESTIMATED; never summed into NCR). |
| 20 | BI Dashboard — Sales by Channel | Executive KPIs: NCR 1,383.51M, GSV 1,415.09M, payment-failure 6.96%. |
| 21 | BI Dashboard — Inventory Health | Stockout 0.01%, available stock 14.22K, oversell 5, inventory accuracy 0.99. |
| 22 | BI Dashboard — Customer Journey | Checkout conversion, cart abandonment 41.53%, on-time delivery 54.23%, BOPIS readiness. |
| 23 | BI Dashboard — Customer Journey funnel | Cart sessions 1.65K → checkout 0.96K → purchases 0.96K (58.5%). |
| 24 | BI Dashboard — NexaLocal & Seller Quality | Estimated GMV gauge, active listings 538, seller risk tiers, validated-report rate 94.74%. |

**Rules honoured:** Confirmed vs Estimated always visually separated; campaign vs baseline shown;
business-language titles; every figure traceable to a live query or a real dashboard page.
