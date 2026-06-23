# NexaMart M2 — Presentation Outline (5–10 slides)

**Audience:** CEO, CFO, Chief Data Officer. Keep it simple, no technical jargon, answer the business
question. Mirrors the brief §12.4 fixed sequence. Export to `nexamart_m2_presentation.pptx` (or PDF) for the ZIP.

| # | Slide | Content |
|---|---|---|
| 1 | **The Problem** | One slide showing the conflicting numbers each team reported (Sales +34%, Finance +11%, etc.). Make the business problem tangible. |
| 2 | **What We Built** | Architecture (Bronze → Silver → Gold → Marts) + tools (Snowflake, Databricks, BI). Keep it visual. |
| 3 | **What We Found (1)** | Top impactful anomalies — A1 cancelled-in-revenue (₹0.41 Cr), A4 seller-sold mislabelled as confirmed (₹1.72 Cr → ESTIMATED), A3 tax-basis mismatch (₹16.25 Cr comparable basis) — and what they meant for the numbers. |
| 4 | **What We Found (2)** | A4 NexaLocal seller-sold as revenue (₹1.72 Cr, now ESTIMATED), A11 customer-9999 collision, inventory anomalies (A5/A6). |
| 5 | **The Reconciled Numbers (1)** | GSV → NCR waterfall: each deduction named and quantified (cancellations, refunds, tax, shipping). |
| 6 | **The Reconciled Numbers (2)** | Confirmed GMV vs **Estimated Classified GMV** (separate, with band) + Net Margin. Show the reconciliation to one number. |
| 7 | **Was the Campaign Successful?** | One clear, direct, defensible answer with evidence (NCR, Net Margin, certainty-labelled). "It depends" is not acceptable. |
| 8 | *(optional)* Inventory findings | Stockouts/oversell during campaign; return-to-restock. Only if dashboard-supported. |
| 9 | *(optional)* Customer journey | Funnel campaign vs baseline; cart abandonment; BOPIS readiness. |
| 10 | *(optional)* Seller quality | Risk tier distribution; duplicate-listing inflation; fraud-ring finding. |

**Rules:** Confirmed vs Estimated always visually separated; campaign vs baseline shown; no engineering
jargon in titles ("Net Confirmed Revenue — Store Channel", not `fact_…net_sale_excl_tax`).
