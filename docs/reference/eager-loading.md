# Eager Loading Reference

## Overview

The engine automatically resolves N+1 query problems by eager-loading associations based on presenter metadata. When a presenter references associated data (FK columns in index, association lists in show, nested fields in forms), the `IncludesResolver` detects these dependencies and applies the optimal Rails eager loading strategy.

## Auto-Detection Rules

The resolver scans presenter configuration based on the current context:

| Context | Source | Detection Rule | Example |
|---------|--------|----------------|---------|
| `:index` | `table_columns` | FK column matching a `belongs_to` association | `company_id` column detects `:company` |
| `:index` | `table_columns` | Dot-path field referencing an association | `company.name` column detects `:company` |
| `:index` | `table_columns` | Template field with dot-path references | `{company.name}: {title}` detects `:company` |
| `:show` | `layout` | Section with `type: association_list` | `association: contacts` detects `:contacts` |
| `:show` | `layout` | Dot-path field in section fields | `company.name` field detects `:company` |
| `:show` | `layout` | Template field in section fields | `{company.name}` detects `:company` |
| `:form` | `sections` | Section with `type: nested_fields` | `association: todo_items` detects `:todo_items` |

### Dot-Path Detection

Dot-path fields like `company.name` are automatically split into association segments. The first segment is used as the association name for eager loading:

- `company.name` → preloads `:company`
- `company.industry.name` → preloads `{ company: :industry }`
- `contacts.full_name` → preloads `:contacts`

Template fields (e.g., `{company.name}: {title}`) are scanned for all `{ref}` placeholders, and any dot-path references within are collected as dependencies.

## Manual Configuration

Override or supplement auto-detection with explicit `includes` and `eager_load` keys in index, show, or form config:

```yaml
presenter:
  name: deal_admin
  model: deal

  index:
    includes: [company]
    eager_load: [company]
    table_columns:
      - { field: title }
      - { field: company_id }

  show:
    includes: [contacts, deals]
    layout:
      - section: "Details"
        fields:
          - { field: name }
```

- `includes` entries are treated as `:display` dependencies (preload for rendering)
- `eager_load` entries are treated as `:query` dependencies (JOIN for WHERE/ORDER)

### Nested Paths

Both keys accept nested association paths:

```yaml
index:
  includes:
    - company
    - { company: industry }
```

### DSL Syntax

```ruby
define_presenter :deal_admin do
  model :deal

  index do
    includes :company
    eager_load :company
    column :title
    column :company_id
  end

  show do
    includes :contacts, :deals
    section "Details" do
      field :name
    end
  end

  form do
    includes :todo_items
    section "Items" do
      field :title
    end
  end
end
```

## Strategy Resolution

The resolver maps each dependency to the optimal Rails loading method:

| Association Type | Reason | Strategy | Rationale |
|------------------|--------|----------|-----------|
| `belongs_to` / `has_one` | `:display` | `includes` | Preloads via separate query or LEFT JOIN (AR decides) |
| `belongs_to` / `has_one` | `:query` | `eager_load` | Always LEFT JOIN (needed for WHERE/ORDER) |
| `has_many` | `:display` | `includes` | Separate query avoids cartesian product |
| `has_many` | `:query` | `joins` + `includes` | INNER JOIN for query + separate preload (avoids breaking Kaminari pagination) |

When the same association has both `:display` and `:query` reasons, the query strategy takes precedence.

## Association Sorting

Sort fields support dot-notation for sorting by association columns:

```
GET /admin/deals?sort=company.name&direction=asc
```

The `IncludesResolver` automatically adds a `:query` dependency for `company`, and `apply_sort` generates the appropriate ORDER clause using quoted table and column names. Column names are validated against the target model's actual database columns to prevent injection.

## Association Search

Searchable fields in presenter config can include dot-notation paths:

```yaml
search:
  searchable_fields: [title, company.name]
```

Dot-notation fields generate `:query` dependencies that ensure the association table is JOINed for the WHERE clause.

## Error Handling

The eager loading system is designed to fail gracefully. If strategy resolution or association preloading fails (e.g., due to a metadata mismatch or missing association), the engine:

1. Logs a warning via `Rails.logger.warn` with the context and error message
2. Falls back to an empty loading strategy (no eager loading)
3. The page renders normally — associations are loaded lazily instead

This means a misconfigured `includes` or `eager_load` will never crash a page. Check your Rails log for `[LcpRuby] Failed to resolve loading strategy` or `[LcpRuby] Failed to preload associations` warnings.

## `strict_loading` Configuration

Enable `strict_loading` to catch missed N+1 queries during development. When enabled, accessing a lazy-loaded association raises `ActiveRecord::StrictLoadingViolationError`. Applied to index scopes, show records, and edit records after eager loading.

```ruby
LcpRuby.configure do |config|
  config.strict_loading = :development
end
```

| Value | Behavior |
|-------|----------|
| `:never` | Disabled (default) |
| `:development` | Enabled in `development` and `test` environments |
| `:always` | Enabled in all environments |

Note: `:development` enables strict loading in both `development` and `test` Rails environments. This is intentional — catching N+1 queries in tests is valuable.

## FormHelper Optimization

The `render_association_select` helper optimizes queries when the target model has a known `label_method` that maps to a real database column. Instead of loading all records with `SELECT *`, it uses:

```ruby
target_class.select(:id, :name).order(:name)
```

This reduces memory usage and query time for large association select dropdowns.

## Architecture

```
lib/lcp_ruby/presenter/includes_resolver.rb           # Facade: .resolve()
lib/lcp_ruby/presenter/includes_resolver/
  association_dependency.rb   # Value object: { path, reason }
  dependency_collector.rb     # Gathers deps from presenter, sort, search, manual config
  strategy_resolver.rb        # Maps deps -> LoadingStrategy
  loading_strategy.rb         # Applies includes/eager_load/joins to AR scope
```

Source: `lib/lcp_ruby/presenter/includes_resolver.rb`, `app/controllers/lcp_ruby/resources_controller.rb`
