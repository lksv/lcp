# Design: Soft Delete (Discard)

**Status:** Proposed
**Date:** 2026-02-22

## Problem

The platform currently performs hard delete exclusively — `ResourcesController#destroy` calls `@record.destroy!`, permanently removing the record from the database. Many business applications need records to be hidden rather than deleted, for reasons including:

- **Audit compliance** — regulators require data retention
- **Accidental deletion recovery** — users can undo a delete
- **Referential integrity** — other records may reference the deleted record
- **Historical reporting** — archived data remains queryable for analytics

In classical Rails, this is solved by gems like `discard`, `paranoia`, or `acts_as_paranoid`. The platform needs a native, metadata-driven equivalent that integrates with the existing model, presenter, permission, and scope infrastructure.

## Goals

- Add `soft_delete` as a model-level option in YAML and DSL
- Automatically create a timestamp column (`discarded_at` by default, configurable)
- Provide `discard!`, `undiscard!`, `discarded?` methods on the model with discard origin tracking
- Provide `kept`, `discarded`, and `with_discarded` scopes
- Support `dependent: :discard` on associations for automatic cascade discard/undiscard
- Auto-remap the `destroy` controller action to soft delete when enabled — zero changes to permissions, presenter, or routes
- Provide `permanently_destroy` as an optional built-in action for hard delete
- Provide `restore` as a built-in action for undiscarding records
- Filter discarded records from index/show automatically (explicit scope in controller, NOT `default_scope`)
- Integrate with `ConfigurationValidator`, `SchemaManager`, and `Builder` pipeline
- Support the feature in JSON schema validation

## Non-Goals

- Automatic purge of old discarded records (scheduled jobs are out of scope)
- Overriding ActiveRecord's `destroy!` / `destroy` on the model class (too surprising, breaks AR conventions)
- `default_scope` filtering (causes well-documented problems with `unscoped`, associations, and debugging)

## Design

### YAML Configuration

```yaml
# config/lcp_ruby/models/deal.yml
name: deal
soft_delete: true          # simple form — column defaults to discarded_at
fields:
  - name: title
    type: string
```

```yaml
# config/lcp_ruby/models/order.yml
name: order
soft_delete:
  column: deleted_at       # custom column name
fields:
  - name: title
    type: string
```

### DSL Configuration

```ruby
define_model :deal do
  soft_delete true                          # column: discarded_at

  field :title, :string
end

define_model :order do
  soft_delete column: :deleted_at           # custom column name

  field :title, :string
end
```

### What `soft_delete` Enables

When `soft_delete` is set on a model, the platform automatically:

1. **SchemaManager** — adds a nullable `datetime` column (default name: `discarded_at`) with an index
2. **SoftDeleteApplicator** (new) — defines scopes (`kept`, `discarded`, `with_discarded`) and instance methods (`discard!`, `undiscard!`, `discarded?`)
3. **ResourcesController** — the `destroy` action calls `discard!` instead of `destroy!`; index/show scope is filtered to `kept` records
4. **ActionSet** — recognizes `restore` and `permanently_destroy` as new built-in actions
5. **PolicyFactory** — adds `restore?` and `permanently_destroy?` policy methods
6. **PermissionEvaluator** — recognizes `restore` and `permanently_destroy` as valid CRUD entries

No changes are needed to presenter YAML, permission YAML, or routes for the basic case. The existing `destroy` action, button, and permission simply become soft delete.

### Scopes

| Scope | SQL | Purpose |
|-------|-----|---------|
| `kept` | `WHERE discarded_at IS NULL` | Active (non-discarded) records — applied automatically in controller |
| `discarded` | `WHERE discarded_at IS NOT NULL` | Only discarded records — for archive presenters |
| `with_discarded` | No condition on `discarded_at` | All records regardless of status — for admin/reporting |

### Instance Methods

| Method | Behavior |
|--------|----------|
| `discard!(by: nil)` | Sets `discarded_at` to `Time.current` via `update_columns`. When `by:` is provided, sets `discarded_by_type` and `discarded_by_id` to track cascade origin. Cascades to children with `dependent: :discard`. Raises `ActiveRecord::ActiveRecordError` if record is already discarded. |
| `undiscard!` | Cascades undiscard to children that were cascade-discarded by this record (matched by `discarded_by_type`/`discarded_by_id`). Then clears `discarded_at` and tracking columns via `update_columns`. Raises `ActiveRecord::ActiveRecordError` if record is not discarded. |
| `discarded?` | Returns `true` if `discarded_at` is present |
| `kept?` | Returns `true` if `discarded_at` is nil (inverse of `discarded?`) |
| `cascade_discarded?` | Returns `true` if `discarded_by_type` is present (discarded as part of a cascade, not manually) |

Using `update_columns` bypasses validations and callbacks intentionally — discard/undiscard should always succeed regardless of the record's current validation state. If event hooks are needed, the `CallbackApplicator` can fire `after_discard` / `after_undiscard` events (see Events section below).

### Controller Behavior

When `soft_delete` is enabled on the current model:

