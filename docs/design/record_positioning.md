# Design: Record Positioning

**Status:** Proposed
**Date:** 2026-02-21

## Problem

Users need to maintain an explicit ordering of records in dynamic models. Typical use cases:

- Pipeline stages (sales pipeline with ordered stages)
- Priority lists (tasks sorted by user-defined priority)
- Menu items, workflow steps, checklist items
- Any entity where business logic depends on a user-controlled sequence

The platform currently supports drag-and-drop reordering only for **nested fields** (child records within a parent form). This works because the entire form is submitted atomically — position values are set by JavaScript and saved in a single transaction.

For **top-level records** (standalone models displayed in an index table), there is no positioning support. The `position` field is just a plain integer with no server-side logic — no automatic gap closing on delete, no atomic reordering, no race condition protection.

## Goals

- Declare positioning on a model via YAML/DSL (single source of truth)
- Support scoped positioning (position within a parent group)
- Automatic position management: insert at end, close gaps on delete, atomic reorder
- Drag-and-drop reordering in the index table (presenter opt-in)
- Presenter auto-detects positioning config from its model — no redundant declaration
- Permission-controlled: reorder respects `update` permission and field-level write access

## Non-Goals

- Bulk reorder API (reorder multiple records in one request) — can be added later
- Keyboard-based reorder (accessibility enhancement for later)
- Nested fields changes — the existing drag-and-drop for nested fields is unaffected

## Current State

### Nested fields (works today)

| Layer | Implementation |
|-------|---------------|
| Model YAML | `position` as plain `integer` field; association `order: { position: asc }` |
| Presenter YAML | `sortable: true` on `nested_fields` form section |
| Frontend | `nested_forms.js` — drag handle, mouse + touch, updates hidden `position` input |
| Controller | `sortable_position_field()` helper; position field permitted in nested attributes |

This is purely client-side position management. The server stores whatever integers the form sends. No gap closing, no conflict resolution — but that is acceptable because the parent form is a single atomic save.

### Top-level records (missing)

No support. A user can define `position: integer` and `default_sort: { field: position, direction: asc }`, but:

- New records get no automatic position (NULL or 0)
- Deleting a record leaves a gap
- No reorder endpoint exists
- No drag-and-drop in the index table
- Concurrent edits can produce duplicate positions

## Design

### Gem choice: `positioning`

