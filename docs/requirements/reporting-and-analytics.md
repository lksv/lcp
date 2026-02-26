# Reporting and Analytics — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Report Definitions from Metadata

- [ ] Reports defined in metadata (without writing SQL or code)
- [ ] Visual report builder (drag & drop fields, filters, groupings)
- [ ] Multiple report types: tabular, summary, matrix (cross-tab), chart, combined
- [ ] Report templates (pre-built patterns per entity / per domain)
- [ ] Report definition versioning
- [ ] Copy report as basis for new one
- [ ] Report per role (different reports for different roles)
- [ ] Report per tenant (tenant-specific reports)

## Data Sources

- [ ] Data from single entity (simple select)
- [ ] Data from multiple entities via relations (JOINs driven from metadata)
- [ ] Data from computed / derived fields
- [ ] Data from workflow (states, throughput, SLA)
- [ ] Data from audit log (who changed what when)
- [ ] Aggregation across related records (SUM, COUNT, AVG, MIN, MAX)
- [ ] Custom SQL / query for advanced reports (with permissions)
- [ ] External data sources (API, CSV import for comparison)
- [ ] Snapshot data (historical states — what data looked like at a given date)

## Report Filters and Parameters

- [ ] Parameterized reports (user enters parameters before running — date from/to, department...)
- [ ] Default parameter values (current month, current user...)
- [ ] Filtering respects row-level and column-level permissions
- [ ] Relative date parameters (this month, last quarter, YTD...)
- [ ] Cascading parameters (region selection limits branch selection)
- [ ] Saving favorite parameter combinations per user

## Grouping and Aggregation

- [ ] Group by any field (multiple levels — region → branch → employee)
- [ ] Aggregation functions: SUM, COUNT, AVG, MIN, MAX, MEDIAN, COUNT DISTINCT
- [ ] Subtotals per group
- [ ] Grand total
- [ ] Percentage share (% of total, % of group)
- [ ] Running total / cumulative sum
- [ ] Year-over-year / period-over-period comparison
- [ ] Pivot / cross-tab (rows × columns × value)
- [ ] Top N / Bottom N (top 10 customers, worst 5 products)

## Charts and Visualizations

- [ ] Chart types: bar, column, line, area, pie, donut, scatter, bubble, funnel, waterfall, gauge
- [ ] Combined charts (bar + line on one chart)
- [ ] Stacked / grouped column chart variants
- [ ] Interactive charts (hover tooltip, click segment → drill-down)
- [ ] Axis configuration (format, range, logarithmic scale)
- [ ] Data labels on charts
- [ ] Trendline / regression curve
- [ ] Configurable color scheme (per report, per tenant)
- [ ] Responsive charts (adapt to container size)
- [ ] Heatmap visualization
- [ ] Sparklines (mini charts in table cells)
- [ ] KPI cards (large number + trend arrow + comparison with previous period)

## Drill-Down and Interactivity

- [ ] Drill-down from aggregation to detail (click on sum → display individual records)
- [ ] Drill-through to record detail (from report directly to form)
- [ ] Hierarchical drill-down (year → quarter → month → day)
- [ ] Cross-report navigation (from one report to another with pre-filled parameters)
- [ ] Interactive dashboard filtering (click on chart filters other widgets)

## Dashboards

- [ ] Dashboard builder from metadata (grid layout of widgets)
- [ ] Widget types: KPI card, chart, table, list, filter, text/HTML, iframe
- [ ] User dashboard personalization (rearrange, hide, add widgets)
- [ ] Shared dashboards (per team, per role)
- [ ] Dashboard as landing page per role
- [ ] Auto-refresh interval per widget / per dashboard
- [ ] Fullscreen mode for presentation
- [ ] Dashboard parameters / global filters (dashboard filter affects all widgets)
- [ ] Responsive layout (mobile / tablet / desktop)

## Scheduled and Automatic Reports

- [ ] Scheduled report generation (cron — daily, weekly, monthly)
- [ ] Automatic email delivery (PDF / XLSX attachment)
- [ ] Distribution per role / per group (each receives report filtered to their data)
- [ ] Conditional generation (report generated only when condition met — e.g., new records exist)
- [ ] Generated report archival (history with download capability)
- [ ] Notification on long report completion

## Report Export

- [ ] Export to PDF (with configurable template — header, footer, logo)
- [ ] Export to XLSX (with formatting, sheets per group)
- [ ] Export to CSV
- [ ] Export charts as images (PNG, SVG)
- [ ] Report print (print-friendly layout)
- [ ] Report sharing by link (URL with parameters)
- [ ] Report embedding (iframe for insertion into external systems)

## Performance and Optimization

- [ ] Report result caching (with invalidation on data change)
- [ ] Materialized views / pre-aggregated tables for frequent reports
- [ ] Asynchronous generation for large reports (background job with progress bar)
- [ ] Query timeout (protection against reports that overload DB)
- [ ] Explain / query plan display for admins
- [ ] Report result pagination (not entire dataset at once)
- [ ] Incremental refresh (only new data since last run)
- [ ] Separate DB replica for reporting (read replica — doesn't load production DB)

## Report Audit and Management

- [ ] Report catalog (overview of all available reports with descriptions)
- [ ] Permissions per report (who can run, who can edit definition)
- [ ] Usage tracking (which report, who, and how often runs)
- [ ] Deprecation / archival of unused reports
- [ ] Report definition import / export between environments

---

## Key Points

- **Separate read replica for reporting** — reports with aggregations across millions of records will bring down the production DB. Read replica is the simplest way to isolate reporting.
- **Snapshot data** — "what was the state of orders as of Dec 31" is a common requirement. Without historical snapshots you can't reconstruct it because data has since changed.
- **Conditional scheduled reports** — sending an empty report every Monday is spam. A report should be sent only when there's new data or an exception that needs attention.
- **Row-level security in reports** — branch manager sees only their data, regional director sees entire region. Filters must pass through the authorization layer, otherwise it's a security hole.
- **Drill-down** — a static report in PDF isn't enough. Users want to click a number and see what it's composed of. Without drill-down they generate more and more sub-reports.
- **KPI cards with trend** — the most used dashboard widget. A number alone says nothing, but number + arrow + comparison with previous period gives immediate context.
