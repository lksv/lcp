# View Groups Reference

File: `config/lcp_ruby/views/<name>.yml`

View groups organize one or more presenters for the same model into a navigable unit. They control the navigation menu (which entries appear, in what order) and provide a view switcher when multiple presenters exist for the same model (e.g., "Detailed" vs. "Short" views of deals).

See the [View Groups Guide](../guides/view-groups.md) for practical examples.

## YAML Schema

```yaml
view_group:
  name: <group_name>
  model: <model_name>
  primary: <presenter_name>
  public: false
  navigation:
    menu: main
    position: 3
  breadcrumb:
    relation: <association_name>
  views:
    - presenter: <presenter_name>
      label: "Detailed"
      icon: maximize
    - presenter: <presenter_name>
      label: "Short"
      icon: list
```

## Top-Level Attributes

### `name`

| | |
|---|---|
| **Required** | no |
| **Default** | filename without extension |
| **Type** | string |

Unique identifier for the view group. If omitted, the YAML filename is used (e.g., `deals.yml` becomes `deals`).

### `model`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Name of the [model](models.md) this view group covers. Must match a model's `name` attribute. Multiple view groups can reference the same model (e.g., a "Deals" group and a "Pipeline" group both referencing the `deal` model).

### `primary`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Name of the primary presenter in this group. The primary presenter is used as the representative entry in the navigation menu (its label, slug, and icon are shown). Must be one of the presenters listed in `views`.

### `public`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

When `true`, this view group allows unauthenticated access. Requests to presenters in a public view group bypass the `authenticate_user!` check — an anonymous user object with empty roles is used instead. This is useful for public-facing pages like landing pages or public directories.

```yaml
view_group:
  name: public_catalog
  model: product
  primary: product_catalog
  public: true
  navigation: false
  views:
    - presenter: product_catalog
```

### `navigation`

Controls the position of this view group in the navigation menu, or disables navigation entirely.

**As a hash** (default):

| Attribute | Type | Description |
|-----------|------|-------------|
| `menu` | string | Menu group name (e.g., `main`) |
| `position` | integer | Sort order within the menu. Lower numbers appear first |

**As `false`**:

```yaml
navigation: false
```

Setting `navigation: false` excludes this view group from auto-generated navigation and from auto-append in `:auto` menu mode. The view group still works for routing and view switching — it just does not appear in any menu.

Use this for view groups that should be accessible via direct URL but not shown in navigation (e.g., audit logs, embedded views, detail pages linked from other pages).

The `navigable?` method on `ViewGroupDefinition` returns `false` when `navigation` is set to `false`.

See [Menu Reference](menu.md) for details on the configurable menu system.

### `breadcrumb`

| | |
|---|---|
| **Required** | no |
| **Default** | `nil` (default breadcrumb: `Home > Current View`) |
| **Type** | `Hash` or `false` |

Controls breadcrumb navigation for this view group. Breadcrumbs provide hierarchical context like `Home > Companies > Acme Inc > Deals > Big Deal`.

| Value | Behavior |
|-------|----------|
| omitted | Default breadcrumb: `Home > {View Label}` (plus record/action crumbs) |
| `{ relation: <name> }` | Adds parent breadcrumbs by following the named belongs_to association |
| `false` | Disables breadcrumbs entirely for this view group |

The `relation` value must match a `belongs_to` association name on the model. The engine automatically resolves the parent's view group to generate the correct links and labels. Polymorphic associations are supported — the engine reads `{relation}_type` to determine the parent model dynamically.

If the FK is nullable and the parent record is `nil`, the parent breadcrumb level is skipped. The chain recurses up to 5 levels when parent view groups also define `breadcrumb.relation`.

