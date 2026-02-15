# Example Apps

LCP Ruby includes two example Rails applications demonstrating basic and advanced features.

## TODO App (`examples/todo/`)

A minimal example demonstrating basic CRUD with associations.

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

| Feature | Where |
|---------|-------|
| Basic CRUD | Both models have full create/read/update/delete |
| Associations | TodoItem belongs_to TodoList ([association docs](reference/models.md#associations)) |
| Association selects | TodoItem form has a dropdown for selecting the parent list ([how it works](reference/presenters.md#how-association-selects-work)) |
| Search | Text search on todo item titles ([search docs](reference/presenters.md#search-configuration)) |
| Timestamps | Both models have `created_at`/`updated_at` |
| Single admin role | One role with full access ([permissions docs](reference/permissions.md)) |

## CRM App (`examples/crm/`)

A more complete example demonstrating advanced features like custom actions, event handlers, multiple roles, and field-level permissions.

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
- **Contact** — belongs_to company, has_many deals
- **Deal** — belongs_to company, belongs_to contact

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
| Custom actions | `close_won` marks deal as won | [Custom Actions](guides/custom-actions.md) |
| Event handlers | `on_stage_change` logs stage transitions | [Event Handlers](guides/event-handlers.md) |
| Scopes | `open_deals` (where_not closed), `won`, `lost` | [Scopes](reference/models.md#scopes) |
| Predefined filters | Filter buttons on deals index | [Search](reference/presenters.md#search-configuration) |
| Field-level permissions | `value` writable only by admin | [Field Overrides](reference/permissions.md#field-overrides) |
| Record rules | Closed deals read-only for non-admin | [Record Rules](reference/permissions.md#record-rules) |
| Masked fields | Field overrides with `readable_by` | [Field Overrides](reference/permissions.md#field-overrides) |
| Enum fields | Deal stage with badge display | [Enum values](reference/models.md#enum_values), [Display types](reference/presenters.md#display-types-index) |
| Decimal fields | Deal value with currency display | [Column options](reference/models.md#column_options) |
| Multiple presenters | Admin view + read-only pipeline | [Presenters](reference/presenters.md) |
| Action visibility | `close_won` hidden for closed deals | [Action Visibility](reference/presenters.md#action-visibility) |
