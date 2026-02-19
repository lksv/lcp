# View Groups Guide

View groups let you offer multiple views of the same model (e.g., a detailed admin table and a compact summary table) and control the navigation menu. This guide walks through common scenarios.

For the full attribute reference, see the [View Groups Reference](../reference/view-groups.md).

## Adding Multiple Views for a Model

Suppose you have a `deal` model with two presenters: `deal` (all columns, full editing) and `deal_short` (key columns only, read-only). To let users switch between them:

**Step 1.** Create both presenters in `config/lcp_ruby/presenters/`:

```yaml
# config/lcp_ruby/presenters/deal.yml
presenter:
  name: deal
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
  primary: deal
  navigation:
    menu: main
    position: 3
  views:
    - presenter: deal
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
  primary: todo_list
  navigation:
    menu: main
    position: 1
  views:
    - presenter: todo_list
      label: "Todo Lists"
```

Single-view groups do not render a view switcher -- the `has_switcher?` method returns `false` when there is only one view.

## URL Behavior When Switching Views

When a user clicks a view switcher tab:

- On **index pages**, the URL changes to the target presenter's slug. Query parameters (search, filters, pagination) are preserved.
- On **show pages**, the URL changes to the target presenter's slug with the same record ID (e.g., `/deals/5` to `/deals-short/5`).

Each presenter has its own slug, so each view has a distinct, bookmarkable URL.

## Multiple View Groups for the Same Model

You can define multiple view groups that reference the same model. For example, a CRM might have both a "Deals" group and a "Pipeline" group:

```yaml
# config/lcp_ruby/views/deals.yml
view_group:
  model: deal
  primary: deal
  navigation:
    menu: main
    position: 3
  views:
    - presenter: deal
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

## Breadcrumb Navigation

Breadcrumbs provide hierarchical context: `Home > Companies > Acme Inc > Deals > Big Deal`. They are rendered automatically in the layout and configured per view group.

### Default Breadcrumbs

Without any `breadcrumb` config, every page gets a basic breadcrumb: `Home > {View Label}`. On show pages, the record name is appended. On edit/new pages, the action name is appended.

### Adding a Parent Relation

To show parent context, add a `breadcrumb` key with a `relation` pointing to a `belongs_to` association:

```yaml
# config/lcp_ruby/views/deals.yml
view_group:
  model: deal
  primary: deal
  navigation:
    menu: main
    position: 3
  breadcrumb:
    relation: company
  views:
    - presenter: deal
      label: "Detailed"
      icon: maximize
```

This produces breadcrumbs like:
- Index: `Home > Deals`
- Show: `Home > Companies > Acme Inc > Deals > Big Deal`
- Edit: `Home > Companies > Acme Inc > Deals > Big Deal > Edit`

The engine resolves the parent's view group automatically from the association's target model. If the parent's view group also has a `breadcrumb.relation`, the chain recurses up (limited to 5 levels).

### Nullable FK Handling

If the belongs_to association is optional and the parent record is nil, the parent breadcrumb level is skipped. For example, a deal without a company shows: `Home > Deals > Big Deal`.

### Configuring the Home Link

By default the "Home" crumb links to `"/"`. When the engine is mounted at a sub-path, override it in the initializer:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.breadcrumb_home_path = "/crm"
end
```

See [Engine Configuration — `breadcrumb_home_path`](../reference/engine-configuration.md#breadcrumb_home_path) for details.

### Disabling Breadcrumbs

To hide breadcrumbs for a specific view group:

```yaml
breadcrumb: false
```

### Polymorphic Associations

For polymorphic belongs_to associations, the engine reads `{relation}_type` on the record to determine the parent model and resolves its view group dynamically.

## DSL Alternative

The same configuration in Ruby DSL:

```ruby
# config/lcp_ruby/views/deals.rb
define_view_group :deals do
  model :deal
  primary :deal

  navigation menu: "main", position: 3
  breadcrumb relation: :company

  view :deal, label: "Detailed", icon: :maximize
  view :deal_short,  label: "Short",    icon: :list
end
```

To disable breadcrumbs in DSL:

```ruby
define_view_group :reports do
  model :report
  primary :report
  breadcrumb false
  view :report
end
```