```ruby
# destroy action — soft delete instead of hard delete
def destroy
  authorize @record
  if current_model_definition.soft_delete?
    @record.discard!
    redirect_to resources_path, notice: "#{current_model_definition.label} was successfully archived."
  else
    @record.destroy!
    redirect_to resources_path, notice: "#{current_model_definition.label} was successfully deleted."
  end
end

# index action — filter to kept records
def index
  authorize @model_class
  scope = policy_scope(@model_class)
  scope = scope.kept if current_model_definition.soft_delete?
  scope = apply_search(scope)
  scope = apply_sort(scope)
  # ...rest unchanged...
end

# show/edit/update — find only among kept records
def set_record
  scope = @model_class
  scope = scope.kept if current_model_definition.soft_delete?
  @record = scope.find(params[:id])
end
```

### New Built-In Actions

Two new built-in actions are available for soft-deletable models:

#### `restore`

Calls `undiscard!` on a discarded record. Only meaningful in archive-context presenters where `scope: discarded` is set.

```yaml
# presenters/deals_archive.yml
presenter:
  name: deals_archive
  model: deal
  label: "Archived Deals"
  slug: deals-archive
  scope: discarded

  actions:
    single:
      - { name: restore, type: built_in, icon: undo, label: "Restore" }
      - name: permanently_destroy
        type: built_in
        icon: trash
        style: danger
        confirm: true
        confirm_message: "This will permanently delete the record. Are you sure?"
```

#### `permanently_destroy`

Calls `destroy!` (real AR hard delete). Available as a built-in action on soft-deletable models. Typically used only in archive presenters and restricted to admin roles.

### Permission Integration

No permission changes are needed for the basic soft delete case — the existing `destroy` CRUD permission controls soft delete.

For archive presenters, the new actions need to be added to the CRUD list:

```yaml
# permissions/deal.yml
permissions:
  model: deal
  roles:
    admin:
      crud: [index, show, create, update, destroy, restore, permanently_destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all

    sales_rep:
      crud: [index, show, create, update, destroy]
      # No restore or permanently_destroy — can soft-delete but cannot recover or hard-delete
```

### Presenter Scope for Archive Views

Presenters can specify a base scope to show only discarded records:

```yaml
presenter:
  name: deals_archive
  model: deal
  scope: discarded            # applies model scope before rendering
```

The `scope` key references a named scope on the model. The controller applies it:

```ruby
scope = policy_scope(@model_class)
scope = scope.kept if current_model_definition.soft_delete? && !presenter_scope_overrides_kept?
scope = apply_presenter_scope(scope)
```

When a presenter has `scope: discarded`, the controller skips the automatic `kept` filter and applies `discarded` instead.

### Events

Two new lifecycle event types are supported for soft-deletable models:

```yaml
# config/lcp_ruby/models/deal.yml
events:
  - name: on_deal_archived
    type: after_discard

  - name: on_deal_restored
    type: after_undiscard
```

These events fire after `discard!` and `undiscard!` respectively, dispatched via the existing `Events::Dispatcher`.

### Associations and Cascade Discard

#### `dependent: :discard` — new association option

A new `dependent` value `:discard` is introduced alongside the existing AR values (`:destroy`, `:delete_all`, `:nullify`, `:restrict_with_exception`, `:restrict_with_error`).

When a parent record is discarded, all children with `dependent: :discard` are **recursively soft-deleted**. When the parent is undiscarded, cascade-discarded children are **automatically restored**.

```yaml
# models/deal.yml
name: deal
soft_delete: true
associations:
  - name: comments
    type: has_many
    target_model: comment
    dependent: discard            # cascade soft delete

  - name: activities
    type: has_many
    target_model: activity
    dependent: destroy            # hard delete (unchanged AR behavior)
```

```yaml
# models/comment.yml
name: comment
soft_delete: true                 # required for dependent: :discard
fields:
  - name: body
    type: text
```

#### Behavior comparison

| `dependent` value | On parent `discard!` | On parent `undiscard!` | On parent `destroy!` |
|---|---|---|---|
| `:discard` | Children are soft-deleted (cascade) | Cascade-discarded children are restored | Children are hard-deleted (AR default) |
| `:destroy` | **No effect** on children | N/A | Children are hard-deleted (AR default) |
| `:nullify` | **No effect** on children | N/A | FK set to NULL (AR default) |
| `:restrict_with_exception` | **No effect** on children | N/A | Raises if children exist (AR default) |

`dependent: :discard` only triggers on `discard!`/`undiscard!`. It does not interfere with AR's `destroy!` — hard delete still cascades via standard AR `dependent` behavior.

#### The Undiscard Problem

Cascade discard creates an ambiguity during undiscard. Consider:

1. Deal has 5 comments
2. User manually discards comment #3 (intentional deletion)
3. User discards Deal → comments #1, #2, #4, #5 are cascade-discarded
4. User restores Deal — **which comments should be restored?**

