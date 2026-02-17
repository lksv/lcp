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
# Visit http://localhost:3000/admin
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
| Service auto-discover | Custom default service in `app/lcp_services/defaults/` | [Extensibility](guides/extensibility.md#auto-discovery-setup) |

## CRM App (`examples/crm/`)

A more complete example demonstrating advanced features like custom actions, event handlers, multiple roles, and field-level permissions. Uses the **Ruby DSL** for model definitions.

### Running

```bash
cd examples/crm
bundle install
bundle exec rails db:prepare
bundle exec rails s -p 3001
# Visit http://localhost:3001/admin
```

### Models

- **Company** — has_many contacts, has_many deals
- **Contact** — belongs_to company, has_many deals; computed `full_name` field
- **Deal** — belongs_to company, belongs_to contact; computed `weighted_value`, dynamic defaults, conditional validations

### Presenters

| Presenter | Purpose |
|-----------|---------|
| `company_admin` | Company management |
| `contact_admin` | Contact management |
| `deal_admin` | Deal management with custom actions |
| `deal_pipeline` | Read-only pipeline view |

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
| Enum fields | Deal stage with badge display | [Enum values](reference/models.md#enum_values), [Display types](reference/presenters.md#display-types-index) |
| Decimal fields | Deal value with currency display | [Column options](reference/models.md#column_options) |
| Multiple presenters | Admin view + read-only pipeline | [Presenters](reference/presenters.md) |
| Action visibility | `close_won` hidden for closed deals | [Action Visibility](reference/presenters.md#action-visibility) |
| Field-level transforms | `strip` + custom `titlecase` on contact names | [Transforms](reference/models.md#transforms) |
| Custom transform service | `titlecase` in `app/lcp_services/transforms/` | [Extensibility](guides/extensibility.md#custom-transforms) |
| Conditional validations | `value` required past lead stage; `contact_id` required for negotiation+ | [When](reference/models.md#conditional-validations-when) |
| Cross-field validations | `expected_close_date` must be after `created_at` | [Comparison](reference/models.md#comparison) |
| Service validators | `deal_credit_limit` checks total company deals under 1M | [Service Validators](guides/extensibility.md#service-validators) |
| Dynamic defaults | `expected_close_date` defaults to 30 days out via service | [Defaults](reference/models.md#default) |
| Computed fields (template) | Contact `full_name` from `{first_name} {last_name}` | [Computed](reference/models.md#computed) |
| Computed fields (service) | Deal `weighted_value` from value * progress | [Computed](reference/models.md#computed) |
| Service auto-discover | Custom services in `app/lcp_services/` | [Extensibility](guides/extensibility.md#auto-discovery-setup) |
