# Eager Loading Guide

## Quick Start

The engine prevents N+1 queries automatically. When you add a FK column to your index table or an association list to your show page, the engine detects the dependency and eager-loads the associated records.

**Before (N+1 problem):** Without eager loading, displaying a company name for each deal triggers a separate `SELECT` per deal:

```
SELECT * FROM deals ...
SELECT * FROM companies WHERE id = 1  -- for deal 1
SELECT * FROM companies WHERE id = 2  -- for deal 2
SELECT * FROM companies WHERE id = 3  -- for deal 3
... (one per deal)
```

**After (batched):** With the engine's auto-detection, all companies are loaded in one query:

```
SELECT * FROM deals ...
SELECT * FROM companies WHERE id IN (1, 2, 3, ...)
```

## Common Patterns

### Displaying Parent Name in Child Index

Add the FK column to `table_columns`. The engine auto-detects the `belongs_to` association and eager-loads it:

```yaml
# presenters/deal.yml
index:
  table_columns:
    - { field: title, width: "40%" }
    - { field: company_id, width: "20%" }   # Auto-detects belongs_to :company
    - { field: stage, width: "20%" }
```

The index view renders the company's `to_label` (or `label_method` from model config) instead of the raw integer ID.

### Show Page with Association Lists

Add `association_list` sections to the show layout. The engine preloads the associated records:

```yaml
# presenters/company.yml
show:
  layout:
    - section: "Company Information"
      columns: 2
      fields:
        - { field: name, renderer: heading }
        - { field: industry }
    - section: "Contacts"
      type: association_list
      association: contacts      # Auto-preloads :contacts
    - section: "Deals"
      type: association_list
      association: deals         # Auto-preloads :deals
```

### Nested Forms

Nested fields sections automatically preload the child association on edit:

```yaml
form:
  sections:
    - title: "Items"
      type: nested_fields
      association: todo_items    # Auto-preloads :todo_items on edit
      fields:
        - { field: title }
        - { field: completed }
```

### Dot-Path Fields (Association Traversal)

When using dot-notation fields like `company.name` or `contacts.full_name`, the engine automatically detects the association chain and eager-loads all required associations:

```yaml
# presenters/deal.yml
index:
  table_columns:
    - { field: title, width: "40%" }
    - { field: "company.name", width: "20%" }      # Auto-detects belongs_to :company
    - { field: "contact.full_name", width: "20%" }  # Auto-detects belongs_to :contact
```

Deep dot-paths are also supported — `company.industry.name` will preload `{ company: :industry }`.

Template fields with dot-path references also trigger eager loading:

```yaml
table_columns:
  - { field: "{company.name}: {title}" }  # Auto-detects :company
```

### Has-Many Collection Fields

Displaying has_many fields in the index table also triggers eager loading:

```yaml
table_columns:
  - field: "contacts.full_name"           # Auto-detects has_many :contacts
    renderer: collection
    options: { limit: 3 }
```

## Enabling strict_loading for Development

Add to your initializer to catch any remaining lazy loads:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.strict_loading = :development
end
```

This raises `ActiveRecord::StrictLoadingViolationError` whenever a lazy association load occurs on LCP-managed index pages, helping you identify missing eager loads during development.

## Manual Overrides

For edge cases where auto-detection doesn't cover your needs, add explicit includes:

```yaml
index:
  includes: [company, contact]
  table_columns:
    - { field: title }
```

Or in DSL:

```ruby
index do
  includes :company, :contact
  column :title
end
```

Use `eager_load` when you need a LEFT JOIN (e.g., for future sorting/filtering by association columns):

```yaml
index:
  eager_load: [company]
```

## Troubleshooting

### Checking Query Counts

Enable Rails SQL logging to see actual queries:

```ruby
# In Rails console or test
ActiveRecord::Base.logger = Logger.new(STDOUT)
```

Or check the Rails development log (`log/development.log`) for SELECT query counts after loading an index page.

### FK Column Shows ID Instead of Name

If a FK column (e.g., `company_id`) shows the integer ID instead of the company name:

1. Verify the model has a `belongs_to` association with matching `foreign_key`
2. Verify the target model has a `label_method` in its options (or implements `to_label`)
3. Check that the FK field is included in the permission's `readable` fields

### Association Not Preloaded

If you see N+1 queries despite adding a FK column:

1. Check the presenter YAML has the column in `table_columns`
2. Verify the model YAML has the `belongs_to` association defined
3. Check the `foreign_key` in the association matches the column `field` name
