# Context-Aware View Switcher — Design Document

> **Status:** Implemented
> **Date:** 2026-02-26

## Problem

When a view group contains multiple presenters, the view switcher (toggle buttons) currently appears on both the index and show pages unconditionally. This causes a confusing user experience when sibling presenters share identical configuration for a given page type.

**Example:** `showcase_recipes` has two presenters — "Structured" and "Raw JSON". They differ only in the `show` view (structured vs. code block rendering of JSON data). The `index`, `form`, `search`, and `actions` configs are identical (inherited). On the index page, the switcher shows two buttons that lead to visually identical pages.

The opposite case also exists: two presenters that differ only on the index (e.g., Table View vs. Card View) would show a pointless switcher on the show page if both show configs are identical.

## Goals

- Allow view groups to configure **where** the view switcher appears (index, show, form, or any combination)
- Provide auto-detection as the default — compare presenter configurations and only show the switcher on pages where they actually differ
- Keep the explicit override for cases where auto-detection is not desired
- Zero configuration needed for common cases — auto-detection should just work

## Non-Goals

- Per-user switcher preferences — remembering which view a user last selected
- Conditional switcher based on record data (e.g., show switcher only for records with JSON data)

## Design

### Configuration: `switcher` key on view group

A new optional `switcher` key in the view group definition controls where the switcher appears:

```yaml
# Auto-detection (default — does not need to be specified)
view_group:
  model: showcase_recipe
  primary: showcase_recipes
  views:
    - presenter: showcase_recipes
      label: "Structured"
    - presenter: showcase_recipes_raw
      label: "Raw JSON"

# Explicit context list
view_group:
  model: showcase_recipe
  primary: showcase_recipes
  switcher: [show]
  views: ...

# Always show on all page types (opt out of auto-detection)
view_group:
  model: some_model
  primary: some_presenter
  switcher: [index, show, form]
  views: ...

# Disable switcher entirely (even with multiple views)
view_group:
  model: some_model
  primary: some_presenter
  switcher: false
  views: ...
```

| Value | Behavior |
|-------|----------|
| *(omitted)* or `auto` | Auto-detect: compare presenter configs, show switcher only where they differ |
| `[index]` | Switcher only on index page |
| `[show]` | Switcher only on show page |
| `[form]` | Switcher only on edit/new pages |
| `[index, show]` | Switcher on index and show pages |
| `[index, show, form]` | Switcher on all pages (forces display, skips auto-detection) |
| `false` | No switcher anywhere |

### Auto-detection algorithm

When `switcher` is `auto` (or omitted), the system compares the resolved presenter configurations for each page context:

```ruby
def presenters_differ_on?(context)
  config_method = case context
                  when "index" then :index_config
                  when "show"  then :show_config
                  when "form"  then :form_config
                  end
  return true unless config_method

  configs = presenter_definitions.map(&config_method)
  !configs.all? { |c| c == configs.first }
end
```

**Why hash comparison is reliable:**

- Presenter inheritance resolves at load time via deep clone + merge. The resulting `PresenterDefinition` contains fully resolved configuration as deeply-stringified hashes.
- If a child presenter does not override `index`, it inherits an identical deep clone from the parent. `Hash#==` correctly returns `true`.
- If a child overrides `show`, the hash is structurally different. `Hash#==` correctly returns `false`.
- Edge case: two presenters that independently define identical configs are correctly treated as equal — no switcher shown, which is the right behavior.

**Caching:** The comparison result is cached per context in `@presenter_diff_cache` since configurations do not change at runtime.

### ViewGroupDefinition changes

New attribute and methods:

```ruby
VALID_SWITCHER_CONTEXTS = %w[index show form].freeze

attr_reader :switcher_contexts

def show_switcher?(context)
  return false if views.length < 2
  return false if @switcher == false

  context_s = context.to_s

  case @switcher
  when Array
    @switcher.include?(context_s)
  else
    presenters_differ_on?(context_s)
  end
end

# Backward compatibility — true if switcher could appear on any page
def has_switcher?
  views.length > 1 && @switcher != false
end
```

Parsing:

