# View Groups Guide

View groups let you offer multiple views of the same model (e.g., a detailed admin table and a compact summary table) and control the navigation menu. This guide walks through common scenarios.

For the full attribute reference, see the [View Groups Reference](../reference/view-groups.md).

## Adding Multiple Views for a Model

Suppose you have a `deal` model with two presenters: `deal_admin` (all columns, full editing) and `deal_short` (key columns only, read-only). To let users switch between them:

**Step 1.** Create both presenters in `config/lcp_ruby/presenters/`:

```yaml
# config/lcp_ruby/presenters/deal_admin.yml
presenter:
  name: deal_admin
  model: deal
  label: "Deals"
  slug: deals
  # ... full index/show/form config
```

```yaml
# config/lcp_ruby/presenters/deal_short.yml
presenter:
  name: deal_short
  model: deal
  label: "Deals (Short)"
  slug: deals-short
  read_only: true
  # ... minimal index config
```

**Step 2.** Create a view group in `config/lcp_ruby/views/`:

```yaml
# config/lcp_ruby/views/deals.yml
view_group:
  model: deal
  primary: deal_admin
  navigation:
    menu: main
    position: 3
  views:
    - presenter: deal_admin
      label: "Detailed"
      icon: maximize
    - presenter: deal_short
      label: "Short"
      icon: list
```

The `primary` presenter determines which entry appears in the navigation menu. Users land on the primary presenter's page and can switch to other views using the view switcher tabs.

**Step 3.** The view switcher renders automatically. No template changes needed -- the `_view_switcher` partial appears on index and show pages when the current view group has more than one view.

## Navigation Menu Integration

The `navigable_presenters` helper returns all view groups sorted by position. Use it in your layout to build the navigation menu:

```erb
<nav>
  <% navigable_presenters.each do |entry| %>
    <%= link_to entry[:label],
          lcp_ruby.resources_path(lcp_slug: entry[:slug]),
          class: "nav-link #{entry[:slug] == params[:lcp_slug] ? 'active' : ''}" %>
  <% end %>
</nav>
```

Each entry represents one view group (not one presenter). The label, slug, and icon come from the primary presenter.

## Single-View Groups

When a model has only one presenter, you can either:

**Option A: Let auto-creation handle it.** If you do not define a view group, the engine creates one automatically with `position: 99`. The presenter appears in the navigation menu at the end.

**Option B: Define an explicit view group** to control the position:

```yaml
# config/lcp_ruby/views/todo_lists.yml
view_group:
  model: todo_list
  primary: todo_list_admin
  navigation:
    menu: main
    position: 1
  views:
    - presenter: todo_list_admin
      label: "Todo Lists"
```

Single-view groups do not render a view switcher -- the `has_switcher?` method returns `false` when there is only one view.

## URL Behavior When Switching Views

When a user clicks a view switcher tab:

- On **index pages**, the URL changes to the target presenter's slug. Query parameters (search, filters, pagination) are preserved.
- On **show pages**, the URL changes to the target presenter's slug with the same record ID (e.g., `/admin/deals/5` to `/admin/deals-short/5`).

Each presenter has its own slug, so each view has a distinct, bookmarkable URL.

## Multiple View Groups for the Same Model

You can define multiple view groups that reference the same model. For example, a CRM might have both a "Deals" group and a "Pipeline" group:

```yaml
# config/lcp_ruby/views/deals.yml
view_group:
  model: deal
  primary: deal_admin
  navigation:
    menu: main
    position: 3
  views:
    - presenter: deal_admin
      label: "Detailed"
    - presenter: deal_short
      label: "Short"
```

```yaml
# config/lcp_ruby/views/pipeline.yml
view_group:
  model: deal
  primary: deal_pipeline
  navigation:
    menu: main
    position: 4
  views:
    - presenter: deal_pipeline
      label: "Pipeline"
```

Both appear as separate entries in the navigation menu. A presenter can only belong to one view group.

## DSL Alternative

The same configuration in Ruby DSL:

```ruby
# config/lcp_ruby/views/deals.rb
define_view_group :deals do
  model :deal
  primary :deal_admin

  navigation menu: "main", position: 3

  view :deal_admin, label: "Detailed", icon: :maximize
  view :deal_short,  label: "Short",    icon: :list
end
```