Without tracking, there are only bad options: restore all (including #3 which was intentionally deleted) or restore none (losing 4 comments the user didn't intend to delete).

#### Discard Origin Tracking

To solve the undiscard problem, models with `soft_delete: true` always get two additional tracking columns:

| Column | Type | Purpose |
|--------|------|---------|
| `discarded_by_type` | `string`, nullable | Polymorphic type of the record that caused the cascade (e.g., `"LcpRuby::Dynamic::Deal"`) |
| `discarded_by_id` | `bigint`, nullable | ID of the record that caused the cascade |

These columns are `NULL` when the record was discarded manually (by user action), and populated when the record was discarded as part of a cascade.

**On cascade discard:**

```ruby
# SoftDeleteApplicator generates this logic:
def discard!(by: nil)
  raise ActiveRecord::ActiveRecordError, "Record is already discarded" if discarded?

  attrs = { discarded_at_column => Time.current }
  if by
    attrs[:discarded_by_type] = by.class.name
    attrs[:discarded_by_id] = by.id
  end
  update_columns(attrs)

  cascade_discard!    # discard children with dependent: :discard
  # ... event dispatch ...
end
```

**On cascade undiscard:**

```ruby
def undiscard!
  raise ActiveRecord::ActiveRecordError, "Record is not discarded" if kept?

  cascade_undiscard!  # restore children that were cascade-discarded BY THIS record
  update_columns(discarded_at_column => nil, discarded_by_type: nil, discarded_by_id: nil)
  # ... event dispatch ...
end
```

**Cascade undiscard logic:**

```ruby
def cascade_undiscard!
  self.class.reflect_on_all_associations(:has_many).each do |assoc|
    next unless assoc.options[:dependent] == :discard

    # Only restore children that were cascade-discarded by THIS record
    send(assoc.name)
      .discarded
      .where(discarded_by_type: self.class.name, discarded_by_id: id)
      .find_each(&:undiscard!)
  end
end
```

This correctly handles the ambiguity:
- Comment #3 (manually discarded): `discarded_by_type = NULL` → **not restored** when Deal is undiscarded
- Comments #1, #2, #4, #5 (cascade-discarded): `discarded_by_type = "Deal", discarded_by_id = 42` → **restored** when Deal is undiscarded

Multi-level cascade works recursively: Deal → Comment → Reply. When Deal is undiscarded, Comments with `discarded_by = Deal#42` are undiscarded, which in turn undiscards Replies with `discarded_by = Comment#X`.

#### Boot-Time Validation

The `ConfigurationValidator` validates `dependent: :discard` at boot time:

**Rule 1: Target model must have `soft_delete: true`.**

When an association declares `dependent: :discard`, the target model must have `soft_delete` enabled — otherwise `discard!` would fail at runtime (method doesn't exist).

```
# ERROR — hard failure, prevents boot
Model 'deal', association 'comments': dependent: :discard requires target model
'comment' to have soft_delete enabled
```

This is always an **error**, not a warning, because it would crash at runtime.

**Rule 2: Polymorphic associations.**

For polymorphic `has_many` (e.g., `has_many :comments, as: :commentable`), the validation checks the declared `target_model`:

```yaml
# models/post.yml
associations:
  - name: comments
    type: has_many
    target_model: comment
    as: commentable
    dependent: discard      # validator checks: does 'comment' have soft_delete?
```

The platform always knows the `target_model` even for polymorphic associations — it's declared in the YAML. So validation works the same way as for non-polymorphic associations.

The interesting case is when **multiple parents** reference the same polymorphic child with **different strategies**:

```yaml
# models/post.yml — soft-deletable parent
soft_delete: true
associations:
  - name: comments
    type: has_many
    target_model: comment
    as: commentable
    dependent: discard          # cascade soft delete

# models/article.yml — non-soft-deletable parent
associations:
  - name: comments
    type: has_many
    target_model: comment
    as: commentable
    dependent: destroy          # hard delete
```

This is **valid and correct**: `comment` has `soft_delete: true` (required by post's `dependent: :discard`), and when an Article is hard-deleted, its comments are hard-deleted too (standard AR `dependent: :destroy`). Different parents can use different strategies for the same child model — there is no conflict.

#### `dependent: :destroy` on soft-deletable models

When a model has `soft_delete: true` and a parent uses `dependent: :destroy`, the platform does **not** intercept this — AR's `destroy!` performs a real hard delete. This is the configurator's explicit choice and the platform respects it.

#### Associations without `dependent`

When a parent is discarded and a `has_many` association has **no** `dependent` option (or `dependent: :nullify` etc.), child records are not affected. The children remain in the database with their FK pointing to the (now-discarded) parent. This is the default behavior — cascade must be explicitly opted into via `dependent: :discard`.

## Implementation

### 1. `Metadata::ModelDefinition`

**File:** `lib/lcp_ruby/metadata/model_definition.rb`

Add soft delete accessor methods:

```ruby
def soft_delete?
  !!soft_delete_config
end

def soft_delete_column
  case options["soft_delete"]
  when true then "discarded_at"
  when Hash then options["soft_delete"]["column"] || "discarded_at"
  else nil
  end
end

private

def soft_delete_config
  sd = options["soft_delete"]
  sd == true || sd.is_a?(Hash) ? sd : nil
end
```

### 2. `ModelFactory::SchemaManager`

**File:** `lib/lcp_ruby/model_factory/schema_manager.rb`

#### In `create_table!` — after timestamps block (line 54):

```ruby
if model_definition.soft_delete?
  col = model_definition.soft_delete_column
  t.datetime col, null: true
  t.index col

  # Tracking columns for cascade undiscard
  t.string :discarded_by_type, null: true
  t.bigint :discarded_by_id, null: true
  t.index [:discarded_by_type, :discarded_by_id]
end
```

#### In `update_table!` — after timestamps block (line 121):

```ruby
if model_definition.soft_delete?
  col = model_definition.soft_delete_column
  unless existing_columns.include?(col)
    connection.add_column(table, col, :datetime, null: true)
    connection.add_index(table, col) unless connection.index_exists?(table, col)
  end

  # Tracking columns for cascade undiscard
  %w[discarded_by_type discarded_by_id].each do |tracking_col|
    unless existing_columns.include?(tracking_col)
      col_type = tracking_col == "discarded_by_id" ? :bigint : :string
      connection.add_column(table, tracking_col, col_type, null: true)
    end
  end
  unless connection.index_exists?(table, [:discarded_by_type, :discarded_by_id])
    connection.add_index(table, [:discarded_by_type, :discarded_by_id])
  end
end
```

### 3. `ModelFactory::SoftDeleteApplicator` (new)

**File:** `lib/lcp_ruby/model_factory/soft_delete_applicator.rb`

```ruby
module LcpRuby
  module ModelFactory
    class SoftDeleteApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.soft_delete?

        column = @model_definition.soft_delete_column
        apply_scopes(column)
        apply_instance_methods(column)
      end

      private

      def apply_scopes(column)
        col = column # capture for closure
        @model_class.scope :kept, -> { where(col => nil) }
        @model_class.scope :discarded, -> { where.not(col => nil) }
        @model_class.scope :with_discarded, -> { unscope(where: col) }
      end

      def apply_instance_methods(column)
        col = column # capture for closure
        model_def = @model_definition

        @model_class.define_method(:discard!) do |by: nil|
          raise ActiveRecord::ActiveRecordError, "Record is already discarded" if send(col).present?

          attrs = { col => Time.current }
          if by
            attrs[:discarded_by_type] = by.class.name
            attrs[:discarded_by_id] = by.id
          end
          update_columns(attrs)

          # Cascade discard to children with dependent: :discard
          model_def.associations
            .select { |a| a.type == "has_many" && a.dependent == "discard" }
            .each do |assoc|
              send(assoc.name).kept.find_each { |child| child.discard!(by: self) }
            end

          LcpRuby::Events::Dispatcher.dispatch(
            event_name: :after_discard,
            record: self,
            changes: { col => [nil, send(col)] }
          )
        end

        @model_class.define_method(:undiscard!) do
          raise ActiveRecord::ActiveRecordError, "Record is not discarded" if send(col).nil?

          old_value = send(col)

          # Cascade undiscard — only children that were cascade-discarded BY THIS record
          model_def.associations
            .select { |a| a.type == "has_many" && a.dependent == "discard" }
            .each do |assoc|
              send(assoc.name)
                .discarded
                .where(discarded_by_type: self.class.name, discarded_by_id: id)
                .find_each(&:undiscard!)
            end

          update_columns(col => nil, discarded_by_type: nil, discarded_by_id: nil)

          LcpRuby::Events::Dispatcher.dispatch(
            event_name: :after_undiscard,
            record: self,
            changes: { col => [old_value, nil] }
          )
        end

        @model_class.define_method(:discarded?) do
          send(col).present?
        end

        @model_class.define_method(:kept?) do
          send(col).nil?
        end

        @model_class.define_method(:cascade_discarded?) do
          discarded_by_type.present?
        end
      end
    end
  end
end
```

### 4. `ModelFactory::Builder`

**File:** `lib/lcp_ruby/model_factory/builder.rb`

Add `apply_soft_delete` to the pipeline after `apply_scopes` (line 18):

```ruby
def build
  model_class = create_model_class
  apply_table_name(model_class)
  apply_enums(model_class)
  apply_validations(model_class)
  apply_transforms(model_class)
  apply_associations(model_class)
  apply_attachments(model_class)
  apply_scopes(model_class)
  apply_soft_delete(model_class)          # <-- new, after scopes
  apply_callbacks(model_class)
  apply_defaults(model_class)
  apply_computed(model_class)
  apply_external_fields(model_class)
  apply_model_extensions(model_class)
  apply_custom_fields(model_class)
  apply_label_method(model_class)
  validate_external_methods!(model_class)
  model_class
end

def apply_soft_delete(model_class)
  SoftDeleteApplicator.new(model_class, model_definition).apply!
end
```

### 5. `ResourcesController`

**File:** `app/controllers/lcp_ruby/resources_controller.rb`

#### `destroy` action (line 81):

```ruby
def destroy
  authorize @record
  if current_model_definition.soft_delete?
    @record.discard!
    redirect_to resources_path, notice: "#{current_model_definition.label} was successfully archived."
  else
    @record.destroy!
    redirect_to resources_path, notice: "#{current_model_definition.label} was successfully deleted."
  end
end
```

#### New `restore` action:

```ruby
def restore
  set_record_with_discarded
  authorize @record
  @record.undiscard!
  redirect_to resources_path, notice: "#{current_model_definition.label} was successfully restored."
end
```

#### New `permanently_destroy` action:

```ruby
def permanently_destroy
  set_record_with_discarded
  authorize @record
  @record.destroy!
  redirect_to resources_path, notice: "#{current_model_definition.label} was permanently deleted."
end
```

#### `set_record` — filter to kept records (line 185):

```ruby
def set_record
  scope = @model_class
  scope = scope.kept if current_model_definition.soft_delete?
  @record = scope.find(params[:id])
end

def set_record_with_discarded
  @record = @model_class.find(params[:id])
end
```

#### `index` — apply kept scope (line 9):

```ruby
def index
  authorize @model_class
  scope = policy_scope(@model_class)
  scope = apply_soft_delete_scope(scope)
  scope = apply_search(scope)
  scope = apply_sort(scope)
  # ...rest unchanged...
end

def apply_soft_delete_scope(scope)
  return scope unless current_model_definition.soft_delete?

  presenter_scope = current_presenter.scope
  if presenter_scope == "discarded"
    scope.discarded
  elsif presenter_scope == "with_discarded"
    scope.with_discarded
  else
    scope.kept
  end
end
```

### 6. Routes

**File:** `config/routes.rb` (engine routes)

Add member routes for restore and permanently_destroy:

```ruby
LcpRuby::Engine.routes.draw do
  scope "/:lcp_slug" do
    # ...existing routes...
    member do
      post :restore
      delete :permanently_destroy
    end
  end
end
```

These routes only respond when the model has `soft_delete` enabled; otherwise the controller returns 404.

### 7. `Authorization::PolicyFactory`

**File:** `lib/lcp_ruby/authorization/policy_factory.rb`

Add policy methods for the new actions (after line 37):

```ruby
define_method(:restore?) { @evaluator.can_for_record?(:restore, record) }
define_method(:permanently_destroy?) { @evaluator.can_for_record?(:permanently_destroy, record) }
```

### 8. `Presenter::ActionSet`

**File:** `lib/lcp_ruby/presenter/action_set.rb`

The existing `filter_actions` method (line 31) already checks `permission_evaluator.can?(action["name"])` for built-in actions. Since `restore` and `permanently_destroy` are new built-in action names, they work automatically once the policy methods exist.

No changes needed in `ActionSet` — just ensure the action names are recognized as built-in.

### 9. `Presenter::PresenterDefinition`

**File:** `lib/lcp_ruby/metadata/presenter_definition.rb`

Add `scope` accessor if not already present:

```ruby
def scope
  raw_hash&.dig("presenter", "scope")
end
```

### 10. `CallbackApplicator`

**File:** `lib/lcp_ruby/model_factory/callback_applicator.rb`

Recognize `after_discard` and `after_undiscard` as valid event types. Event dispatch is handled directly in `SoftDeleteApplicator`'s `discard!` and `undiscard!` methods (see section 3 above). The `CallbackApplicator` only needs to accept these event type names in its validation logic so that YAML event definitions with `type: after_discard` are not rejected.

### 11. `Metadata::ConfigurationValidator`

**File:** `lib/lcp_ruby/metadata/configuration_validator.rb`

Add validation for `soft_delete` option and `dependent: :discard` associations:

```ruby
def validate_soft_delete(model)
  sd = model.options["soft_delete"]
  return unless sd

  unless sd == true || sd.is_a?(Hash)
    @errors << "Model '#{model.name}': soft_delete must be true or a Hash " \
               "with optional 'column' key, got #{sd.class}"
    return
  end

  if sd.is_a?(Hash)
    allowed_keys = %w[column]
    unknown = sd.keys - allowed_keys
    if unknown.any?
      @errors << "Model '#{model.name}': soft_delete has unknown keys: #{unknown.join(', ')}. " \
                 "Allowed keys: #{allowed_keys.join(', ')}"
    end

    if sd["column"].present? && !sd["column"].is_a?(String)
      @errors << "Model '#{model.name}': soft_delete.column must be a string"
    end
  end
end

def validate_dependent_discard(model)
  model.associations.each do |assoc|
    next unless assoc.dependent == "discard"

    # dependent: :discard only makes sense on has_many / has_one
    unless %w[has_many has_one].include?(assoc.type)
      @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                 "dependent: :discard is only valid on has_many and has_one associations"
      next
    end

    # The target model must have soft_delete enabled
    target = @loader.model_definition(assoc.target_model) rescue nil
    unless target
      @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                 "dependent: :discard references unknown target model '#{assoc.target_model}'"
      next
    end

    unless target.soft_delete?
      @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                 "dependent: :discard requires target model '#{assoc.target_model}' " \
                 "to have soft_delete enabled"
    end

    # The parent model should also have soft_delete enabled (warning, not error)
    # — otherwise discard! is never called on the parent and dependent: :discard
    # has no effect
    unless model.soft_delete?
      @warnings << "Model '#{model.name}', association '#{assoc.name}': " \
                   "dependent: :discard has no effect because model '#{model.name}' " \
                   "does not have soft_delete enabled (discard! is never called on it)"
    end
  end
end
```

**Validation severity:**
- **Error** (prevents boot): target model missing `soft_delete: true` — calling `discard!` would crash at runtime
- **Warning** (boot continues): parent model missing `soft_delete: true` — `dependent: :discard` is technically valid but has no effect since the controller never calls `discard!` on it

### 12. `ModelFactory::AssociationApplicator`

**File:** `lib/lcp_ruby/model_factory/association_applicator.rb`

The `dependent: :discard` value must **not** be passed to ActiveRecord's `has_many` / `has_one` macros — AR does not recognize it. The applicator filters it out:

```ruby
def apply_has_many(assoc)
  opts = base_options(assoc)
  # ...existing options...

  # dependent: :discard is handled by SoftDeleteApplicator, not AR
  if assoc.dependent && assoc.dependent != "discard"
    opts[:dependent] = assoc.dependent.to_sym
  end

  @model_class.has_many assoc.name.to_sym, **opts
end
```

The same applies to `apply_has_one`. The cascade logic lives entirely in `SoftDeleteApplicator`'s `discard!` and `undiscard!` methods, which iterate `model_definition.associations` at runtime.

### 13. JSON Schema

**File:** `lib/lcp_ruby/schemas/model.json`

Add `soft_delete` to the model options schema:

```json
"soft_delete": {
  "oneOf": [
    { "type": "boolean", "const": true },
    {
      "type": "object",
      "properties": {
        "column": {
          "type": "string",
          "description": "Column name for the discard timestamp. Default: discarded_at"
        }
      },
      "additionalProperties": false
    }
  ]
}
```

### 13. `Dsl::ModelBuilder`

**File:** `lib/lcp_ruby/dsl/model_builder.rb`

Add `soft_delete` DSL method:

```ruby
def soft_delete(value = true, column: nil)
  if column
    @model_hash["options"]["soft_delete"] = { "column" => column.to_s }
  else
    @model_hash["options"]["soft_delete"] = value
  end
end
```

## Components Requiring No Changes

| Component | Why it works |
|---|---|
| **PermissionEvaluator** | `can?(:destroy)` already works for soft delete. `can?(:restore)` and `can?(:permanently_destroy)` work because `can?` checks the CRUD list directly. |
| **ScopeBuilder** | Permission scopes apply on top of the `kept`/`discarded` scope — no interaction. |
| **FieldValueResolver** | Calls `record.send(field_name)` — `discarded_at` is a regular column. |
| **LayoutBuilder** | No awareness of soft delete needed — form/show sections are model-driven. |
| **TransformApplicator** | Does not interact with `discarded_at` — it's not a user-editable field. |
| **Display::Renderers** | `discarded_at` can be rendered with the existing `relative_date` renderer if shown in archive views. |
| **CustomFields** | Independent of soft delete — custom fields work on both kept and discarded records. |

## File Changes Summary

| File | Change |
|------|--------|
| `lib/lcp_ruby/metadata/model_definition.rb` | Add `soft_delete?`, `soft_delete_column` methods |
| `lib/lcp_ruby/model_factory/soft_delete_applicator.rb` | **New** — scopes, instance methods, cascade discard/undiscard, event dispatch |
| `lib/lcp_ruby/model_factory/builder.rb` | Add `apply_soft_delete` to pipeline |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | Add `discarded_at` + tracking columns in `create_table!` and `update_table!` |
| `lib/lcp_ruby/model_factory/association_applicator.rb` | Filter out `dependent: :discard` before passing to AR macros |
| `app/controllers/lcp_ruby/resources_controller.rb` | Remap `destroy`, add `restore` and `permanently_destroy` actions, `apply_soft_delete_scope` |
| `config/routes.rb` | Add `restore` and `permanently_destroy` member routes |
| `lib/lcp_ruby/authorization/policy_factory.rb` | Add `restore?` and `permanently_destroy?` policy methods |
| `lib/lcp_ruby/metadata/presenter_definition.rb` | Add `scope` accessor |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Validate `soft_delete` model option + `dependent: :discard` associations |
| `lib/lcp_ruby/schemas/model.json` | Add `soft_delete` to model options schema |
| `lib/lcp_ruby/dsl/model_builder.rb` | Add `soft_delete` DSL method |
| `app/views/lcp_ruby/resources/_action_button.html.erb` | Handle `restore` and `permanently_destroy` button rendering |

## Examples

### Basic Soft Delete

```yaml
# models/deal.yml
name: deal
soft_delete: true
fields:
  - name: title
    type: string
    validations:
      - type: presence
  - name: stage
    type: enum
    values:
      lead: Lead
      negotiation: Negotiation
      closed_won: Closed Won
      closed_lost: Closed Lost
options:
  timestamps: true
  label_method: title
```

```yaml
# presenters/deals.yml — no changes needed, destroy button now soft-deletes
presenter:
  name: deals
  model: deal
  label: "Deals"
  slug: deals

  actions:
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

```yaml
# presenters/deals_archive.yml — separate archive view
presenter:
  name: deals_archive
  model: deal
  label: "Archived Deals"
  slug: deals-archive
  scope: discarded

  index:
    default_view: table
    table_columns:
      - { field: title, width: "30%" }
      - { field: stage, width: "20%", renderer: badge }
      - { field: discarded_at, width: "20%", renderer: relative_date, label: "Archived" }

  actions:
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: restore, type: built_in, icon: undo, label: "Restore" }
      - name: permanently_destroy
        type: built_in
        icon: trash
        style: danger
        confirm: true
        confirm_message: "This will permanently delete the record and cannot be undone. Are you sure?"
```

```yaml
# permissions/deal.yml
permissions:
  model: deal
  roles:
    admin:
      crud: [index, show, create, update, destroy, restore, permanently_destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all

    sales_rep:
      crud: [index, show, create, update, destroy]
      fields:
        readable: all
        writable: [title, stage]
      scope: all
      presenters: [deals]          # no access to archive presenter
```

### Custom Column Name

```yaml
# models/order.yml
name: order
soft_delete:
  column: deleted_at
fields:
  - name: number
    type: string
```

### DSL with Events

```ruby
define_model :invoice do
  soft_delete true

  field :number, :string
  field :total, :decimal, precision: 12, scale: 2

  on :after_discard, name: "on_invoice_archived"
  on :after_undiscard, name: "on_invoice_restored"

  timestamps true
end
```

### Cascade Discard via `dependent: :discard`

```yaml
# models/deal.yml
name: deal
soft_delete: true
associations:
  - name: comments
    type: has_many
    target_model: comment
    dependent: discard              # soft delete comments when deal is discarded
  - name: activities
    type: has_many
    target_model: activity
    dependent: destroy              # hard delete activities (different strategy)

# models/comment.yml
name: comment
soft_delete: true                   # required for dependent: :discard
associations:
  - name: replies
    type: has_many
    target_model: reply
    dependent: discard              # multi-level cascade: deal → comment → reply

# models/reply.yml
name: reply
soft_delete: true

# models/activity.yml
name: activity
# no soft_delete — hard-deleted when deal is destroyed
```

**What happens when Deal #42 is discarded:**
1. Deal #42: `discarded_at = now`, `discarded_by_type = NULL` (manual discard)
2. Comment #1: `discarded_at = now`, `discarded_by_type = "Deal"`, `discarded_by_id = 42`
3. Comment #2: `discarded_at = now`, `discarded_by_type = "Deal"`, `discarded_by_id = 42`
4. Reply #10 (on Comment #1): `discarded_at = now`, `discarded_by_type = "Comment"`, `discarded_by_id = 1`
5. Activities: **not affected** (no `dependent: :discard`)

**What happens when Deal #42 is undiscarded:**
1. Reply #10: restored (was cascade-discarded by Comment #1)
2. Comment #1, #2: restored (were cascade-discarded by Deal #42)
3. Deal #42: restored
4. Comment #3 (manually discarded before deal): `discarded_by_type = NULL` → **not restored**

### Polymorphic Cascade Discard

```yaml
# models/post.yml — soft-deletable parent
name: post
soft_delete: true
associations:
  - name: comments
    type: has_many
    target_model: comment
    as: commentable
    dependent: discard

# models/article.yml — non-soft-deletable parent
name: article
associations:
  - name: comments
    type: has_many
    target_model: comment
    as: commentable
    dependent: destroy          # hard delete, different strategy

# models/comment.yml — shared polymorphic child
name: comment
soft_delete: true
associations:
  - name: commentable
    type: belongs_to
    polymorphic: true
```

Both parents can coexist — `comment` has `soft_delete: true` (satisfying post's `dependent: :discard`), and article's `dependent: :destroy` still works via standard AR.

### Cascade Discard via Event Handler (alternative)

For cases where `dependent: :discard` is not appropriate (e.g., custom logic, conditional cascade), event handlers remain a valid alternative:

```ruby
# app/event_handlers/cascade_deal_discard.rb
class CascadeDealDiscard
  def self.handle(event_name:, record:, **)
    return unless event_name.to_s == "on_deal_archived"
    # Custom logic: only discard open activities, close completed ones
    record.activities.kept.where(status: "open").find_each(&:discard!)
  end
end
```

```yaml
events:
  - name: on_deal_archived
    type: after_discard
```

## Migration / Compatibility

- **Additive feature** — models without `soft_delete` are completely unaffected
- **No database migration needed** — columns are created at boot by `SchemaManager`
- **No breaking changes to existing permissions** — `destroy` CRUD permission now means soft delete for soft-deletable models
- **No breaking changes to existing presenters** — the `destroy` action button works as before
- **Pre-production** — no backward compatibility concerns

## Test Plan

### Unit Tests

1. **ModelDefinition** — `soft_delete?`, `soft_delete_column` for `true`, `{ column: "deleted_at" }`, and `false`/absent
2. **SoftDeleteApplicator — basic** — `discard!` sets timestamp, `undiscard!` clears it, `discarded?`/`kept?` predicates, `discard!` on already-discarded raises, `undiscard!` on kept record raises
3. **SoftDeleteApplicator — tracking** — `discard!(by: parent)` sets `discarded_by_type` and `discarded_by_id`; `discard!` without `by:` leaves tracking columns nil; `undiscard!` clears tracking columns; `cascade_discarded?` predicate
4. **SoftDeleteApplicator — scopes** — `kept` returns only non-discarded, `discarded` returns only discarded, `with_discarded` returns all
5. **SoftDeleteApplicator — cascade discard** — parent with `dependent: :discard` child: discarding parent discards children with correct tracking; children already discarded are not re-discarded; multi-level cascade (parent → child → grandchild)
6. **SoftDeleteApplicator — cascade undiscard** — undiscarding parent restores only cascade-discarded children (by tracking match); manually-discarded children are not restored; multi-level cascade undiscard works recursively
7. **SchemaManager** — creates `discarded_at`, `discarded_by_type`, `discarded_by_id` columns with indexes in `create_table!`; adds missing columns in `update_table!`; no columns when `soft_delete` is absent
8. **Builder** — `apply_soft_delete` is called in pipeline; model has scopes and methods when enabled; model has neither when disabled
9. **ConfigurationValidator — soft_delete** — accepts `true`, accepts `{ column: "deleted_at" }`, rejects invalid types, rejects unknown keys
10. **ConfigurationValidator — dependent: :discard** — error when target model lacks `soft_delete`; error on `belongs_to` with `dependent: :discard`; warning when parent model lacks `soft_delete`; accepts valid configuration
11. **AssociationApplicator** — `dependent: :discard` is not passed to AR `has_many` macro (filtered out); other `dependent` values still work
12. **PolicyFactory** — `restore?` and `permanently_destroy?` delegate to evaluator
13. **Event dispatch** — `after_discard` and `after_undiscard` events fire with correct changes hash; events fire after cascade (not before)

### Integration Tests

14. **Destroy soft-deletable record** — `DELETE /deals/:id` sets `discarded_at`, record disappears from index, count decreases by 1, record still in DB
15. **Restore discarded record** — `POST /deals-archive/:id/restore` clears `discarded_at`, record reappears in main index
16. **Permanently destroy** — `DELETE /deals-archive/:id/permanently_destroy` removes record from DB
17. **Show discarded record in archive** — `GET /deals-archive` shows only discarded records
18. **404 on discarded record** — `GET /deals/:id` returns 404 for a discarded record (filtered by `kept` scope)
19. **Permission check** — role without `restore` cannot call restore action; role without `permanently_destroy` cannot hard-delete
20. **Non-soft-deletable model** — `DELETE /lists/:id` still performs hard delete (no regression)
21. **Custom column name** — model with `soft_delete: { column: deleted_at }` uses `deleted_at` column
22. **Cascade discard integration** — discard deal with `dependent: :discard` comments → comments are discarded with tracking; undiscard deal → comments restored; manually-discarded comment not restored
23. **Polymorphic cascade** — soft-deletable parent with polymorphic `dependent: :discard` child → cascade works; non-soft-deletable parent with same child model using `dependent: :destroy` → hard delete works

### Fixture Requirements

- Add `soft_delete: true` to one model in integration fixtures (e.g., `spec/fixtures/integration/crm/models/deal.yml`)
- Add `dependent: :discard` to at least one `has_many` association in fixtures
- Add a child model with `soft_delete: true` as cascade target
- Add archive presenter fixture (`spec/fixtures/integration/crm/presenters/deal_archive.yml`)
- Add `restore` and `permanently_destroy` to admin CRUD in permission fixtures

## Open Questions

1. **Should `discarded_at` be exposed as a readable field automatically?** Currently the column exists but is not in `fields` array, so it won't appear in forms. For archive presenters, the configurator can reference it in `table_columns` directly since AR knows the column. Alternatively, the platform could auto-inject it as a virtual read-only field. Recommendation: do not auto-inject — let the configurator add it to presenter columns explicitly.

2. **Should Ransack search filter discarded records?** The `apply_search` method works on the already-scoped relation, so discarded records are excluded from search results in the main presenter. In archive presenters, search works on the `discarded` scope. This should work correctly without changes, but needs verification.

3. **Should the `discard!` method use `update_columns` or `update!`?** `update_columns` bypasses validations and callbacks, which is desirable (a record with validation errors should still be discardable). However, it also bypasses `updated_at` timestamp update. Recommendation: use `update_columns` — discard is not a content change and should not affect `updated_at`.

4. **Should nested `_destroy` in nested forms trigger soft delete?** When a parent form has nested fields with `allow_destroy: true`, submitting `_destroy: true` currently calls AR `mark_for_destruction` → `destroy`. If the child model is soft-deletable, should this soft-delete instead? Recommendation: defer — this is a complex interaction that needs separate design. For now, nested `_destroy` always hard-deletes.

5. **Performance of deep cascade trees.** `find_each` iterates in batches of 1000, but each `discard!` call is a separate `UPDATE` statement. For large association trees (e.g., deal with 10,000 comments, each with replies), this could be slow. Possible optimization: batch `UPDATE` with `update_all` for cascade discard (set `discarded_at`, `discarded_by_type`, `discarded_by_id` in one query per association), then fire events per-record only if event handlers are registered. Recommendation: start with per-record `discard!` for correctness (events, multi-level cascade), optimize later if needed.

6. **Should `dependent: :restrict_with_exception` prevent discard?** Currently, `restrict_with_exception` only prevents AR `destroy!`. If a parent model has `has_many :orders, dependent: :restrict_with_exception`, discarding the parent would succeed even though hard-deleting would fail. Should the platform also check restrict-style dependents on discard? Recommendation: yes, add a `restrict_with_exception` / `restrict_with_error` check in `discard!` that mirrors AR's behavior — raise/add error if kept children exist on restricted associations.