```ruby
def parse_switcher(value)
  case value
  when nil, "auto" then :auto
  when false        then false
  when Array
    invalid = value.map(&:to_s) - VALID_SWITCHER_CONTEXTS
    raise MetadataError, "..." if invalid.any?
    value.map(&:to_s)
  else
    raise MetadataError, "..."
  end
end
```

### Template changes

The `_view_switcher.html.erb` partial receives a `context` local variable:

```erb
<% if current_view_group&.show_switcher?(local_assigns[:context] || :index) %>
  <div class="lcp-view-switcher">
    ...existing code...
  </div>
<% end %>
```

Callers pass the context:

```erb
<%# index.html.erb %>
<%= render "lcp_ruby/resources/view_switcher", context: :index %>

<%# show.html.erb %>
<%= render "lcp_ruby/resources/view_switcher", context: :show %>

<%# edit.html.erb %>
<%= render "lcp_ruby/resources/view_switcher", context: :form %>

<%# new.html.erb %>
<%= render "lcp_ruby/resources/view_switcher", context: :form %>
```

The form context generates links appropriate to the page: `edit_resource_path` for persisted records, `new_resource_path` for new records.

### JSON Schema

Add `switcher` to `view_group.json`:

```json
"switcher": {
  "description": "Where to show the view switcher. 'auto' for auto-detection (default), array of contexts, or false to disable.",
  "oneOf": [
    { "type": "boolean", "const": false },
    { "type": "string", "const": "auto" },
    {
      "type": "array",
      "items": { "type": "string", "enum": ["index", "show", "form"] },
      "minItems": 1,
      "uniqueItems": true
    }
  ]
}
```

## Examples

### Showcase Recipes (auto-detection)

No `switcher` key needed. The two presenters share identical `index_config` (inherited) but have different `show_config`. Auto-detection result:

- **Index:** configs equal → no switcher
- **Show:** configs differ → switcher displayed
- **Form:** configs equal → no switcher

### Showcase Fields (Table vs. Card — auto-detection)

Both presenters override `index` (different columns) and `show` (different section layouts). Auto-detection result:

- **Index:** configs differ → switcher displayed
- **Show:** configs differ → switcher displayed
- **Form:** configs equal → no switcher

### Hypothetical: same show, different index

Two presenters where only the index differs (compact vs. detailed table). Auto-detection result:

- **Index:** configs differ → switcher displayed
- **Show:** configs equal → no switcher
- **Form:** configs equal → no switcher

### Explicit override

A view group where auto-detection would hide the switcher on index, but the developer wants it visible everywhere for discoverability:

```yaml
view_group:
  model: report
  primary: report_summary
  switcher: [index, show, form]
  views:
    - presenter: report_summary
    - presenter: report_detailed
```

## File Changes

| File | Change |
|------|--------|
| `lib/lcp_ruby/metadata/view_group_definition.rb` | Add `switcher` attribute, `parse_switcher`, `show_switcher?`, `presenters_differ_on?` |
| `lib/lcp_ruby/schemas/view_group.json` | Add `switcher` property |
| `lib/lcp_ruby/dsl/view_group_builder.rb` | Add `switcher` DSL method + `to_hash` serialization |
| `app/views/lcp_ruby/resources/_view_switcher.html.erb` | Use `show_switcher?(context)` instead of `has_switcher?`, handle form context links |
| `app/views/lcp_ruby/resources/index.html.erb` | Pass `context: :index` |
| `app/views/lcp_ruby/resources/show.html.erb` | Pass `context: :show` |
| `app/views/lcp_ruby/resources/edit.html.erb` | Add view switcher with `context: :form` |
| `app/views/lcp_ruby/resources/new.html.erb` | Add view switcher with `context: :form` |
| `spec/lib/lcp_ruby/metadata/view_group_definition_spec.rb` | Unit tests for switcher parsing, auto-detection, explicit modes |
| `spec/lib/lcp_ruby/dsl/view_group_builder_spec.rb` | DSL builder tests + round-trip tests |
| `spec/integration/view_groups_spec.rb` | Integration tests for context-aware switcher |