Use the [`positioning`](https://github.com/brendon/positioning) gem (by Brendon Muir, same author as `acts_as_list`). Reasons:

- Clean declarative API: `positioned column: :position, on: [:parent_id]`
- No monkey-patching of ActiveRecord (unlike `acts_as_list`)
- Automatic gap closing on destroy
- Automatic append-to-end on create
- Supports relative positioning: `position = { after: 5 }`, `position = :first`
- Scoped positioning built-in (position within a parent group)
- Handles scope changes (moving a record to a different group)
- Transaction-safe reordering

### Model YAML — new top-level `positioning` key

```yaml
# config/lcp_ruby/models/stage.yml
name: stage
fields:
  - name: name
    type: string
  - name: position
    type: integer
  - name: pipeline_id
    type: integer

associations:
  - type: belongs_to
    name: pipeline
    target_model: pipeline

positioning:
  field: position          # optional, default: "position"
  scope: pipeline_id       # optional, string or array of strings
```

The `positioning` key is the single source of truth. When present:

1. The `positioning` gem's `positioned` macro is applied to the model
2. The position column gets a `NOT NULL` constraint automatically
3. The `SchemaManager` adds a unique index on `[scope_columns..., position_column]`

**Minimal form** — when field name is `position` and no scope:

```yaml
positioning: true
```

Equivalent to `positioning: { field: position }`.

**Multi-column scope:**

```yaml
positioning:
  scope: [pipeline_id, category]
```

### Model DSL

```ruby
define_model :stage do
  field :name, :string
  field :position, :integer
  belongs_to :pipeline, model: :pipeline

  # Minimal
  positioning

  # With options
  positioning field: :position, scope: :pipeline_id

  # Multi-scope
  positioning scope: [:pipeline_id, :category]
end
```

### Presenter — `reorderable: true` on index

The presenter enables drag-and-drop reordering in the index table:

```yaml
# config/lcp_ruby/presenters/stages.yml
index:
  reorderable: true
  table_columns:
    - field: name
      link_to: show
    - field: position
      sortable: false
```

**Why `reorderable` and not `sortable`?**

The key `sortable` is already used at two other levels with different meanings:

| Level | Key | Meaning |
|-------|-----|---------|
| `table_column` | `sortable: true` | Column header is clickable for sorting |
| `form_section` (nested_fields) | `sortable: true` | Drag-and-drop reordering of child rows in a form |
| `index` | ~~`sortable`~~ | Would be a third meaning — ambiguous |

`reorderable` clearly describes the user action (manually reorder records via drag-and-drop) and avoids confusion with column sorting.

**Resolution logic:**

1. Presenter has `reorderable: true` on index config
2. Engine resolves the model via `presenter.model`
3. Engine reads `model_definition.positioning` to get field name and scope
4. If model has no `positioning` config → boot-time validation error

No position field override in the presenter. The model is the single source of truth. If a future use case requires an override, it can be added as an optional key without breaking changes.

**Implied behavior when `reorderable: true`:**

- `default_sort` is automatically set to `{ field: <position_field>, direction: asc }` unless explicitly overridden
- User-initiated column sorting (clicking table headers) temporarily overrides position order but does not disable drag-and-drop
- The position column itself should not have `sortable: true` on its table_column (sorting by position is the default, and toggling it would be confusing)
- The position column does **not** need to be included in `table_columns`. Drag-and-drop works regardless — position is managed invisibly. Including the position column is optional (useful for debugging or when users want to see the numeric order)

### Presenter DSL

```ruby
define_presenter :stages do
  model :stage
  slug "stages"

  index do
    reorderable true

    column :name, link_to: :show
    column :position
  end
end
```

### Controller — `reorder` action

New action on `ResourcesController`:

```ruby
# PATCH /:lcp_slug/:id/reorder
# Note: set_record is a before_action that loads @record from params[:id].
def reorder
  unless current_model_definition.positioned?
    head :not_found
    return
  end

  authorize @record, :update?
  authorize_position_field!

  stale = verify_list_version!
  return if stale

  position_value = parse_position_param
  pos_field = current_model_definition.positioning_field
  @record.update!(pos_field => position_value)

  render json: {
    position: @record.reload.send(pos_field),
    list_version: compute_list_version(@record)
  }
end

private

def authorize_position_field!
  field = current_model_definition.positioning_field
  unless current_evaluator.field_writable?(field)
    raise Pundit::NotAuthorizedError,
      "Not allowed to write positioning field '#{field}'"
  end
end

# Returns true if the list is stale (conflict response already rendered),
# false otherwise. The caller must `return if stale` to avoid DoubleRenderError.
def verify_list_version!
  return false unless params[:list_version].present?

  current_version = compute_list_version(@record)
  return false if current_version == params[:list_version]

  render json: { error: "list_version_mismatch", list_version: current_version },
         status: :conflict
  true
end

def compute_list_version(record)
  scope = @model_class.all
  current_model_definition.positioning_scope.each do |col|
    scope = scope.where(col => record.send(col))
  end
  pos_field = current_model_definition.positioning_field
  ids_in_order = scope.order(pos_field => :asc).pluck(:id)
  Digest::SHA256.hexdigest(ids_in_order.join(","))
end

def parse_position_param
  raw = params[:position]
  case raw
  when ActionController::Parameters, Hash
    raw.to_unsafe_h.transform_values { |v| v.to_i }.symbolize_keys
  when "first"
    :first
  when "last"
    :last
  else
    raw.to_i
  end
end
```

The `positioning` gem handles all the reordering logic internally — when you set `record.position = 3`, it shifts other records automatically within a transaction.

The reorder action returns `200` with the record's final position (the gem may clamp values) and an updated `list_version`. This allows the frontend to update the position display and keep the version in sync for subsequent reorder operations without a full page reload.

The route is registered globally for all models. For non-positioned models, the action returns `404` early. This avoids conditional route generation at boot time.

**Staleness detection via `list_version`:** The frontend sends a `list_version` hash with each reorder request. The server recomputes the hash from the current state of the positioning scope and compares. On mismatch, it returns `409 Conflict` — the frontend reloads the list. See [Concurrent reordering](#concurrent-reordering) for details.

### Route

```ruby
# lib/lcp_ruby/engine.rb (routes)
resources :records, path: ":lcp_slug", param: :id do
  member do
    patch :reorder
  end
end
```

Produces: `PATCH /:lcp_slug/:id/reorder`

### Frontend — index table drag-and-drop

New JavaScript file `app/assets/javascripts/lcp_ruby/index_sortable.js`:

1. Activated when `<table class="lcp-table" data-reorder-url="...">` is present
2. Reads `data-list-version` from the table element and stores it in memory
3. Drag handle column added as first `<td>` in each row
4. Mouse and touch support (same pattern as `nested_forms.js`)
5. On drop: sends `PATCH /:lcp_slug/:id/reorder` with relative position and list version:
   - Dropped after another row: `position: { after: <previous_row_record_id> }`
   - Dropped before another row: `position: { before: <next_row_record_id> }`
   - Dropped at the very top of the visible list: `position: { before: <first_row_record_id> }`
   - Always includes: `list_version: <current_stored_hash>`
   The `{ before: id }` form is necessary because `position: 1` (absolute) is only correct on the first page. On page 2+, the top of the visible list is not position 1.
6. On success (200): update `list_version` in memory from response; update the position display value from `{ position: <n> }` if the position column is visible; DOM already moved
7. On conflict (409): reload the page to get fresh data and a new `list_version`; show a brief flash message ("List was modified by another user, reloading...")
8. On other failure: revert DOM position, show flash error
9. CSRF token included via `meta[name="csrf-token"]`

**Scoped behavior:** When the model has a scoped position (e.g., `scope: pipeline_id`), drag-and-drop only works within the same scope. The index table should group or filter by scope for reordering to make sense. Cross-scope drag is not supported in the initial implementation.

### View changes

`app/views/lcp_ruby/resources/index.html.erb`:

```erb
<% reorderable = current_presenter.index_config["reorderable"] &&
                 current_model_definition.positioned? &&
                 current_evaluator.can?(:update) &&
                 current_evaluator.field_writable?(current_model_definition.positioning_field) %>
<% reorder_url = reorderable ? reorder_resource_path(":id") : nil %>
<% list_version = reorderable ? compute_list_version_from_records(@records) : nil %>
<table class="lcp-table"
  <%= "data-reorder-url=#{reorder_url}" if reorderable %>
  <%= "data-list-version=#{list_version}" if reorderable %>>
  <thead>
    <tr>
      <% if reorderable %>
        <th class="lcp-drag-column"></th>
      <% end %>
      ...
    </tr>
  </thead>
  <tbody>
    <% @records.each do |record| %>
      <tr data-record-id="<%= record.id %>">
        <% if reorderable %>
          <td class="lcp-drag-column"><span class="lcp-drag-handle">&#9776;</span></td>
        <% end %>
        ...
      </tr>
    <% end %>
  </tbody>
</table>
```

The `data-list-version` attribute contains a SHA-256 hash of record IDs in position order within the positioning scope. The frontend sends this value with each reorder request and updates it from the response.

Helper in `ApplicationController`:

```ruby
def compute_list_version_from_records(records)
  return nil unless current_model_definition.positioned?
  pos_field = current_model_definition.positioning_field
  ids_in_order = records.reorder(pos_field => :asc).pluck(:id)
  Digest::SHA256.hexdigest(ids_in_order.join(","))
end
helper_method :compute_list_version_from_records
```

### ModelDefinition changes

```ruby
# lib/lcp_ruby/metadata/model_definition.rb
attr_reader :name, :label, ..., :positioning_config  # new

def initialize(attrs = {})
  # ...existing...
  @positioning_config = attrs[:positioning_config]
end

def self.from_hash(hash)
  new(
    # ...existing...
    positioning_config: normalize_positioning(hash["positioning"])
  )
end

def positioning
  @positioning_config
end

def positioned?
  @positioning_config.present?
end

def positioning_field
  positioning&.fetch("field", "position") || "position"
end

def positioning_scope
  Array(positioning&.fetch("scope", nil)).compact
end

private_class_method def self.normalize_positioning(raw)
  case raw
  when true
    { "field" => "position" }
  when Hash
    result = {}
    result["field"] = (raw["field"] || "position").to_s
    result["scope"] = Array(raw["scope"]).map(&:to_s) if raw["scope"]
    result
  when nil, false
    nil
  end
end
```

### PositioningApplicator (new)

```ruby
# lib/lcp_ruby/model_factory/positioning_applicator.rb
module LcpRuby
  module ModelFactory
    class PositioningApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.positioned?

        col = @model_definition.positioning_field.to_sym
        scope_columns = @model_definition.positioning_scope.map(&:to_sym)

        if scope_columns.any?
          @model_class.positioned column: col, on: scope_columns
        else
          @model_class.positioned column: col
        end
      end
    end
  end
end
```

### Builder integration

```ruby
# lib/lcp_ruby/model_factory/builder.rb
def build
  model_class = create_model_class
  apply_table_name(model_class)
  apply_enums(model_class)
  apply_validations(model_class)
  apply_transforms(model_class)
  apply_associations(model_class)
  apply_attachments(model_class)
  apply_scopes(model_class)
  apply_callbacks(model_class)
  apply_defaults(model_class)
  apply_computed(model_class)
  apply_positioning(model_class)          # <-- new, after defaults
  apply_external_fields(model_class)
  apply_model_extensions(model_class)
  apply_custom_fields(model_class)
  apply_label_method(model_class)
  validate_external_methods!(model_class)
  model_class
end

def apply_positioning(model_class)
  PositioningApplicator.new(model_class, model_definition).apply!
end
```

### SchemaManager changes

When a model has `positioning`, the `SchemaManager` must:

1. Set `null: false` on the position column (the `positioning` gem requires this)
2. Backfill any existing NULL values to 0 before applying the NOT NULL constraint
3. Add a unique index on `[scope_columns..., position_column]` — **except on SQLite**

```ruby
# In create_table! or update_table!
def apply_positioning_constraints!(table)
  connection = ActiveRecord::Base.connection
  col = model_definition.positioning_field

  # Ensure NOT NULL on position column (for existing tables where the column may be nullable)
  if connection.column_exists?(table, col)
    column = connection.columns(table).find { |c| c.name == col }
    if column&.null
      connection.execute(
        "UPDATE #{connection.quote_table_name(table)} SET #{connection.quote_column_name(col)} = 0 " \
        "WHERE #{connection.quote_column_name(col)} IS NULL"
      )
      connection.change_column_null(table, col, false)
    end
  end

  add_positioning_index!(table, connection) unless sqlite?(connection)
end

def add_positioning_index!(table, connection)
  col = model_definition.positioning_field
  scope_cols = model_definition.positioning_scope
  index_columns = scope_cols + [col]
  index_name = "idx_#{table}_positioning"

  return if connection.index_exists?(table, index_columns, unique: true)

  begin
    connection.add_index(table, index_columns, unique: true, name: index_name)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
    model_class_name = "LcpRuby::Dynamic::#{model_definition.name.classify}"
    heal_method = "heal_#{col}_column!"
    Rails.logger.warn(
      "[LcpRuby] Could not create unique positioning index on #{table} " \
      "(#{index_columns.join(', ')}): #{e.message}. " \
      "Run `#{model_class_name}.#{heal_method}` in the Rails console to fix existing data, then restart."
    )
  end
end
```

**Unique index and SQLite:** The `positioning` gem uses negative intermediate positions during reorder (never actual duplicates), so the unique constraint is safe as long as concurrent transactions are serialized via `SELECT ... FOR UPDATE`. PostgreSQL and MySQL support row-level locking — the unique index is added and provides a data integrity guarantee. SQLite does not support `FOR UPDATE`, so concurrent reorders could collide on the temporary position 0 — the index is skipped on SQLite.

**Existing data with duplicates:** When adding `positioning` to a model that already has rows with duplicate position values, the unique index creation may fail. The `SchemaManager` catches this error and logs a warning with remediation steps instead of crashing boot.

### Model JSON schema update

```json
{
  "properties": {
    "positioning": {
      "oneOf": [
        { "type": "boolean", "const": true },
        {
          "type": "object",
          "properties": {
            "field": { "type": "string" },
            "scope": {
              "oneOf": [
                { "type": "string" },
                { "type": "array", "items": { "type": "string" } }
              ]
            }
          },
          "additionalProperties": false
        }
      ]
    }
  }
}
```

### Presenter JSON schema update

Add `reorderable` to `index_config`:

```json
{
  "index_config": {
    "properties": {
      "reorderable": { "type": "boolean" }
    }
  }
}
```

### ConfigurationValidator

Boot-time validations:

1. **Position field exists:** If model has `positioning`, verify `positioning.field` (default `position`) is a declared field of type `integer`
2. **Scope fields exist:** Each field in `positioning.scope` must be a declared field or a belongs_to FK
3. **Presenter cross-check:** If presenter has `index.reorderable: true`, verify its model has `positioning` config
4. **Position field in form (warning):** If a positioned field appears in a presenter form section, emit a warning — the position is managed via drag-and-drop; manual editing in a form may cause confusing behavior

```ruby
def validate_positioning(model)
  config = model.positioning
  return unless config

  field_name = config["field"] || "position"
  field_def = model.field(field_name)

  unless field_def
    @errors << "Model '#{model.name}': positioning field '#{field_name}' is not defined"
    return
  end

  unless field_def.type == "integer"
    @errors << "Model '#{model.name}': positioning field '#{field_name}' must be type 'integer', got '#{field_def.type}'"
  end

  Array(config["scope"]).each do |scope_col|
    scope_field = model.field(scope_col)
    scope_fk = model.associations.any? { |a| a.foreign_key == scope_col }
    unless scope_field || scope_fk
      @errors << "Model '#{model.name}': positioning scope '#{scope_col}' is not a defined field or FK"
    end
  end
end

def validate_presenter_reorderable(presenter, model)
  return unless presenter.index_config["reorderable"]
  unless model.positioned?
    @errors << "Presenter '#{presenter.name}': index.reorderable is true but model '#{model.name}' has no positioning config"
  end
end

def validate_positioning_field_not_in_form(presenter, model)
  return unless model.positioned?
  pos_field = model.positioning_field

  presenter.form_sections.each do |section|
    next unless section["fields"]
    if section["fields"].any? { |f| f["field"] == pos_field }
      @warnings << "Presenter '#{presenter.name}': positioning field '#{pos_field}' appears in a form section. " \
                   "The position is managed automatically via drag-and-drop; editing it manually in a form may cause " \
                   "confusing behavior. Consider removing it from the form."
    end
  end
end
```

### Permission integration

Reorder requires **two** permission checks:

1. **CRUD level:** The user must have `update` permission on the model (`authorize @record, :update?`)
2. **Field level:** The positioning field (e.g., `position`) must be in the user's `writable` fields list (`current_evaluator.field_writable?("position")`)

This handles the case where a user can edit a record's name or description but should not be allowed to change its ordering. No new permission type is needed — the existing field-level write permissions are sufficient.

**Controller:**

```ruby
def reorder
  return head(:not_found) unless current_model_definition.positioned?

  set_record
  authorize @record, :update?
  authorize_position_field!   # raises Pundit::NotAuthorizedError if field not writable
  verify_list_version!        # returns 409 Conflict if list changed since page load
  # ...
end
```

**View** — drag handles are rendered only when both checks pass:

```erb
<% reorderable = current_presenter.index_config["reorderable"] &&
                 current_model_definition.positioned? &&
                 current_evaluator.can?(:update) &&
                 current_evaluator.field_writable?(current_model_definition.positioning_field) %>
```

**Permission YAML example:**

```yaml
roles:
  manager:
    crud: [index, show, create, update, destroy]
    fields:
      writable: [name, description, position]    # can reorder

  editor:
    crud: [index, show, update]
    fields:
      writable: [name, description]              # can edit but NOT reorder

  viewer:
    crud: [index, show]
    fields:
      readable: all                              # no drag handles (no update permission)
```

## Examples

### Simple ordered list

```yaml
# models/priority.yml
name: priority
fields:
  - name: name
    type: string
  - name: position
    type: integer

positioning: true
```

```yaml
# presenters/priorities.yml
name: priorities
model: priority
slug: priorities

index:
  reorderable: true
  table_columns:
    - field: name
      link_to: show
```

### Scoped positioning

```yaml
# models/stage.yml
name: stage
fields:
  - name: name
    type: string
  - name: position
    type: integer
  - name: pipeline_id
    type: integer

associations:
  - type: belongs_to
    name: pipeline
    target_model: pipeline

positioning:
  scope: pipeline_id
```

### DSL equivalent

```ruby
define_model :stage do
  field :name, :string
  field :position, :integer

  belongs_to :pipeline, model: :pipeline

  positioning scope: :pipeline_id
end

define_presenter :stages do
  model :stage
  slug "stages"

  index do
    reorderable true
    column :name, link_to: :show
  end
end
```

## Interaction with existing features

### Default sort

When `index.reorderable: true` and no explicit `default_sort` is set, the engine auto-applies `default_sort: { field: <position_field>, direction: asc }`. An explicit `default_sort` overrides this.

This is implemented at runtime in `apply_sort` (ApplicationController) as a fallback, not by mutating the presenter config at boot time. This keeps the stored config clean and avoids surprises when debugging.

### Pagination

Drag-and-drop reordering works **within the current page**. Moving a record from page 2 to page 1 is not supported in this initial implementation. For models with many records, consider setting a high `per_page` or filtering by scope.

The frontend always uses relative positioning (`{ after: id }` or `{ before: id }`) rather than absolute position numbers. This ensures correct behavior on any page — the gem resolves the target record's actual position regardless of which page the user is viewing.

### User-initiated column sort

When a user clicks a column header to sort by a different field, the table displays records in that column's order. Drag handles remain visible but are **disabled** (greyed out, no drag events) because reordering only makes sense when viewing records in position order. Returning to position-based sort (click position column or clear sort) re-enables drag-and-drop.

### Nested fields

Unchanged. The existing `nested_forms.js` drag-and-drop continues to work independently. Nested fields use client-side position management; top-level records use server-side positioning via the gem.

### Scope change via normal edit

When a user edits a record and changes a scope field (e.g., moves a stage to a different pipeline by changing `pipeline_id`), the `positioning` gem automatically:

1. Closes the gap in the old scope (reorders remaining records)
2. Appends the record at the end of the new scope

This is correct behavior but happens invisibly — the user won't see a position change notification. No code change is needed; this is inherent to the gem. Worth noting in user-facing documentation that changing a scope field resets the record's position to the end of the new group.

### Predefined filters / search

Drag handle behavior depends on the type of active filter:

- **Search query active** (`params[:q]` present): drag handles are **disabled**. Reordering a text-search subset would produce unexpected results.
- **Predefined filter matching the positioning scope**: drag handles remain **enabled**. For example, if a model has `positioning: { scope: pipeline_id }` and the index is filtered to `pipeline_id = 5`, the visible records are exactly one positioning scope — reordering within that filter is safe and expected.
- **Predefined filter not matching the positioning scope** (e.g., filtering by `status` on a model scoped by `pipeline_id`): drag handles are **disabled**. The filtered subset crosses scope boundaries, so reordering would be confusing.
- **No filter, no search**: drag handles are **enabled** (default).

The view template passes `data-reorder-disabled="true"` to the table when handles should be disabled. The frontend reads this attribute and greys out drag handles (no drag events fire).

### Bulk create / seeding performance

When creating multiple records in a loop (e.g., seeding or data import), each insert triggers the `positioning` gem's callbacks — the gem acquires a row lock and appends the record at the end of the scope. For small batches (< 100 records per scope) this is fine.

For large bulk imports, consider:

1. **Create records without positioning** (set position to arbitrary values or use `insert_all` to bypass callbacks)
2. **Heal positions after import:** `Model.heal_position_column!` resets positions to consecutive integers in a single pass, respecting scopes
3. **Custom ordering:** `Model.heal_position_column!(order: :name)` applies a specific initial order

This is not an issue for typical platform usage (CRUD forms, seed data). It only matters for large data migrations or imports.

### Concurrent reordering

When two users view the same list and reorder simultaneously, the second user's view is stale. The `positioning` gem uses row-level locking so data stays consistent, but the second user's visual intent may not match the actual result (the `{ after: id }` target may have shifted).

This is solved via a **scope-level list version check**:

1. **On page load:** The server computes a SHA-256 hash of record IDs in position order within the positioning scope. This hash is embedded in the table as `data-list-version`.
2. **On reorder request:** The frontend sends the stored `list_version` alongside the position change.
3. **Server verifies:** Before applying the update, the server recomputes the hash from the current DB state and compares. If it matches, the reorder proceeds. If not, the server returns `409 Conflict` with the current `list_version`.
4. **On success:** The server returns the updated `list_version` in the response. The frontend stores it for the next reorder — no page reload needed for successive reorders by the same user.
5. **On conflict:** The frontend reloads the page, showing a brief flash message ("List was modified by another user, reloading..."). The user sees the current state and can retry their reorder.

**Hash computation:**

```ruby
def compute_list_version(record)
  scope = @model_class.all
  current_model_definition.positioning_scope.each do |col|
    scope = scope.where(col => record.send(col))
  end
  ids_in_order = scope.order(positioning_field => :asc).pluck(:id)
  Digest::SHA256.hexdigest(ids_in_order.join(","))
end
```

For unscoped models, the hash covers all records in the table. For scoped models, only records in the same scope as the record being moved are included.

**Performance:** The hash computation is a single `ORDER BY + pluck` query on an indexed column. For typical positioning use cases (tens to low hundreds of records per scope), this is negligible. For unscoped models with thousands of records, the query is still fast (indexed integer sort + ID pluck), but the SHA-256 input string is larger. This is acceptable — models with thousands of records would typically use scoped positioning anyway.

**Edge case — record created between page load and reorder:** If User A loads the page, then User B creates a new record (appended at end by the gem), User A's `list_version` is stale. User A's next reorder returns 409 and the page reloads showing the new record. This is correct behavior — the user should see the new record before reordering.

## Migration / Compatibility

No migration needed for existing models. This is purely additive:

- Existing models without `positioning` are unaffected
- The `positioning` gem is a new dependency in `lcp_ruby.gemspec`
- No changes to existing YAML files

For models that currently use a plain `position` integer field and want to adopt positioning:

1. Add `positioning: true` (or `positioning: { scope: ... }`) to model YAML
2. Add `reorderable: true` to presenter index config
3. Run a one-time data migration to fill gaps and set NOT NULL using the gem's built-in method:
   ```ruby
   Model.heal_position_column!
   ```
   This resets positions to consecutive integers starting at 1, respecting scopes. It is more efficient and correct than manual iteration (handles scopes, uses bulk SQL).

   For custom initial ordering (e.g., preserve existing sort by name):
   ```ruby
   Model.heal_position_column!(order: :name)
   ```

## Implementation Plan

1. Add `positioning` gem to `lcp_ruby.gemspec`
2. Extend `ModelDefinition` with `positioning_config`, `positioned?`, `positioning_field`, `positioning_scope`
3. Extend model JSON schema with `positioning` key
4. Extend `ModelBuilder` (DSL) with `positioning` method
5. Create `PositioningApplicator`
6. Register in `Builder#build` pipeline
7. Extend `SchemaManager` for NOT NULL + unique index
8. Add `ConfigurationValidator` checks (field exists, type integer, scope valid)
9. Add `reorder` route + controller action (with `list_version` verification)
10. Add `compute_list_version` helpers (controller + view helper)
11. Extend presenter JSON schema with `index.reorderable`
11. Extend `PresenterBuilder` (DSL) with `reorderable` in index block
12. Add `ConfigurationValidator` cross-check (presenter reorderable → model positioned)
13. Update `index.html.erb` — conditional drag handle column + `data-reorder-url`
14. Create `index_sortable.js` — drag-and-drop with PATCH requests
15. Add CSS for drag handle column, disabled state, drop indicator
16. Unit tests: `PositioningApplicator`, `ModelDefinition#positioned?`, validator
17. Integration tests: reorder endpoint, drag handle rendering, permission checks

## Test Plan

1. **ModelDefinition** — `positioned?`, `positioning_field`, `positioning_scope` for all input forms (true, hash, nil)
2. **PositioningApplicator** — `positioned` macro applied with correct column and scope; no-op when positioning absent
3. **SchemaManager** — NOT NULL constraint and unique index created for positioned models; graceful warning when index creation fails on duplicate data
4. **ConfigurationValidator** — error on missing position field, wrong field type, invalid scope, presenter reorderable without model positioning; warning when positioning field appears in a form section
5. **Builder** — full build pipeline with positioning (model has `positioned` behavior after build)
6. **Dynamic model smoke test** — verify that the `positioning` gem's callbacks fire correctly on dynamically-created model classes (in the `LcpRuby::Dynamic` namespace). Create two records and assert positions are `[1, 2]`; destroy the first and assert the remaining record's position is `1` (gap closing works). This catches any issues with the gem's callback registration on runtime-generated classes.
7. **Controller reorder** — position update with relative positioning (`{ after: id }`, `{ before: id }`), gap closing, scope-aware reorder, unauthorized user rejected, returns 200 with `{ position: n, list_version: "..." }`, returns 404 for non-positioned models
8. **List version (concurrent reordering)** — correct `list_version` returned in reorder response; reorder with matching `list_version` succeeds; reorder with stale `list_version` returns 409 with current version; reorder without `list_version` succeeds (param is optional for backwards compatibility); `list_version` changes after a record is created, destroyed, or reordered within the same scope; `list_version` is unaffected by changes in a different scope
9. **Integration** — drag handle rendered for users with update + field write permission; not rendered for read-only roles or roles without position field write access; reorder endpoint returns 200; reorder rejected (403) when field not writable; positions update correctly; `data-list-version` attribute present on table when reorderable
9. **DSL** — `positioning` method produces correct hash; round-trip YAML → DSL → YAML
