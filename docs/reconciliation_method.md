# Reconciliation Method (M2 — report Section 4 / LO14)

The CEO's question is really: *why did every team report a different number?* This document is the
backbone of report Section 4 — the GSV → NCR waterfall plus the per-team divergence narrative.

## The GSV → NCR waterfall (name + quantify every step)

```
GSV (Gross Sale Value, all confirmed-transaction channels)
  − Cancellations              ← A1 (cancelled orders wrongly carrying revenue)
  − Full refunds
  − Partial refunds            ← B2 (period attribution: recognised in return period)
  − Tax pass-through           ← A3 (normalise all channels to tax-exclusive)
  − Shipping pass-through
  = NCR (Net Confirmed Revenue)
```

Each deduction is a labelled step in the waterfall chart; the report quantifies each in ₹.
NexaLocal seller-marked transactions without platform payment are **excluded** from NCR (they are
ESTIMATED Classified GMV, reported separately with a band).

## Why each of the seven teams had a different number

| Team | Reported | Why it differed | Resolving anomaly |
|---|---|---|---|
| **Sales** | +34% | counted cancelled orders + NexaLocal seller-marked-sold as revenue | A1, A4/B6 |
| **Finance** | +11% | strict NCR — excluded everything Sales over-counted | (the correct base) |
| **Marketplace** | classified GMV inflated | counted estimates that must be labelled ESTIMATED | B6 (+ A12 relisting) |
| **Inventory** | "3 stockouts" | website-available while warehouse-empty; negative ATP | A5, A6 |
| **Ecommerce** | abandonment +22% | driven by inventory mismatch + broken delivery promises | A5/A6, A14 |
| **Store Ops** | pickup handling tripled | BOPIS/BORIS workload invisible in store KPIs | B7, BORIS separation |
| **Support** | 340 reports | complaint volume inflated by duplicate cases across 3 channels | A16 |

Cross-cutting causes: **tax-basis mismatch (A3)** made cross-channel sums incomparable;
**refund-period attribution (B2)** shifted revenue between Aug and Sep.

## The single reconciled answer

Report Section 4 shows the path from each team's number to the one validated number, and Section 5
answers the campaign question using NCR + Net Margin (CONFIRMED) alongside Estimated Classified GMV
(ESTIMATED, labelled) — never mixing certainty levels.