The "Home" crumb links to `"/"` by default. Override via `config.breadcrumb_home_path` (see [Engine Configuration](engine-configuration.md#breadcrumb_home_path)).

```yaml
# Deals breadcrumb shows: Home > Companies > {company name} > Deals > {deal title}
breadcrumb:
  relation: company

# Disable breadcrumbs
breadcrumb: false
```

### `views`

| | |
|---|---|
| **Required** | yes (at least one) |
| **Type** | array of view objects |

List of presenters in this group. Each view is rendered as a tab in the view switcher.

#### View Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `presenter` | string | yes | Presenter name. Must match a presenter's `name` attribute |
| `label` | string | no | Display label in the view switcher. Falls back to the presenter name |
| `icon` | string | no | Icon name displayed in the view switcher tab |

## Auto-Creation Behavior

You do not need to create a view group for every model. When a model has exactly one presenter and no explicit view group, the engine auto-creates a view group at load time:

- **Name**: `<model_name>_auto`
- **Primary**: the single presenter
- **Navigation**: `{ menu: "main", position: 99 }`
- **Views**: one entry with the presenter's label

This means single-presenter models appear in the navigation menu without any view group YAML. Define an explicit view group when you need to:

- Control the navigation position
- Group multiple presenters with a view switcher
- Override the default menu placement

Auto-creation is skipped when:

- An explicit view group already references the model
- The model has more than one presenter (you must define view groups explicitly to avoid ambiguity)

## Validation Rules

The configuration validator checks:

- Referenced model exists
- All referenced presenters exist
- Primary presenter is included in the views list
- No presenter appears in more than one view group
- Duplicate navigation positions produce a warning

## DSL Reference

File: `config/lcp_ruby/views/<name>.rb`

```ruby
define_view_group :deals do
  model :deal
  primary :deal

  navigation menu: "main", position: 3
  breadcrumb relation: :company

  view :deal, label: "Detailed", icon: :maximize
  view :deal_short,  label: "Short",    icon: :list
end
```

### `define_view_group(name, &block)`

Creates a view group definition. The block supports these methods:

| Method | Arguments | Description |
|--------|-----------|-------------|
| `model` | `value` | Sets the model name |
| `primary` | `value` | Sets the primary presenter name |
| `navigation` | `menu:`, `position:` | Sets navigation config. `position` is optional |
| `breadcrumb` | `false` or `relation:` | Sets breadcrumb config. Use `breadcrumb false` to disable, `breadcrumb relation: :company` to set parent relation |
| `view` | `presenter_name`, `label:`, `icon:` | Adds a view entry. `label` and `icon` are optional |

## API

### `LcpRuby.loader.view_groups_for_model(model_name)`

Returns an array of `ViewGroupDefinition` objects for the given model name. Returns an empty array if none exist. Multiple view groups can reference the same model (e.g., a "Deals" group and a "Pipeline" group both for the `deal` model).

### `LcpRuby.loader.view_group_for_presenter(presenter_name)`

Returns the `ViewGroupDefinition` that contains the given presenter, or `nil`.

### `navigable_presenters` (helper)

Available in views via `LayoutHelper`. Returns an array of hashes sorted by navigation position, one per view group. Each hash contains:

| Key | Description |
|-----|-------------|
| `:presenter` | The primary `PresenterDefinition` object |
| `:label` | Display label |
| `:slug` | URL slug |
| `:icon` | Icon name |
| `:navigation` | Navigation config hash (`menu`, `position`) |

Only view groups whose primary presenter has a slug (is routable) are included.

```erb
<% navigable_presenters.each do |entry| %>
  <%= link_to entry[:label], resources_path(lcp_slug: entry[:slug]) %>
<% end %>
```

### `current_view_group` (helper)

Available in controllers and views. Returns the `ViewGroupDefinition` for the current presenter, or `nil`.

### `sibling_views` (helper)

Available in controllers and views. Returns an array of view hashes for the current view group, each enriched with `slug` and `presenter_name` keys. Used internally by the `_view_switcher` partial.

### `breadcrumbs` (helper)

Available in controllers and views. Returns an array of `BreadcrumbBuilder::Crumb` structs for the current page. Each crumb has:

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | string | Display text |
| `path` | string or nil | Link URL (nil for the current/last crumb) |
| `current?` | boolean | True for the last crumb in the chain |

The breadcrumb chain is built automatically based on the view group's `breadcrumb` config, the current record, and the action name. The layout renders them via `app/views/lcp_ruby/shared/_breadcrumbs.html.erb`.

Source: `lib/lcp_ruby/metadata/view_group_definition.rb`, `lib/lcp_ruby/dsl/view_group_builder.rb`, `lib/lcp_ruby/presenter/breadcrumb_builder.rb`, `lib/lcp_ruby/metadata/loader.rb`, `app/helpers/lcp_ruby/layout_helper.rb`
