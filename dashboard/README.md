# dashboard/

The stakeholder dashboard (M2 LO16). **Tool TBD** — Power BI Desktop (`.pbix`) or Tableau Public (`.twbx`).

- **Connect to `NEXAMART_MARTS` views ONLY** — never to Gold or Silver tables.
- Build the 5 pages defined in [`../docs/dashboard_spec.md`](../docs/dashboard_spec.md): Executive Summary, Sales by Channel, Inventory Health, Customer Journey, NexaLocal & Seller Quality.
- Confirmed vs Estimated visually separated on every page; Baseline | Campaign | Post comparison on every revenue/inventory/conversion chart.
- Save the source file here as `nexamart_dashboard.pbix` (or `.twbx`).
- Put one PNG per page in `screenshots/`.

Do **not** start the dashboard until `validation_suite.sql` passes — a dashboard on unvalidated Gold gives the CEO wrong numbers.
