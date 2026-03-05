# Example Apps

LCP Ruby includes two example Rails applications demonstrating basic and advanced features.

## TODO App (`examples/todo/`)

A minimal example demonstrating basic CRUD with associations, using YAML-based configuration.

### Running

```bash
cd examples/todo
bundle install
bundle exec rails db:prepare
bundle exec rails s -p 3000
# Visit http://localhost:3000
```

### Models

- **TodoList** — has_many todo_items
- **TodoItem** — belongs_to todo_list

### Features Demonstrated

| Feature | Where | Docs |
|---------|-------|------|
| Basic CRUD | Both models have full create/read/update/delete | |
| Associations | TodoItem belongs_to TodoList | [Associations](reference/models.md#associations) |
| Association selects | TodoItem form has a dropdown for selecting the parent list | [How it works](reference/presenters.md#how-association-selects-work) |
| Search | Text search on todo item titles | [Search](reference/presenters.md#search-configuration) |
| Timestamps | Both models have `created_at`/`updated_at` | |
| Single admin role | One role with full access | [Permissions](reference/permissions.md) |
| Field-level transforms | `strip` on title fields | [Transforms](reference/models.md#transforms) |
| Dynamic defaults | `start_date` defaults to `current_date`, `due_date` defaults to `one_week_from_now` service | [Defaults](reference/models.md#default) |
| Conditional validations | `due_date` required only when `completed` is false | [When](reference/models.md#conditional-validations-when) |
| Cross-field validations | `due_date` must be on or after `start_date` | [Comparison](reference/models.md#comparison) |
| Record positioning | Todo items with drag-and-drop reordering scoped by list | [Positioning](design/record_positioning.md) |
| Service auto-discover | Custom default service in `app/lcp_services/defaults/` | [Extensibility](guides/extensibility.md#auto-discovery-setup) |

## CRM App (`examples/crm/`)

A more complete example demonstrating advanced features like custom actions, event handlers, multiple roles, and field-level permissions. Uses the **Ruby DSL** for model definitions.

### Running

```bash
cd examples/crm
bundle install
bundle exec rails db:prepare
bundle exec rails s -p 3001
# Visit http://localhost:3001
```

### Models

- **Company** — has_many contacts, has_many deals; aggregate columns (contacts_count, deals_count, total_deal_value)
- **Contact** — belongs_to company, has_many deals; computed `full_name` field; aggregate columns (activities_count)
- **Deal** — belongs_to company, belongs_to contact; computed `weighted_value`, dynamic defaults, conditional validations
- **Activity** — belongs_to company, contact, deal; enum `activity_type` (call, meeting, email, note, task); soft_delete, userstamps

### Presenters

| Presenter | Purpose |
|-----------|---------|
| `company` | Company management (table layout) |
| `company_short` | Compact company list |
| `company_tiles` | Company card grid with aggregate counts and deal values |
| `company_archive` | Archived (soft-deleted) companies |
| `contact` | Contact management (table layout) |
| `contact_short` | Compact contact list |
| `contact_tiles` | Contact card grid (4 columns) with email/phone links |
| `deal` | Deal management with custom actions (table layout) |
| `deal_short` | Compact deal list |
| `deal_tiles` | Deal card grid with stage badges, progress bars, and summary bar |
| `deal_pipeline` | Read-only pipeline view |
| `activity` | Activity management (table layout) |
| `activity_short` | Compact activity list |
| `activity_tiles` | Activity card grid with type badges and dot-path associations |

### Roles

| Role | Access |
|------|--------|
| `admin` | Full access to everything |
| `sales_rep` | Restricted write access, can execute `close_won` action |
| `viewer` | Read-only access to limited fields and pipeline presenter only |

### Features Demonstrated

| Feature | Where | Docs |
|---------|-------|------|
| Business types | Contact email (`:email`), phone (`:phone`); Company website (`:url`), phone (`:phone`) | [Types](reference/types.md) |
| Custom actions | `close_won` marks deal as won | [Custom Actions](guides/custom-actions.md) |
| Event handlers | `on_stage_change` logs stage transitions | [Event Handlers](guides/event-handlers.md) |
| Hash event conditions | `on_stage_change` fires only when stage is not `lead` | [Event Conditions](reference/models.md#condition) |
| Scopes | `open_deals` (where_not closed), `won`, `lost` | [Scopes](reference/models.md#scopes) |
| Predefined filters | Filter buttons on deals index | [Search](reference/presenters.md#search-configuration) |
| Field-level permissions | `value` writable only by admin | [Field Overrides](reference/permissions.md#field-overrides) |
| Record rules | Closed deals read-only for non-admin | [Record Rules](reference/permissions.md#record-rules) |
| Masked fields | Field overrides with `readable_by` | [Field Overrides](reference/permissions.md#field-overrides) |
| Enum fields | Deal stage with badge display | [Enum values](reference/models.md#enum_values), [Renderers](reference/presenters.md#renderers) |
| Decimal fields | Deal value with currency display | [Column options](reference/models.md#column_options) |
| Multiple presenters | Admin view + read-only pipeline + tiles views | [Presenters](reference/presenters.md) |
| View groups | Companies, Contacts, Deals, Activities each have 3 views (Detailed, Short, Tiles) with a view switcher | [View Groups](guides/view-groups.md) |
| Tiles view | Card grid layout for all 4 main entities with renderers, dot-path fields, sort dropdown, per-page selector | [Tiles](guides/tiles.md) |
| Summary bar | Deal tiles show total value (sum), average value (avg), and deal count | [Tiles](guides/tiles.md#summary-bar) |
| Presenter DSL inheritance | All `_tiles` and `_short` presenters use `inherits:` to reuse show/form/actions from the base presenter | [DSL Inheritance](reference/presenter-dsl.md#inheritance) |
| Action visibility | `close_won` hidden for closed deals | [Action Visibility](reference/presenters.md#action-visibility) |
| Field-level transforms | `strip` + custom `titlecase` on contact names | [Transforms](reference/models.md#transforms) |
| Custom transform service | `titlecase` in `app/lcp_services/transforms/` | [Extensibility](guides/extensibility.md#custom-transforms) |
| Conditional validations | `value` required past lead stage; `contact_id` required for negotiation+ | [When](reference/models.md#conditional-validations-when) |
| Cross-field validations | `expected_close_date` must be after `created_at` | [Comparison](reference/models.md#comparison) |
| Service validators | `deal_credit_limit` checks total company deals under 1M | [Service Validators](guides/extensibility.md#service-validators) |
| Dynamic defaults | `expected_close_date` defaults to 30 days out via service | [Defaults](reference/models.md#default) |
| Computed fields (template) | Contact `full_name` from `{first_name} {last_name}` | [Computed](reference/models.md#computed) |
| Computed fields (service) | Deal `weighted_value` from value * progress | [Computed](reference/models.md#computed) |
| Menu badges | Dynamic badges on sidebar menu items (count, text, template) | [Menu Badges](reference/menu.md#badges) |
| Data providers | `open_deals_count`, `active_contacts_count`, `won_deals_count`, `pipeline_value` in `app/lcp_services/data_providers/` | [Menu Guide](guides/menu.md#adding-badges) |
| Service auto-discover | Custom services in `app/lcp_services/` | [Extensibility](guides/extensibility.md#auto-discovery-setup) |
| Aggregate columns | Company: `contacts_count`, `deals_count`, `total_deal_value`, `won_deals_value` (filtered SUM); Contact: `activities_count`, `completed_activities_count` (filtered COUNT) | [Aggregates](reference/models.md#aggregates) |

## Showcase App (`examples/showcase/`)

A comprehensive feature catalog demonstrating nearly every platform capability. Each feature area has its own dedicated model, presenter, and view group.

### Running

```bash
cd examples/showcase
bundle install
bundle exec rails db:prepare
bundle exec rails s -p 3002
# Visit http://localhost:3002
```

### Aggregate Columns Demo

The **Aggregate Projects** section (`showcase_aggregates`) demonstrates all aggregate column types:

- **COUNT** — `tasks_count` (total tasks per project)
- **Filtered COUNT** — `completed_count` (only tasks with `status: done`)
- **SUM** — `total_hours` (sum of estimated hours)
- **Filtered SUM** — `completed_cost` (cost of completed tasks only)
- **AVG** — `avg_priority` (average priority score)
- **MAX** — `latest_due_date` (latest task due date)
- **MIN** — `earliest_due_date` (earliest task due date)
- **COUNT DISTINCT** — `unique_assignees` (distinct assignee names)

All aggregate columns are sortable in the index view and displayed in dedicated sections on the show page.

### Tiles View Demo

Five presenters demonstrate all tiles configuration options:

| Presenter | Model | Key Tiles Features |
|-----------|-------|--------------------|
| `showcase_fields_tiles` | showcase_field | All renderer types (currency, rating, boolean_icon, email_link, color_swatch, date), summary bar (sum/avg/count), sort dropdown, per-page selector |
| `showcase_aggregates_tiles` | showcase_aggregate | 2-column layout, `actions: :inline`, summary bar with all 5 functions (sum, avg, count, max, min) |
| `articles_tiles` | article | Dot-path fields (`category.name`, `author.name`), predefined filters (Published/Drafts), relative_date renderer |
| `employees_tiles` | employee | 4-column layout, `actions: :none`, role badge color_map, dot-path `department.name` |
| `features_tiles` | feature | Description with `max_lines: 2`, category badge with 20-value color_map, status badges |

The Feature Catalog includes 14 entries under the **Tiles** category documenting each configuration option with config examples and demo links.
