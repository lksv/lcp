# Design: Tree Structures

**Status:** Proposed
**Date:** 2026-02-22

> **Note:** This feature depends on [Model Options Infrastructure](model_options_infrastructure.md) for `boolean_or_hash_option` helper (§3), `validate_boolean_or_hash_option` validator (§4), Builder pipeline ordering (§1), cross-feature interaction matrix (§9), and error handling conventions (§10). See also [Record Positioning](record_positioning.md) for the `positioning` gem integration that tree ordering builds on, [Soft Delete](soft_delete.md) for `dependent: :discard` cascade behavior on tree associations, and [Auditing](auditing.md) for reparenting audit trail.

## Problem

The platform already supports self-referential associations (a model can `belongs_to :parent` and `has_many :children` targeting itself) and has a `tree_select` input type for selecting a parent node in a hierarchical dropdown. However, every tree model currently requires **manual boilerplate**:

1. Two explicit associations (`belongs_to :parent` + `has_many :children`) with correct FK and target_model
2. Manual scope definition for `roots` (nodes with no parent)
3. No helper methods for traversal (`ancestors`, `descendants`, `depth`, `root?`, `leaf?`)
4. No cycle detection — a record can be set as its own ancestor, corrupting the tree
5. No integration with positioning — siblings have no ordered sequence within a parent
6. No tree-aware index view — trees are displayed as flat tables

These gaps make tree models error-prone to configure and limited in functionality. A declarative `tree` option should eliminate the boilerplate and provide a complete tree infrastructure.

### Why Not Use a Gem?

Gems like `ancestry`, `closure_tree`, and `acts_as_tree` were evaluated and rejected:

**`ancestry`** stores the full path as a string column (`"1/5/12"`). This enables efficient subtree queries but creates problems:
- **Dual storage** — the ancestry string duplicates the `parent_id` FK, creating consistency risks. Alternatively, dropping `parent_id` breaks existing `tree_select` and standard AR association patterns.
- **API leakage** — adds ~40 methods with its own naming conventions. Platform code becomes coupled to ancestry's API, and gem deprecation/breaking changes affect the entire platform.
- **Dynamic model friction** — `has_ancestry` is a class-level macro that caches configuration. Combined with `LcpRuby.reset!` (which destroys and rebuilds dynamic model classes), this creates a surface for stale-state bugs.
- **Runtime dependency for all** — every host application pays the dependency cost, even those without tree models.

**`closure_tree`** uses a separate closure table (all ancestor-descendant pairs). Most efficient for read-heavy deep trees, but:
- Requires a second auto-generated table per tree model — adds `SchemaManager` complexity
- Overkill for typical business trees (< 1000 nodes, < 10 levels deep)

**Chosen approach: pure adjacency list** (`parent_id` FK) with platform-provided helper methods. Traversal methods use **recursive CTEs** (supported by PostgreSQL, MySQL 8+, SQLite 3.8.3+) for efficient single-query operations when needed. For UI operations (tree_select, tree index), all records are loaded and the tree is built in memory — this is already the existing pattern and performs well for typical business datasets.

## Goals

- Add `tree` as a model-level option in YAML and DSL
- Automatically create `belongs_to :parent` and `has_many :children` associations (no manual declaration)
- Provide `roots`, `leaves` scopes and `root?`, `leaf?`, `ancestors`, `descendants`, `siblings`, `depth`, `subtree`, `path` instance methods
- Add before_save cycle detection validation
- Integrate with positioning: `tree: { ordered: true }` automatically sets `positioning: { scope: parent_id }`
- Integrate with `ConfigurationValidator` and `SchemaManager`
- Support the feature in JSON schema validation
- No external gem dependencies
- **Tree index view** — presenter opt-in indented table with expand/collapse for tree models
- **Drag-and-drop reparenting** — move nodes (including entire branches) between parents via drag-and-drop in the tree index view, with optional sibling positioning

## Non-Goals

- DAG (Directed Acyclic Graph) support — DAG requires a fundamentally different storage mechanism (edges table instead of FK column). DAG is a separate feature that may share a `GraphNode` traversal interface with tree in the future, but the storage and UI layers are independent. See [Open Questions](#open-questions).
- Subtree-based permission scopes (`scope: subtree_of(current_user.department)`) — future extension that builds on the `subtree_ids` method this feature provides. See [Scoped Permissions](scoped_permissions.md).
- Materialized path or closure table strategies — adjacency list is sufficient for the platform's use cases. If a future need arises, a `strategy` option can be added without breaking existing tree models.
- Keyboard-based reparenting (accessibility enhancement for later).

## Design

### YAML Configuration

```yaml
# config/lcp_ruby/models/category.yml
name: category
fields:
  - name: name
    type: string
    validations:
      - type: presence
  - name: description
    type: text
  - name: parent_id
    type: integer
  - name: position
    type: integer

tree: true                    # simple form — all defaults
```

```yaml
# config/lcp_ruby/models/department.yml
name: department
fields:
  - name: name
    type: string
  - name: code
    type: string
  - name: parent_id
    type: integer
  - name: position
    type: integer

tree:
  parent_field: parent_id     # default
  children_name: children     # default
  parent_name: parent         # default
  dependent: destroy          # default — what happens to children when parent is destroyed
  max_depth: 10               # default — limit for traversal methods and cycle detection
  ordered: true               # enables positioning with scope: parent_id
```

**`parent_id` field must be declared explicitly** in the `fields` array. The `tree` option does not auto-create the column — it auto-creates the *associations* and *methods* that use it. This keeps the model definition explicit about its schema and allows the field to have custom options (e.g., index, null).

### DSL Configuration

```ruby
define_model :category do
  field :name, :string do
    validates :presence
  end
  field :parent_id, :integer
  field :position, :integer

  tree                                          # defaults
end

define_model :department do
  field :name, :string
  field :code, :string
  field :parent_id, :integer
  field :position, :integer

  tree ordered: true, max_depth: 5              # custom options
end
```

### What `tree` Enables

When `tree` is set on a model, the platform automatically:

1. **TreeApplicator** (new) — creates `belongs_to :parent` and `has_many :children` associations targeting the same model; adds scopes (`roots`, `leaves`); adds instance methods (`root?`, `leaf?`, `ancestors`, `descendants`, `siblings`, `subtree`, `depth`, `path`); adds cycle detection validation
2. **SchemaManager** — ensures `parent_id` has an index (if not already present from field definition)
3. **PositioningApplicator** — when `ordered: true`, positioning is configured with `scope: [parent_field]` (siblings have independent ordering per parent)
4. **ConfigurationValidator** — validates tree options, parent field existence, conflicts with manual associations

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `parent_field` | `string` | `"parent_id"` | FK column name for the parent reference |
| `children_name` | `string` | `"children"` | Name of the `has_many` association |
| `parent_name` | `string` | `"parent"` | Name of the `belongs_to` association |
| `dependent` | `string` | `"destroy"` | What happens to children when parent is deleted. Values: `destroy`, `nullify`, `restrict_with_exception`, `restrict_with_error`, `discard` |
| `max_depth` | `integer` | `10` | Maximum traversal depth for `ancestors`, `descendants`, and cycle detection |
| `ordered` | `boolean` | `false` | When `true`, enables `positioning` with `scope: [parent_field]` for sibling ordering |

### Scopes

| Scope | SQL | Purpose |
|-------|-----|---------|
| `roots` | `WHERE parent_id IS NULL` | Top-level nodes with no parent |
| `leaves` | `WHERE id NOT IN (SELECT parent_id FROM table WHERE parent_id IS NOT NULL)` | Nodes with no children |

### Instance Methods

| Method | Return type | Description |
|--------|-------------|-------------|
| `root?` | `Boolean` | `true` if `parent_id` is nil |
| `leaf?` | `Boolean` | `true` if the node has no children |
| `ancestors` | `ActiveRecord::Relation` | All ancestors from parent to root (ordered, nearest first). Uses recursive CTE. |
| `descendants` | `ActiveRecord::Relation` | All descendants (entire subtree below this node). Uses recursive CTE. |
| `subtree` | `ActiveRecord::Relation` | Self + all descendants. |
| `siblings` | `ActiveRecord::Relation` | Other nodes with the same parent (excluding self). |
| `depth` | `Integer` | Distance from root (root = 0). Computed via `ancestors.count`. |
| `path` | `Array<record>` | Ordered array from root to self (inclusive). `ancestors.reverse + [self]`. |
| `root` | `record` | The root ancestor of this node. Follows parent chain to the top. |
| `subtree_ids` | `Array<Integer>` | IDs of self + all descendants. Efficient for scope filtering. |

### Cycle Detection

A before_save validation prevents setting `parent_id` to the record itself or any of its descendants:

```ruby
validate :parent_not_in_subtree, if: -> { parent_id_changed? }

def parent_not_in_subtree
  return if parent_id.nil?

  if parent_id == id
    errors.add(:parent_id, :cycle, message: "cannot be the record itself")
    return
  end

  # Walk up the parent chain from the proposed parent.
  # If we encounter self, it's a cycle.
  visited = Set.new([id])
  current_id = parent_id
  steps = 0
  max = self.class.lcp_tree_max_depth

  while current_id && steps < max
    if visited.include?(current_id)
      errors.add(:parent_id, :cycle, message: "would create a cycle")
      return
    end
    visited << current_id
    current_id = self.class.where(id: current_id).pick(parent_field_name)
    steps += 1
  end

  if steps >= max
    errors.add(:parent_id, :too_deep, message: "would exceed maximum depth of #{max}")
  end
end
```

This uses iterative parent-chain walking (not recursive CTE) because:
- It needs to detect self-reference specifically (better error message)
- It needs to enforce max_depth
- It runs on save, so per-record cost is acceptable (max N queries where N = max_depth)

### Recursive CTE for Traversal

The `ancestors` and `descendants` methods use recursive CTEs for single-query traversal. The CTE is database-portable (PostgreSQL, MySQL 8+, SQLite 3.8.3+):

```ruby
# ancestors — walk up the parent chain
def ancestors
  table = self.class.arel_table
  parent_col = self.class.lcp_tree_parent_field
  max = self.class.lcp_tree_max_depth

  cte_sql = <<~SQL
    WITH RECURSIVE tree_ancestors AS (
      SELECT #{table.name}.*, 1 AS tree_depth
      FROM #{table.name}
      WHERE #{table.name}.id = #{self.class.connection.quote(send(parent_col))}

      UNION ALL

      SELECT #{table.name}.*, ta.tree_depth + 1
      FROM #{table.name}
      INNER JOIN tree_ancestors ta ON #{table.name}.id = ta.#{parent_col}
      WHERE ta.tree_depth < #{max}
    )
    SELECT id FROM tree_ancestors ORDER BY tree_depth ASC
  SQL

  ancestor_ids = self.class.connection.select_values(cte_sql)
  self.class.where(id: ancestor_ids).order(
    Arel.sql("FIELD(id, #{ancestor_ids.join(',')})") # MySQL
    # or: Arel.sql("array_position(ARRAY[#{ancestor_ids.join(',')}], id)") # PostgreSQL
  )
end
```

**Database portability note:** The ordering of results from `WHERE id IN (...)` is not guaranteed by SQL standard. The actual implementation will use a portable ordering approach — either a CASE expression or re-query with the CTE directly. The exact SQL will be adapter-aware via a helper method.

For in-memory tree building (tree_select, tree index), all records are loaded and the tree is constructed in Ruby — no CTE needed. The CTE methods are for targeted traversal (breadcrumbs, permission scopes).

### Interaction with Positioning

Tree and positioning compose naturally (see [Model Options Infrastructure §9](model_options_infrastructure.md), tree+positioning row).

When `tree: { ordered: true }`:

1. `TreeApplicator` sets `@model_definition.positioning_config` to `{ "field" => position_field, "scope" => [parent_field] }` **before** `PositioningApplicator` runs
2. `PositioningApplicator` sees the positioning config and applies the `positioned` gem macro with `on: [:parent_id]`
3. Each parent's children have independent position sequences: parent A's children are 1,2,3; parent B's children are 1,2,3
4. Moving a node to a different parent (changing `parent_id`) triggers the positioning gem's scope-change logic — the node is removed from the old parent's sequence and appended to the new parent's sequence

**Position field resolution:** When `ordered: true` is set, the tree config can optionally specify `position_field` (default: `"position"`). If the model already has a `positioning` config, `TreeApplicator` does **not** override it — the explicit `positioning` config takes precedence. This prevents conflicts when the user wants custom positioning options beyond what tree provides.

```yaml
# Tree provides positioning automatically:
tree:
  ordered: true                    # → positioning: { scope: parent_id }

# Equivalent to manually declaring:
tree: true
positioning:
  scope: parent_id

# User can override positioning details:
tree:
  ordered: true
  position_field: sort_order       # → positioning: { field: sort_order, scope: parent_id }
```

### Interaction with Soft Delete

Tree does not need special soft delete handling (see [Model Options Infrastructure §9](model_options_infrastructure.md), soft_delete+tree row). The `dependent` option on the auto-generated `has_many :children` association controls cascade behavior:

| `tree.dependent` value | On parent `destroy!` | On parent `discard!` (if soft_delete) |
|------------------------|---------------------|---------------------------------------|
| `destroy` (default) | Children are hard-deleted | No effect on children |
| `nullify` | Children's `parent_id` set to NULL | No effect on children |
| `restrict_with_exception` | Raises if children exist | No effect on children |
| `discard` | Children are hard-deleted (AR default) | Children are soft-deleted (cascade) |

When `tree.dependent` is `discard`, the `ConfigurationValidator` enforces that the model also has `soft_delete: true` (same rule as for any `dependent: :discard` association — see [Soft Delete](soft_delete.md)).

**Reparenting a discarded subtree:** If a parent is discarded and later undiscarded, cascade-discarded children are restored (handled by `SoftDeleteApplicator`, not tree). The tree structure (`parent_id` values) is preserved through discard/undiscard — soft delete does not modify `parent_id`.

### Interaction with Auditing

No special handling needed (see [Model Options Infrastructure §9](model_options_infrastructure.md), auditing+tree row). Reparenting (`update(parent_id: 12)`) is recorded as a normal field change:

```json
{ "parent_id": [5, 12] }
```

Auditing operates on `after_save` callbacks and sees `parent_id` as any other integer field. No tree-specific audit logic is required.

### Interaction with Eager Loading

Three scenarios with different strategies:

**a) One level parent (most common):**

When a presenter displays `parent.name` (dot-path resolution), `IncludesResolver` auto-detects the association and adds `includes(:parent)`. This works today with manual tree associations and continues to work with auto-generated ones.

**b) Ancestors chain (breadcrumbs):**

Cannot use `includes` because depth is unknown. Use the `ancestors` method (recursive CTE — one query) or `path` method instead. Breadcrumb renderers should call these methods rather than chaining `.parent.parent.parent`.

**c) Full tree for tree_select / tree index:**

Load all records with `Model.all` and build the tree in memory. This is the existing pattern in `build_tree_data` and performs well for typical datasets. `IncludesResolver` adds `includes(:parent)` so parent data is available without N+1 for display.

No changes to `IncludesResolver` are needed — the auto-generated associations are standard AR associations that the existing auto-detection handles correctly.

### Interaction with Existing Manual Tree Associations

When a model already has manually declared `belongs_to :parent` / `has_many :children` associations and adds `tree: true`, there is a potential conflict. The `ConfigurationValidator` detects this:

- **Error** if the model has `tree` config AND manual associations named `parent` or `children` targeting the same model — the auto-generated associations would conflict.
- **No error** if the manual associations use different names (e.g., `belongs_to :manager`, `has_many :subordinates`) — these are independent associations, not tree structure.

**Migration path for existing tree models:** Models in `examples/showcase` (category, department) currently declare tree associations manually. After this feature is implemented, they should be migrated to use `tree: true` and remove the manual association declarations.

### Tree Index View

For tree models, the standard flat table is a poor fit — parent-child relationships are invisible except through a "Parent" column. A tree index view renders records as an **indented, expandable tree** while reusing the existing table column infrastructure.

#### Presenter Configuration

```yaml
# presenters/categories.yml
presenter:
  name: categories
  model: category
  label: "Categories"
  slug: categories

  index:
    tree_view: true                  # enables tree index layout
    default_expanded: 1              # expand root level by default (0 = collapsed, :all = expand everything)
    reparentable: true               # enable drag-and-drop reparenting (default: false)
    table_columns:
      - { field: name, link_to: show }
      - { field: description }

  actions:
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

```ruby
# DSL equivalent
define_presenter :categories do
  model :category
  slug "categories"

  index do
    tree_view true
    default_expanded 1
    reparentable true             # enable drag-and-drop reparenting (default: false)

    column :name, link_to: :show
    column :description
  end
end
```

#### `tree_view: true` Behavior

When `tree_view: true` is set on the index config:

1. **Data loading** — controller loads all records (no pagination) and builds an in-memory tree. For large datasets, this is bounded by `max_depth` and the inherent size of business trees (typically < 1000 nodes).
2. **Rendering** — records are rendered as nested `<tbody>` groups. Each row has an indentation level based on its depth. Non-leaf rows have an expand/collapse toggle.
3. **Column rendering** — the first `table_column` is indented by `depth * indent_size` and prefixed with expand/collapse chevron (for non-leaf) or bullet (for leaf). Remaining columns render normally.
4. **Search/filter — filtered tree** — when a search query or filter is active, the tree view shows a **filtered tree** instead of a flat table. Matching records are displayed normally; their ancestors up to root are included for context but rendered in a dimmed style (CSS class `lcp-tree-ancestor-context`). Non-matching nodes that are not ancestors of any match are hidden. The filtered tree is automatically fully expanded so all matches are visible. See [Filtered Tree Behavior](#filtered-tree-behavior) for details.
5. **Sorting** — user-initiated column sorting (clicking headers) switches to flat table mode temporarily. Tree view only makes sense in the natural tree order.

#### Validation

`ConfigurationValidator` checks:
- `tree_view: true` requires the model to have `tree` config — error if model is not a tree
- `reparentable: true` requires `tree_view: true` on the same index config — error otherwise
- `reparentable: true` requires the model to have `tree` config — error if model is not a tree
- `tree_view: true` and pagination — warning, pagination is ignored in tree view mode (all records loaded)

#### Filtered Tree Behavior

When a search query (`?qs=...`) or advanced filter is active on a tree index, the view shows a **filtered tree** that preserves hierarchical context instead of falling back to a flat table.

**Algorithm:**

1. Execute the standard search/filter pipeline (Ransack, QuickSearch, custom filters) → produces `match_ids` (set of matching record IDs)
2. Load **all** records for the model (same as unfiltered tree view — the full tree is already in memory)
3. Build the in-memory tree as usual
4. For each matching record, collect its ancestor IDs up to root (walk the in-memory tree — no CTE needed)
5. Compute `display_ids = match_ids ∪ ancestor_ids_of_all_matches`
6. Render the tree, but only include nodes whose ID is in `display_ids`
7. Nodes in `match_ids` get normal styling; nodes in `display_ids - match_ids` (context ancestors) get CSS class `lcp-tree-ancestor-context`
8. The filtered tree is automatically fully expanded (override `default_expanded`)

**Visual example:**

```
Search: "keyboard"

Full tree:                          Filtered tree:
Electronics                         Electronics           ← ancestor, dimmed
├── Input Devices                   └── Input Devices     ← ancestor, dimmed
│   ├── Keyboards                       ├── Keyboards ✓   ← match, normal
│   ├── Mice                            └── Gaming KB ✓   ← match, normal
│   └── Gaming KB                   Accessories           ← ancestor, dimmed
├── Monitors                        └── Keyboard Cases ✓  ← match, normal
└── Audio
Accessories
├── Cases
├── Keyboard Cases
└── Cables
```

**CSS styling for context ancestors:**

```css
.lcp-tree-row.lcp-tree-ancestor-context {
  opacity: 0.5;
  font-weight: 300;
}

.lcp-tree-row.lcp-tree-ancestor-context .lcp-actions-column {
  visibility: hidden;  /* hide action buttons on context rows */
}
```

Context ancestor rows are visually dimmed to make it clear they are not matches. Action buttons (show, edit, delete) are hidden on context rows because the user is browsing search results, not the full tree.

**Edge cases:**

- **Match is a root node** — displayed normally, no ancestors needed
- **Match's ancestor is also a match** — displayed with normal styling (match wins over ancestor-context)
- **No matches** — empty state shown (same as flat table with no results)
- **All records match** — full tree displayed with normal styling on every node
- **Drag-and-drop during search** — disabled. Reparenting in a partial tree would be confusing and error-prone. The `reparentable` drag handles are hidden when any filter is active.

**Controller changes:**

```ruby
# In resources_controller.rb, tree index action
def load_tree_index_data
  all_records = @model_class.all.includes(:parent)  # full tree always loaded

  if search_active?
    match_ids = apply_advanced_search(@model_class).pluck(:id).to_set
    tree_data = build_filtered_tree(all_records, match_ids)
  else
    tree_data = build_full_tree(all_records)
  end

  @tree_roots = tree_data[:roots]
  @match_ids = tree_data[:match_ids] || nil  # nil = no filter, show all normally
end

def build_filtered_tree(all_records, match_ids)
  # Build in-memory lookup
  records_by_id = all_records.index_by(&:id)
  parent_field = current_model_definition.tree_parent_field

  # Collect ancestor IDs for all matches
  ancestor_ids = Set.new
  match_ids.each do |mid|
    current = records_by_id[mid]
    while current
      pid = current.send(parent_field)
      break if pid.nil? || ancestor_ids.include?(pid)
      ancestor_ids << pid
      current = records_by_id[pid]
    end
  end

  display_ids = match_ids | ancestor_ids

  # Filter tree roots to only include displayed nodes
  # (build_tree helper already exists — filter its output)
  { roots: build_tree_from_subset(all_records, display_ids), match_ids: match_ids }
end
```

**View rendering (filtered mode):**

```erb
<tr class="lcp-tree-row <%= 'lcp-tree-ancestor-context' if @match_ids && !@match_ids.include?(record.id) %>"
    data-record-id="<%= record.id %>"
    ...>
```

#### View Structure

```erb
<%# app/views/lcp_ruby/resources/_tree_index.html.erb %>
<table class="lcp-table lcp-tree-table"
  data-lcp-tree-index="true"
  data-default-expanded="<%= default_expanded %>"
  <% if reparentable %>
    data-reparent-url="<%= reparent_resource_path(':id') %>"
    data-tree-version="<%= @tree_version %>"
  <% end %>>
  <thead>
    <tr>
      <% columns.each do |col| %>
        <th><%= col.label %></th>
      <% end %>
      <th class="lcp-actions-column"></th>
    </tr>
  </thead>
  <tbody>
    <%= render_tree_rows(@tree_roots, columns, depth: 0) %>
  </tbody>
</table>
```

Each row:

```erb
<tr class="lcp-tree-row"
    data-record-id="<%= record.id %>"
    data-parent-id="<%= record.send(parent_field) %>"
    data-depth="<%= depth %>"
    data-has-children="<%= record.send(children_name).any? %>">
  <td style="padding-left: <%= depth * 24 + 8 %>px;">
    <% if record.send(children_name).any? %>
      <button class="lcp-tree-toggle" data-expanded="<%= expanded?(depth) %>">
        <span class="lcp-chevron">&#9654;</span>
      </button>
    <% else %>
      <span class="lcp-tree-leaf-spacer"></span>
    <% end %>
    <%= render_column_value(record, columns.first) %>
  </td>
  <% columns[1..].each do |col| %>
    <td><%= render_column_value(record, col) %></td>
  <% end %>
  <td class="lcp-actions-column">
    <%= render_action_buttons(record) %>
  </td>
</tr>
<% if expanded?(depth) %>
  <% record.send(children_name).each do |child| %>
    <%= render_tree_row(child, columns, depth: depth + 1) %>
  <% end %>
<% end %>
```

#### JavaScript — Expand/Collapse

```
app/assets/javascripts/lcp_ruby/tree_index.js
```

- Toggle expand/collapse: click chevron → show/hide child rows (by `data-parent-id` matching)
- Expand all / collapse all buttons in table header
- Persist expand state in `sessionStorage` per presenter slug (so refreshing the page remembers which nodes were open)
- Smooth animation on expand/collapse (CSS transition on `max-height`)

### Drag-and-Drop Reparenting

Tree index view supports drag-and-drop for moving nodes (including entire branches) to different parents. This combines **reparenting** (changing `parent_id`) with optional **repositioning** (setting position among new siblings).

#### Two Operations, One Gesture

A drag-and-drop in a tree can mean two things:

| Drop target | Effect | Example |
|-------------|--------|---------|
| **On a row** (drop onto a node) | Reparent: dragged node becomes a child of the target node, appended at the end of target's children | Drag "Keyboards" onto "Electronics" → "Keyboards" becomes a child of "Electronics" |
| **Between rows at same level** (drop between siblings) | Reorder: dragged node stays in the same parent, position changes | Drag "Keyboards" between "Mice" and "Monitors" under "Electronics" |
| **Between rows at different level** (drop between children of a different parent) | Reparent + reposition: dragged node becomes a child of the target parent at the specific position | Drag "Keyboards" from "Electronics" to between "Shirts" and "Pants" under "Clothing" |
| **To root level** (drop at root zone) | Reparent to root: dragged node becomes a root node (`parent_id = nil`) | Drag "Electronics" out of "Products" to the root level |

#### Visual Feedback

During drag:

1. **Drag preview** — the dragged row (+ its children count badge if non-leaf: "Keyboards (+3)") follows the cursor
2. **Drop zones** — three distinct zones per row, indicated by highlighting:
   - **Top edge** — thin blue line above the row = "insert before this sibling"
   - **Center** — row background highlights blue = "make child of this node"
   - **Bottom edge** — thin blue line below the row = "insert after this sibling"
3. **Invalid target highlight** — if the target is a descendant of the dragged node (would create a cycle), the row highlights red and shows a "no-drop" cursor. The frontend knows the dragged node's `subtree_ids` (embedded in `data-subtree-ids` attribute on the row) and checks locally before sending the request.
4. **Root drop zone** — a dedicated drop area at the bottom of the tree (or above the first root): "Drop here to make root node"
5. **Depth indicator** — indentation line shows where the node would land at its new depth

#### Subtree Move

When a non-leaf node is dragged, **the entire subtree moves with it**. The server only updates the dragged node's `parent_id` — child nodes keep their existing `parent_id` values (which point to the moved node, not to an absolute position in the tree). This is the natural behavior of adjacency list trees and requires no special handling.

Example:
```
Before:                          After (drag "B" onto "X"):
Root                             Root
├── A                            ├── A
│   ├── B          ──drag──►     ├── X
│   │   ├── B1                   │   ├── B          ← only B.parent_id changes (A → X)
│   │   └── B2                   │   │   ├── B1     ← unchanged
│   └── C                        │   │   └── B2     ← unchanged
└── X                            │   └── Y
    └── Y                        └── (A now has only C)
                                     └── C
```

Only one `UPDATE` statement: `B.parent_id = X.id`. Children B1 and B2 are unaffected.

#### Controller — `reparent` Action

**File:** `app/controllers/lcp_ruby/resources_controller.rb`

```ruby
# PATCH /:lcp_slug/:id/reparent
def reparent
  unless current_model_definition.tree?
    head :not_found
    return
  end

  authorize @record, :update?
  authorize_parent_field_writable!

  stale = verify_tree_version!
  return if stale

  parent_field = current_model_definition.tree_parent_field
  new_parent_id = parse_parent_id_param
  position_value = parse_position_param  # optional, from record_positioning

  # Assign new parent — cycle detection runs via model validation
  @record.send(:"#{parent_field}=", new_parent_id)

  # Set position if provided and model is ordered
  if position_value && current_model_definition.tree_ordered?
    pos_field = current_model_definition.tree_position_field
    @record.send(:"#{pos_field}=", position_value)
  end

  if @record.save
    render json: {
      id: @record.id,
      parent_id: @record.send(parent_field),
      position: current_model_definition.tree_ordered? ? @record.reload.send(current_model_definition.tree_position_field) : nil,
      tree_version: compute_tree_version
    }
  else
    render json: {
      error: "validation_failed",
      messages: @record.errors.full_messages
    }, status: :unprocessable_entity
  end
end

private

def authorize_parent_field_writable!
  field = current_model_definition.tree_parent_field
  unless current_evaluator.field_writable?(field)
    raise Pundit::NotAuthorizedError,
      "Not allowed to write tree parent field '#{field}'"
  end
end

def parse_parent_id_param
  raw = params[:parent_id]
  raw.blank? ? nil : raw.to_i   # blank/null = make root node
end

def verify_tree_version!
  return false unless params[:tree_version].present?

  current_version = compute_tree_version
  return false if current_version == params[:tree_version]

  render json: { error: "tree_version_mismatch", tree_version: current_version },
         status: :conflict
  true
end

def compute_tree_version
  parent_field = current_model_definition.tree_parent_field
  # Hash of (id, parent_id) pairs captures the full tree structure.
  # Any reparent, create, or delete changes this hash.
  pairs = @model_class.order(:id).pluck(:id, parent_field)
  Digest::SHA256.hexdigest(pairs.map { |id, pid| "#{id}:#{pid}" }.join(","))
end
```

**Why a separate `reparent` endpoint instead of extending `reorder`?**

| Concern | `reorder` | `reparent` |
|---------|-----------|------------|
| What changes | `position` only | `parent_id` (+ optionally `position`) |
| Validation | No cycle risk | Cycle detection required |
| Scope change | Same positioning scope | Different positioning scope (positioning gem handles scope change) |
| Permission | `field_writable?(position)` | `field_writable?(parent_id)` |
| Staleness | `list_version` (scope-local) | `tree_version` (whole tree) |

The operations are semantically distinct and have different validation and permission requirements. A combined endpoint would need conditional logic for both cases, making it harder to reason about.

**Position during reparent:** When `position` param is provided and the tree is ordered, the `positioning` gem handles the combined scope-change + position-set in one transaction. When `position` is omitted, the gem appends the node at the end of the new parent's children (default behavior for scope change).

#### Route

```ruby
# In engine routes
resources :records, path: ":lcp_slug", param: :id do
  member do
    patch :reorder      # (from record_positioning design)
    patch :reparent     # ← NEW
  end
end
```

#### Tree Version vs List Version

The existing `reorder` endpoint uses `list_version` — a hash of record IDs within a single positioning scope. This works for flat lists where the scope is fixed.

For tree reparenting, `tree_version` covers the **entire tree** — it hashes `(id, parent_id)` pairs for all records. Any structural change (reparent, create, delete) invalidates the version.

| Version | Scope | Changes on | Used by |
|---------|-------|-----------|---------|
| `list_version` | One positioning scope (e.g., children of parent X) | Reorder within scope | `reorder` endpoint |
| `tree_version` | Entire model table | Reparent, create, delete | `reparent` endpoint |

The frontend tracks `tree_version` at the table level (received from initial page load and updated from each successful `reparent` response). On conflict (409), the page reloads.

#### Frontend — `tree_reparent.js`

**File:** `app/assets/javascripts/lcp_ruby/tree_reparent.js`

Activated when `<table data-reparent-url="...">` is present.

**Drag initiation:**
1. Each tree row has a drag handle (same as `index_sortable.js` pattern) — visible only when user has write access to `parent_id`
2. On drag start, compute the dragged node's subtree IDs from `data-subtree-ids` attribute (set server-side during render)
3. Store dragged node ID and subtree IDs in drag state

**Drop zone detection** (mousemove during drag):
```
Row height divided into 3 zones:
┌─────────────────────────────┐
│  top 25%  → INSERT BEFORE   │  ← thin blue line above
├─────────────────────────────┤
│  middle 50% → MAKE CHILD    │  ← row background blue
├─────────────────────────────┤
│  bottom 25% → INSERT AFTER  │  ← thin blue line below
└─────────────────────────────┘
```

The zone determines the `position` parameter:
- **Top zone**: `{ parent_id: target.parentId, position: { before: target.id } }` — same parent as target, inserted before it
- **Middle zone**: `{ parent_id: target.id, position: "last" }` — becomes child of target, appended at end
- **Bottom zone**: `{ parent_id: target.parentId, position: { after: target.id } }` — same parent as target, inserted after it

**Cycle prevention (client-side):**
- Before highlighting a drop zone, check: is `target.id` in `draggedNode.subtreeIds`?
- If yes: show red highlight + `cursor: no-drop`, do not allow drop
- This is a UX optimization — the server validates again via model cycle detection

**Root drop zone:**
- A dedicated area (above first root or below last root) with `parent_id: null`
- Visual: dashed border area labeled "Drop here to move to root level"

**On drop:**
```javascript
async function handleDrop(draggedId, parentId, position, treeVersion) {
  const url = reparentUrl.replace(':id', draggedId);
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    },
    body: JSON.stringify({
      parent_id: parentId,         // null for root
      position: position,          // { before: id }, { after: id }, "last", or omitted
      tree_version: treeVersion
    })
  });

  if (response.ok) {
    const data = await response.json();
    updateTreeVersion(data.tree_version);
    // Move DOM nodes to reflect new tree structure
    moveDomNode(draggedId, parentId, position);
    // Update data-parent-id, data-depth, indentation on moved rows
    updateSubtreeDepths(draggedId);
  } else if (response.status === 409) {
    // Tree modified by another user
    showFlash('Tree was modified by another user, reloading...');
    location.reload();
  } else if (response.status === 422) {
    const data = await response.json();
    // Cycle detected or other validation error
    showFlash(data.messages.join(', '), 'error');
    revertDomPosition(draggedId);
  } else {
    showFlash('Failed to move item', 'error');
    revertDomPosition(draggedId);
  }
}
```

**DOM update after successful reparent:**
- Move the dragged row (and all its descendant rows) to the new position in the DOM
- Update `data-parent-id`, `data-depth` attributes on moved rows
- Recalculate indentation (`padding-left`) for the moved subtree
- Update expand/collapse state of old and new parents (old parent may become a leaf; new parent gets children)
- Update `data-subtree-ids` on affected ancestor rows

#### Presenter Configuration for Reparenting

Reparenting must be **explicitly enabled** in the presenter via `reparentable: true`. This is a deliberate opt-in because reparenting is a destructive structural operation — the configurator should enable it consciously.

When enabled, drag handles appear only if **all** conditions are met:

1. Presenter has `reparentable: true` on index config
2. Model has `tree` config
3. Presenter has `tree_view: true` on index config
4. User has `update` permission on the model
5. User has write access to `parent_id` field

```yaml
index:
  tree_view: true
  reparentable: true             # explicitly enable drag-and-drop reparenting
```

```ruby
# DSL equivalent
index do
  tree_view true
  reparentable true
end
```

Default: `reparentable: false`. Without this flag, the tree is view-only (expand/collapse still works).

**Validation:** `reparentable: true` requires `tree_view: true` on the same presenter and `tree` config on the model — otherwise `ConfigurationValidator` reports an error.

#### Interaction with `reorderable: true`

When a tree has both `tree_view: true` and `reorderable: true` (ordered tree):

- **Drag within same parent** → handled by `reorder` endpoint (position change only, uses `list_version`)
- **Drag to different parent** → handled by `reparent` endpoint (parent change + position, uses `tree_version`)

The frontend detects which operation to use by comparing `draggedNode.parentId` with the resolved target `parentId`. If they match, it's a reorder; if they differ, it's a reparent.

For **unordered trees** (no `reorderable`), only reparenting is available — drag-and-drop changes the parent but nodes have no defined order within a parent.

#### Permission Integration

| Permission check | Controls |
|-----------------|----------|
| `can?(:update)` | Whether the user can modify records at all |
| `field_writable?(parent_field)` | Whether the user can reparent (change parent_id) |
| `field_writable?(position_field)` | Whether the user can reorder (change position) — only relevant for ordered trees |

**View rendering:**

```erb
<% reparentable = current_presenter.index_config.fetch("reparentable", false) &&
                  current_model_definition.tree? &&
                  current_evaluator.can?(:update) &&
                  current_evaluator.field_writable?(current_model_definition.tree_parent_field) %>
```

When `reparentable` resolves to false (default), tree rows have no drag handles. The tree is view-only (expand/collapse still works).

**Permission YAML example:**

```yaml
roles:
  admin:
    crud: [index, show, create, update, destroy]
    fields:
      writable: all                              # can reparent + reorder

  editor:
    crud: [index, show, update]
    fields:
      writable: [name, description]              # can edit content but NOT reparent or reorder

  organizer:
    crud: [index, show, update]
    fields:
      writable: [parent_id, position]            # can reparent + reorder but NOT edit content

  viewer:
    crud: [index, show]
    fields:
      readable: all                              # tree view, no drag handles
```

## Implementation

### 1. `Metadata::ModelDefinition`

**File:** `lib/lcp_ruby/metadata/model_definition.rb`

Add tree accessor methods using the `boolean_or_hash_option` helper from [Model Options Infrastructure](model_options_infrastructure.md):

```ruby
def tree?
  boolean_or_hash_option("tree").first
end

def tree_options
  boolean_or_hash_option("tree").last
end

def tree_parent_field
  tree_options.fetch("parent_field", "parent_id")
end

def tree_children_name
  tree_options.fetch("children_name", "children")
end

def tree_parent_name
  tree_options.fetch("parent_name", "parent")
end

def tree_dependent
  tree_options.fetch("dependent", "destroy")
end

def tree_max_depth
  tree_options.fetch("max_depth", 10).to_i
end

def tree_ordered?
  tree_options.fetch("ordered", false) == true
end

def tree_position_field
  tree_options.fetch("position_field", "position")
end
```

### 2. `ModelFactory::TreeApplicator` (new)

**File:** `lib/lcp_ruby/model_factory/tree_applicator.rb`

```ruby
module LcpRuby
  module ModelFactory
    class TreeApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.tree?

        store_tree_config
        apply_associations
        apply_scopes
        apply_instance_methods
        apply_cycle_detection
        configure_positioning if @model_definition.tree_ordered?
      end

      private

      def store_tree_config
        parent_field = @model_definition.tree_parent_field
        max_depth = @model_definition.tree_max_depth

        @model_class.instance_variable_set(:@lcp_tree_parent_field, parent_field)
        @model_class.instance_variable_set(:@lcp_tree_max_depth, max_depth)
        @model_class.define_singleton_method(:lcp_tree_parent_field) { @lcp_tree_parent_field }
        @model_class.define_singleton_method(:lcp_tree_max_depth) { @lcp_tree_max_depth }
      end

      def apply_associations
        parent_field = @model_definition.tree_parent_field
        parent_name = @model_definition.tree_parent_name.to_sym
        children_name = @model_definition.tree_children_name.to_sym
        model_class = @model_class
        dependent = @model_definition.tree_dependent.to_sym

        # belongs_to :parent
        @model_class.belongs_to parent_name,
          class_name: model_class.name,
          foreign_key: parent_field,
          optional: true

        # has_many :children
        opts = {
          class_name: model_class.name,
          foreign_key: parent_field,
          dependent: (dependent == :discard ? nil : dependent),
          inverse_of: parent_name
        }
        opts.compact!
        @model_class.has_many children_name, **opts

        # Store dependent: :discard for SoftDeleteApplicator to handle
        # (AR does not recognize dependent: :discard natively)
      end

      def apply_scopes
        parent_field = @model_definition.tree_parent_field

        @model_class.scope :roots, -> { where(parent_field => nil) }
        @model_class.scope :leaves, lambda {
          child_parent_ids = select(parent_field).where.not(parent_field => nil)
          where.not(id: child_parent_ids)
        }
      end

      def apply_instance_methods
        parent_field = @model_definition.tree_parent_field
        parent_name = @model_definition.tree_parent_name.to_sym
        children_name = @model_definition.tree_children_name.to_sym
        max_depth = @model_definition.tree_max_depth

        @model_class.define_method(:root?) { send(parent_field).nil? }
        @model_class.define_method(:leaf?) { send(children_name).none? }

        @model_class.define_method(:ancestors) do
          return self.class.none if root?

          table = self.class.table_name
          pk = self.class.primary_key
          conn = self.class.connection
          quoted_parent_field = conn.quote_column_name(parent_field)
          quoted_pk = conn.quote_column_name(pk)
          quoted_table = conn.quote_table_name(table)
          quoted_parent_id = conn.quote(send(parent_field))

          cte_sql = <<~SQL.squish
            WITH RECURSIVE tree_ancestors AS (
              SELECT #{quoted_table}.*, 1 AS lcp_tree_depth
              FROM #{quoted_table}
              WHERE #{quoted_table}.#{quoted_pk} = #{quoted_parent_id}
              UNION ALL
              SELECT #{quoted_table}.*, ta.lcp_tree_depth + 1
              FROM #{quoted_table}
              INNER JOIN tree_ancestors ta ON #{quoted_table}.#{quoted_pk} = ta.#{quoted_parent_field}
              WHERE ta.lcp_tree_depth < #{max_depth}
            )
            SELECT #{quoted_pk} FROM tree_ancestors ORDER BY lcp_tree_depth ASC
          SQL

          ancestor_ids = conn.select_values(cte_sql)
          return self.class.none if ancestor_ids.empty?

          self.class.where(pk => ancestor_ids)
        end

        @model_class.define_method(:descendants) do
          table = self.class.table_name
          pk = self.class.primary_key
          conn = self.class.connection
          quoted_parent_field = conn.quote_column_name(parent_field)
          quoted_pk = conn.quote_column_name(pk)
          quoted_table = conn.quote_table_name(table)
          quoted_id = conn.quote(id)

          cte_sql = <<~SQL.squish
            WITH RECURSIVE tree_descendants AS (
              SELECT #{quoted_table}.*, 1 AS lcp_tree_depth
              FROM #{quoted_table}
              WHERE #{quoted_table}.#{quoted_parent_field} = #{quoted_id}
              UNION ALL
              SELECT #{quoted_table}.*, td.lcp_tree_depth + 1
              FROM #{quoted_table}
              INNER JOIN tree_descendants td ON #{quoted_table}.#{quoted_parent_field} = td.#{quoted_pk}
              WHERE td.lcp_tree_depth < #{max_depth}
            )
            SELECT #{quoted_pk} FROM tree_descendants
          SQL

          descendant_ids = conn.select_values(cte_sql)
          return self.class.none if descendant_ids.empty?

          self.class.where(pk => descendant_ids)
        end

        @model_class.define_method(:subtree) do
          self.class.where(id: [id] + descendants.pluck(:id))
        end

        @model_class.define_method(:subtree_ids) do
          [id] + descendants.pluck(:id)
        end

        @model_class.define_method(:siblings) do
          self.class.where(parent_field => send(parent_field)).where.not(id: id)
        end

        @model_class.define_method(:depth) do
          ancestors.count
        end

        @model_class.define_method(:path) do
          ancestor_records = ancestors.to_a
          # ancestors returns nearest-first; path needs root-first
          ancestor_records.reverse + [self]
        end

        @model_class.define_method(:root) do
          return self if root?
          path.first
        end
      end

      def apply_cycle_detection
        parent_field = @model_definition.tree_parent_field
        max_depth = @model_definition.tree_max_depth

        @model_class.validate :lcp_tree_no_cycle

        @model_class.define_method(:lcp_tree_no_cycle) do
          return if send(parent_field).nil?
          return unless send(:"#{parent_field}_changed?")

          # Self-reference check
          if persisted? && send(parent_field) == id
            errors.add(parent_field.to_sym, :cycle, message: "cannot reference itself")
            return
          end

          # Ancestor chain check — walk up from proposed parent
          visited = Set.new
          visited << id if persisted?
          current_id = send(parent_field)
          steps = 0

          while current_id && steps < max_depth
            if visited.include?(current_id)
              errors.add(parent_field.to_sym, :cycle, message: "would create a cycle")
              return
            end
            visited << current_id
            current_id = self.class.where(id: current_id).pick(parent_field)
            steps += 1
          end

          if steps >= max_depth
            errors.add(parent_field.to_sym, :too_deep, message: "would exceed maximum tree depth of #{max_depth}")
          end
        end
      end

      def configure_positioning
        # Only set positioning if not already explicitly configured
        return if @model_definition.positioned?

        pos_field = @model_definition.tree_position_field
        parent_field = @model_definition.tree_parent_field

        @model_definition.instance_variable_set(
          :@positioning_config,
          { "field" => pos_field, "scope" => [parent_field] }
        )
      end
    end
  end
end
```

### 3. `ModelFactory::Builder`

**File:** `lib/lcp_ruby/model_factory/builder.rb`

`apply_tree` is part of the canonical Builder pipeline defined in [Model Options Infrastructure §1](model_options_infrastructure.md). It runs after `apply_soft_delete` and before `apply_callbacks`:

```ruby
# Canonical pipeline position (see model_options_infrastructure.md §1):
# ...
# apply_scopes
# apply_soft_delete
# apply_tree              ← parent/child associations, traversal, cycle detection
# apply_callbacks
# apply_auditing
# ...

def apply_tree(model_class)
  TreeApplicator.new(model_class, model_definition).apply!
end
```

**Tree-specific ordering rationale** (see full rationale table in infrastructure §1):

| Step | Must come after | Reason |
|------|----------------|--------|
| `apply_tree` | `apply_associations` | TreeApplicator adds its own associations directly on the model class. Running after AssociationApplicator ensures manual associations are already in place, so ConfigurationValidator can detect conflicts at boot time. |
| `apply_tree` | `apply_soft_delete` | Tree may reference `dependent: :discard` for subtree cascade; soft_delete scopes must exist first. |
| `apply_tree` | — before `apply_positioning` | When `ordered: true`, TreeApplicator writes `@positioning_config` on ModelDefinition. PositioningApplicator reads it later. |

### 4. `ModelFactory::SchemaManager`

**File:** `lib/lcp_ruby/model_factory/schema_manager.rb`

The `parent_id` column is declared in the model's `fields` array, so `SchemaManager` already creates it. TreeApplicator adds an index if one is not already present:

```ruby
# In TreeApplicator#apply!, after associations:
def ensure_parent_index
  conn = ActiveRecord::Base.connection
  table = @model_class.table_name
  parent_field = @model_definition.tree_parent_field

  return unless conn.table_exists?(table)
  return if conn.index_exists?(table, parent_field)

  conn.add_index(table, parent_field)
end
```

No additional columns or tables are needed. The `parent_id` field already exists. If `ordered: true`, the position column is also already declared in `fields` — PositioningApplicator handles its constraints.

### 5. `Metadata::ConfigurationValidator`

**File:** `lib/lcp_ruby/metadata/configuration_validator.rb`

```ruby
def validate_tree(model)
  opts = validate_boolean_or_hash_option(model, "tree",
    allowed_keys: %w[parent_field children_name parent_name dependent max_depth ordered position_field])
  return unless opts

  parent_field = opts.fetch("parent_field", "parent_id")
  position_field = opts.fetch("position_field", "position")
  dependent = opts.fetch("dependent", "destroy")

  # Parent field must exist
  field_def = model.field(parent_field)
  unless field_def
    @errors << "Model '#{model.name}': tree parent_field '#{parent_field}' is not defined in fields"
    return
  end

  unless field_def.type == "integer"
    @errors << "Model '#{model.name}': tree parent_field '#{parent_field}' must be type 'integer', got '#{field_def.type}'"
  end

  # Parent field should be nullable (root nodes have NULL parent_id)
  if field_def.null == false
    @errors << "Model '#{model.name}': tree parent_field '#{parent_field}' must be nullable (null: true) — root nodes have no parent"
  end

  # Validate dependent value
  valid_dependents = %w[destroy nullify restrict_with_exception restrict_with_error discard]
  unless valid_dependents.include?(dependent)
    @errors << "Model '#{model.name}': tree dependent must be one of #{valid_dependents.join(', ')}, got '#{dependent}'"
  end

  # dependent: :discard requires soft_delete on the same model
  if dependent == "discard" && !model.soft_delete?
    @errors << "Model '#{model.name}': tree dependent: discard requires soft_delete to be enabled on the model"
  end

  # max_depth must be positive integer
  max_depth = opts["max_depth"]
  if max_depth && (!max_depth.is_a?(Integer) || max_depth < 1)
    @errors << "Model '#{model.name}': tree max_depth must be a positive integer, got '#{max_depth}'"
  end

  # ordered: true requires position field
  if opts["ordered"] == true
    pos_field = model.field(position_field)
    unless pos_field
      @errors << "Model '#{model.name}': tree ordered: true requires field '#{position_field}' to be defined"
    end
    if pos_field && pos_field.type != "integer"
      @errors << "Model '#{model.name}': tree position_field '#{position_field}' must be type 'integer', got '#{pos_field.type}'"
    end
  end

  # Conflict with manually declared associations
  parent_name = opts.fetch("parent_name", "parent")
  children_name = opts.fetch("children_name", "children")

  model.associations.each do |assoc|
    if assoc.name == parent_name && assoc.target_model == model.name
      @errors << "Model '#{model.name}': tree conflicts with manually declared association '#{parent_name}'. " \
                 "Remove the manual belongs_to association — tree: true creates it automatically"
    end
    if assoc.name == children_name && assoc.target_model == model.name
      @errors << "Model '#{model.name}': tree conflicts with manually declared association '#{children_name}'. " \
                 "Remove the manual has_many association — tree: true creates it automatically"
    end
  end

  # Conflict with explicit positioning when ordered: true
  if opts["ordered"] == true && model.positioned?
    scope = model.positioning_scope
    unless scope == [parent_field]
      @warnings << "Model '#{model.name}': tree ordered: true would set positioning scope to ['#{parent_field}'], " \
                   "but model already has explicit positioning with scope #{scope.inspect}. " \
                   "The explicit positioning config takes precedence"
    end
  end
end
```

### 6. `Dsl::ModelBuilder`

**File:** `lib/lcp_ruby/dsl/model_builder.rb`

```ruby
def tree(value = true, parent_field: nil, children_name: nil, parent_name: nil,
         dependent: nil, max_depth: nil, ordered: nil, position_field: nil)
  if value == true && [parent_field, children_name, parent_name, dependent,
                       max_depth, ordered, position_field].all?(&:nil?)
    @model_hash["options"]["tree"] = true
  else
    opts = {}
    opts["parent_field"] = parent_field.to_s if parent_field
    opts["children_name"] = children_name.to_s if children_name
    opts["parent_name"] = parent_name.to_s if parent_name
    opts["dependent"] = dependent.to_s if dependent
    opts["max_depth"] = max_depth if max_depth
    opts["ordered"] = ordered unless ordered.nil?
    opts["position_field"] = position_field.to_s if position_field
    @model_hash["options"]["tree"] = opts.empty? ? true : opts
  end
end
```

### 7. JSON Schema

**File:** `lib/lcp_ruby/schemas/model.json`

Add `tree` to the model options schema:

```json
"tree": {
  "oneOf": [
    { "type": "boolean", "const": true },
    {
      "type": "object",
      "properties": {
        "parent_field": {
          "type": "string",
          "description": "FK column name for the parent reference. Default: parent_id"
        },
        "children_name": {
          "type": "string",
          "description": "Name of the has_many children association. Default: children"
        },
        "parent_name": {
          "type": "string",
          "description": "Name of the belongs_to parent association. Default: parent"
        },
        "dependent": {
          "type": "string",
          "enum": ["destroy", "nullify", "restrict_with_exception", "restrict_with_error", "discard"],
          "description": "What happens to children when parent is deleted. Default: destroy"
        },
        "max_depth": {
          "type": "integer",
          "minimum": 1,
          "description": "Maximum traversal depth. Default: 10"
        },
        "ordered": {
          "type": "boolean",
          "description": "Enable positioning with scope: parent_field for sibling ordering"
        },
        "position_field": {
          "type": "string",
          "description": "Position column name when ordered: true. Default: position"
        }
      },
      "additionalProperties": false
    }
  ]
}
```

### 8. Impact on Existing `tree_select`

The existing `tree_select` input type in `FormHelper` and `ResourcesController` does **not** need changes. It works by:

1. Looking up the association on the field (via `field_config["association"]`)
2. Loading all target records
3. Building a tree in memory using `parent_field` from `input_options`

With `tree: true`, the associations are auto-generated instead of manually declared, but they produce the same AR association objects. The `tree_select` widget reads `input_options.parent_field` from the presenter, which is independent of the model's `tree` config.

However, when a model has `tree: true`, the presenter's `tree_select` can **omit `input_options.parent_field`** because the default (`parent_id`) matches the tree config's default. The `FormHelper` can be enhanced to auto-detect tree config:

```ruby
def render_tree_select(form, field_name, field_config)
  assoc = field_config["association"]
  input_options = field_config["input_options"] || {}

  # Auto-detect parent_field from tree config if not specified in presenter
  parent_field = input_options["parent_field"]
  if parent_field.nil? && assoc&.lcp_model?
    target_model_def = LcpRuby.loader.model_definition(assoc.target_model) rescue nil
    parent_field = target_model_def.tree_parent_field if target_model_def&.tree?
  end
  parent_field ||= "parent_id"

  # ... rest unchanged ...
end
```

This is a minor convenience improvement, not a requirement.

## Components Requiring No Changes

| Component | Why it works |
|---|---|
| **AssociationApplicator** | TreeApplicator creates associations directly on the model class, bypassing AssociationApplicator. No conflict — they use different association names. |
| **PermissionEvaluator** | `parent_id` is a regular field. `field_writable?("parent_id")` controls who can reparent. No tree-specific permission logic. |
| **ScopeBuilder** | Permission scopes operate on standard AR scopes. The `roots` scope can be used in permissions YAML. |
| **FieldValueResolver** | Dot-path resolution (`parent.name`) works via standard AR association traversal. The auto-generated `parent` association is indistinguishable from a manual one. |
| **LayoutBuilder** | No awareness of tree needed. `parent_id` fields are rendered via `tree_select` or `association_select` based on the presenter's `input_type`. |
| **Display::Renderers** | No tree-specific renderers needed initially. `parent.name` uses dot-path resolution with standard renderers. |
| **CustomFields** | Independent of tree structure. |
| **Events::Dispatcher** | No tree-specific events. Reparenting triggers standard `after_save` events. |

## File Changes Summary

| File | Change |
|------|--------|
| `lib/lcp_ruby/metadata/model_definition.rb` | Add `tree?`, `tree_options`, `tree_parent_field`, `tree_children_name`, `tree_parent_name`, `tree_dependent`, `tree_max_depth`, `tree_ordered?`, `tree_position_field` methods |
| `lib/lcp_ruby/model_factory/tree_applicator.rb` | **New** — associations, scopes, traversal methods, cycle detection, positioning bridge |
| `lib/lcp_ruby/model_factory/builder.rb` | Add `apply_tree` to pipeline after `apply_associations` |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Add `validate_tree` method; add `validate_tree_view` for presenter cross-check |
| `lib/lcp_ruby/dsl/model_builder.rb` | Add `tree` DSL method |
| `lib/lcp_ruby/dsl/presenter_builder.rb` | Add `tree_view`, `default_expanded`, `reparentable` methods in index block |
| `lib/lcp_ruby/schemas/model.json` | Add `tree` to model options schema |
| `lib/lcp_ruby/schemas/presenter.json` | Add `tree_view`, `default_expanded`, `reparentable` to index config schema |
| `app/helpers/lcp_ruby/form_helper.rb` | Optional: auto-detect `parent_field` from tree config in `render_tree_select` |
| `app/controllers/lcp_ruby/resources_controller.rb` | Add `reparent` action, `compute_tree_version`, tree index data loading, `build_filtered_tree` for search |
| `config/routes.rb` | Add `reparent` member route |
| `app/views/lcp_ruby/resources/_tree_index.html.erb` | **New** — tree index partial with indented rows, expand/collapse, drag handles |
| `app/views/lcp_ruby/resources/index.html.erb` | Conditional render: `_tree_index` when `tree_view: true`, existing table otherwise |
| `app/assets/javascripts/lcp_ruby/tree_index.js` | **New** — expand/collapse toggle, sessionStorage persistence |
| `app/assets/javascripts/lcp_ruby/tree_reparent.js` | **New** — drag-and-drop reparenting with drop zone detection, cycle prevention, AJAX |
| `app/assets/stylesheets/lcp_ruby/tree_index.css` | **New** — indentation, chevrons, drop zone highlights, drag preview |

## Examples

### Minimal Tree

```yaml
# models/category.yml
name: category
fields:
  - name: name
    type: string
    validations:
      - type: presence
  - name: parent_id
    type: integer

tree: true
options:
  timestamps: true
  label_method: name
```

```yaml
# presenters/categories.yml
presenter:
  name: categories
  model: category
  label: "Categories"
  slug: categories

  index:
    table_columns:
      - { field: name, link_to: show }
      - { field: "parent.name", label: "Parent" }

  form:
    sections:
      - title: "Category"
        fields:
          - { field: name }
          - field: parent_id
            input_type: tree_select
```

### Ordered Tree with Positioning

```yaml
# models/menu_item.yml
name: menu_item
fields:
  - name: label
    type: string
    validations:
      - type: presence
  - name: url
    type: string
  - name: parent_id
    type: integer
  - name: position
    type: integer
  - name: icon
    type: string

tree:
  ordered: true
  max_depth: 5

options:
  timestamps: true
  label_method: label
```

```yaml
# presenters/menu_items.yml
presenter:
  name: menu_items
  model: menu_item
  label: "Menu Items"
  slug: menu-items

  index:
    reorderable: true
    table_columns:
      - { field: icon, renderer: icon }
      - { field: label, link_to: show }
      - { field: "parent.label", label: "Parent" }
      - { field: position }

  form:
    sections:
      - title: "Menu Item"
        fields:
          - { field: label }
          - { field: url }
          - { field: icon }
          - field: parent_id
            input_type: tree_select
            input_options:
              label_method: label
              max_depth: 5
```

### DSL — Ordered Tree with Soft Delete Cascade

```ruby
define_model :department do
  field :name, :string do
    validates :presence
  end
  field :code, :string, limit: 20, transforms: [:strip, :downcase] do
    validates :presence
    validates :uniqueness
  end
  field :parent_id, :integer
  field :position, :integer

  tree ordered: true, dependent: :discard

  soft_delete true
  timestamps true
  label_method :name
end
```

### DSL — Custom Association Names

```ruby
define_model :employee do
  field :name, :string
  field :manager_id, :integer

  tree parent_field: :manager_id,
       parent_name: :manager,
       children_name: :subordinates,
       dependent: :nullify

  timestamps true
  label_method :name
end

# This generates:
# belongs_to :manager, class_name: "LcpRuby::Dynamic::Employee", foreign_key: :manager_id, optional: true
# has_many :subordinates, class_name: "LcpRuby::Dynamic::Employee", foreign_key: :manager_id, dependent: :nullify
# scope :roots → where(manager_id: nil)
# Methods: root?, leaf?, ancestors, descendants, siblings, etc.
```

### Tree Index with Drag-and-Drop Reparenting

```yaml
# models/folder.yml
name: folder
fields:
  - name: name
    type: string
    validations:
      - type: presence
  - name: parent_id
    type: integer
  - name: position
    type: integer
  - name: icon
    type: string
    default: folder

tree:
  ordered: true
  max_depth: 8

options:
  timestamps: true
  label_method: name
```

```yaml
# presenters/folders.yml
presenter:
  name: folders
  model: folder
  label: "Folder Structure"
  slug: folders

  index:
    tree_view: true
    default_expanded: 2              # expand 2 levels deep by default
    reorderable: true                # drag-and-drop sibling reorder
    reparentable: true               # enable drag-and-drop reparenting (default: false)
    table_columns:
      - { field: icon, renderer: icon, width: "40px" }
      - { field: name, link_to: show }
      - { field: created_at, renderer: relative_date, label: "Created" }

  form:
    sections:
      - title: "Folder"
        fields:
          - { field: name }
          - { field: icon }
          - field: parent_id
            input_type: tree_select
            input_options:
              label_method: name
              max_depth: 8

  actions:
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
    collection:
      - { name: create, type: built_in, icon: plus, label: "New Folder" }
```

```yaml
# permissions/folder.yml
permissions:
  model: folder
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      # Can: see tree, create folders, edit, reparent (drag-and-drop), reorder, delete

    editor:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [name, icon]
      # Can: see tree, create folders, edit name/icon
      # Cannot: reparent (no write on parent_id), reorder (no write on position)

    organizer:
      crud: [index, show, update]
      fields:
        readable: all
        writable: [parent_id, position]
      # Can: see tree, reparent via drag-and-drop, reorder siblings
      # Cannot: edit content, create, delete
```

**What the user sees:**
- Admin: full tree with drag handles, can drag folders between branches and reorder siblings
- Editor: tree view without drag handles, can expand/collapse but not rearrange
- Organizer: tree with drag handles, can rearrange structure but not edit folder names

### DSL — Tree Index with Reparenting

```ruby
define_presenter :departments do
  model :department
  slug "departments"

  index do
    tree_view true
    default_expanded :all         # expand entire tree
    reorderable true
    reparentable true             # enable drag-and-drop reparenting

    column :name, link_to: :show
    column :code
    column :employee_count, label: "Employees"  # virtual/computed field
  end
end
```

### Using Traversal Methods in Event Handlers

```ruby
# app/event_handlers/notify_department_chain.rb
class NotifyDepartmentChain
  def self.handle(event_name:, record:, changes:, **)
    return unless event_name == :after_update
    return unless changes.key?("status")

    # Notify all ancestors up to root
    record.ancestors.each do |ancestor|
      NotificationService.notify(
        ancestor,
        "Subordinate department '#{record.name}' status changed to #{record.status}"
      )
    end
  end
end
```

### Using `subtree_ids` for Scoped Queries

```ruby
# In a custom action or service
class DepartmentReportAction
  def self.execute(record:, **)
    department_ids = record.subtree_ids
    employees = LcpRuby.registry.model_for(:employee)
                       .where(department_id: department_ids)
    # Generate report for all employees in this department and sub-departments
    ReportGenerator.new(employees).generate
  end
end
```

## Test Plan

### Unit Tests

1. **ModelDefinition** — `tree?`, `tree_options`, `tree_parent_field`, `tree_children_name`, `tree_parent_name`, `tree_dependent`, `tree_max_depth`, `tree_ordered?`, `tree_position_field` for all input forms (`true`, `Hash` with options, `false`/absent)

2. **TreeApplicator — associations** — `belongs_to :parent` and `has_many :children` are created with correct class_name, foreign_key, optional, dependent; custom names (`manager`/`subordinates`) work; `dependent: :discard` is not passed to AR (handled by SoftDeleteApplicator)

3. **TreeApplicator — scopes** — `roots` returns nodes with `parent_id: nil`; `leaves` returns nodes with no children; both scopes are chainable with other scopes

4. **TreeApplicator — root? and leaf?** — `root?` returns true for root nodes, false for non-root; `leaf?` returns true for leaf nodes, false for non-leaf

5. **TreeApplicator — ancestors** — returns ordered ancestors (nearest parent first); returns empty relation for root nodes; respects `max_depth` limit; works with multi-level trees

6. **TreeApplicator — descendants** — returns all descendants; returns empty relation for leaf nodes; respects `max_depth` limit; works with multi-level trees

7. **TreeApplicator — subtree and subtree_ids** — includes self + all descendants; `subtree_ids` returns array of integers

8. **TreeApplicator — siblings** — returns other nodes with same parent; excludes self; returns empty for nodes with no siblings; root nodes' siblings are other root nodes

9. **TreeApplicator — depth** — root = 0; child of root = 1; grandchild = 2

10. **TreeApplicator — path** — returns array from root to self; root's path is `[root]`; leaf's path includes all ancestors + self

11. **TreeApplicator — root** — returns the root ancestor; root's root is self

12. **TreeApplicator — cycle detection** — rejects self-reference (`parent_id = id`); rejects direct cycle (A → B → A); rejects indirect cycle (A → B → C → A); rejects depth exceeding `max_depth`; allows valid reparenting; allows setting `parent_id` to nil (becoming root); validates only when `parent_id` changes

13. **TreeApplicator — positioning bridge** — `ordered: true` sets `@positioning_config` on ModelDefinition; explicit `positioning` config takes precedence; position scope is set to `[parent_field]`

14. **SchemaManager** — index created on `parent_id` if not already present

15. **Builder** — `apply_tree` runs in correct pipeline position; model has associations, scopes, and methods when tree enabled; model has none when tree not enabled

16. **ConfigurationValidator — tree** — accepts `true`; accepts valid Hash; rejects unknown keys; error on missing parent_field; error on non-integer parent_field; error on non-nullable parent_field; error on invalid dependent value; error on `dependent: :discard` without `soft_delete`; error on `ordered: true` without position field; error on conflicting manual associations; warning on explicit positioning conflict; error on `reparentable: true` without `tree_view: true`; error on `reparentable: true` when model has no tree config

17. **DSL** — `tree` method produces correct hash; `tree true` produces `true`; `tree ordered: true, max_depth: 5` produces correct Hash; round-trip YAML → DSL → YAML

### Integration Tests

18. **Basic tree CRUD** — create root node, create child node with parent_id, update parent_id (reparent), delete parent cascades to children (or nullifies, based on dependent)

19. **Cycle detection in form** — submit form with parent_id creating cycle → validation error displayed; submit form with valid parent_id → success

20. **tree_select with tree model** — `GET /categories/new` renders tree_select widget; tree data includes correct hierarchy; selecting a parent and saving works

21. **Traversal via show page** — show page renders `parent.name` via dot-path; breadcrumb (path) shows correct ancestor chain

22. **Ordered tree** — siblings within same parent have independent position sequences; reorder endpoint works with tree positioning scope; reparenting resets position in new parent

23. **Soft delete cascade** — tree with `dependent: :discard`: discarding parent discards children with tracking; undiscarding parent restores cascade-discarded children; tree structure (parent_id) preserved through discard/undiscard

24. **Permission integration** — role without write access to `parent_id` cannot reparent; role with write access can reparent; tree_select hidden for roles without write access to `parent_id`

25. **Tree index view rendering** — `GET /categories` with `tree_view: true` renders indented tree structure; root nodes at depth 0; children indented under parents; expand/collapse toggles present on non-leaf nodes; leaf nodes have no toggle

26. **Tree index — default_expanded** — `default_expanded: 0` renders all nodes collapsed; `default_expanded: 1` expands root level only; `default_expanded: :all` expands entire tree

27. **Tree index — filtered tree on search** — when search query is present, tree view shows only matching records + their ancestors; ancestor-context nodes have `lcp-tree-ancestor-context` CSS class; matching nodes have normal styling; filtered tree is fully expanded; when search is cleared, full tree restores; drag-and-drop handles are hidden during search

28. **Reparent endpoint — basic** — `PATCH /categories/:id/reparent` with `parent_id: X` changes the node's parent; response includes updated `tree_version`; node appears under new parent in subsequent GET

29. **Reparent endpoint — make root** — `PATCH /categories/:id/reparent` with `parent_id: null` makes node a root; node has `parent_id: nil` after update

30. **Reparent endpoint — cycle detection** — `PATCH /categories/:id/reparent` with `parent_id` set to a descendant returns 422 with cycle error message; tree structure unchanged

31. **Reparent endpoint — subtree move** — reparenting a non-leaf node moves entire subtree; children keep their `parent_id` values pointing to the moved node; descendants are accessible from new position

32. **Reparent endpoint — with position** — `PATCH /categories/:id/reparent` with `parent_id: X, position: { after: Y }` reparents and positions in one operation; node appears at correct position among new siblings

33. **Reparent endpoint — tree_version conflict** — request with stale `tree_version` returns 409; response includes current `tree_version`

34. **Reparent endpoint — permission denied** — user without write access to `parent_id` gets 403; user with write access succeeds

35. **Tree index — drag handles visibility** — drag handles rendered only when presenter has `reparentable: true` AND user has `update` + `field_writable?(parent_id)`; not rendered for read-only roles; not rendered when `reparentable` is omitted (default false)

36. **Tree index — reparentable default** — presenter with `tree_view: true` without explicit `reparentable: true` renders tree without drag handles for all users including admin; adding `reparentable: true` enables drag handles for authorized users

### Fixture Requirements

- New integration fixture set: `spec/fixtures/integration/tree_structured/`
- Tree model with `tree: true` (category or similar)
- Ordered tree model with `tree: { ordered: true }` (menu_item or similar)
- Presenter with `tree_view: true`, `reorderable: true`, and `reparentable: true`
- Presenter with `tree_view: true` without `reparentable` (default read-only tree)
- Permissions with field-level control over `parent_id` and `position`

## Open Questions

1. **Should `tree` support a `label_field` option for display?** Tree traversal methods like `path` return records, and display is handled by presenters (dot-path, label_method). A `label_field` on tree config would be redundant with the model's `label_method`. Recommendation: do not add — use `label_method` which already exists.

2. **Should `ancestors` and `descendants` return ordered relations?** `ancestors` is ordered nearest-first (via CTE `tree_depth`). `descendants` currently returns unordered. Should descendants be ordered by depth? By position (if ordered tree)? Recommendation: `descendants` returns unordered — let callers apply `.order(...)` as needed. `ancestors` returns nearest-first because that's the natural CTE order and useful for breadcrumbs.

3. **Future: GraphNode shared interface for DAG.** When DAG support is added, both tree and DAG models should respond to a common set of traversal methods (`ancestors`, `descendants`, `roots`, `leaves`, `depth`). This could be extracted into a `GraphNode` module. Recommendation: do not build the abstraction now. When DAG is designed, extract the shared interface at that point. Tree's method signatures are simple enough that they can be adapted to match a future interface without breaking changes.

4. **Should `tree: true` auto-detect the parent field from existing associations?** If a model already has `belongs_to :parent, model: :self_model`, should `tree: true` (without explicit `parent_field`) auto-detect `parent_id`? Recommendation: no. The `parent_field` default (`parent_id`) handles the common case. Auto-detection from existing associations adds complexity and may produce surprising behavior when the model has multiple self-referential associations.

5. **Performance of cycle detection on deep trees.** The iterative parent-chain walk does O(depth) queries. For `max_depth: 10` (default), this is at most 10 simple `SELECT ... WHERE id = ?` queries on an indexed column. For typical business trees, this is negligible. If profiling shows it as a bottleneck, the check could be rewritten as a single recursive CTE query. Recommendation: start with iterative approach for clarity, optimize if needed.

6. **Should `tree_view: true` be auto-enabled for tree models?** When a model has `tree` config, should the engine automatically switch the index to tree view (unless the presenter explicitly opts out)? Or should `tree_view: true` always be explicit? Recommendation: keep it explicit. Not every tree model benefits from tree index view (e.g., a flat list with a "Parent" column might be preferred for shallow trees). The presenter is the right place to opt in.

7. **Large tree performance.** Tree index loads all records (no pagination). For trees with > 1000 nodes, this could be slow. Mitigations: (a) `max_depth` limits rendering depth, (b) lazy loading of deeper levels (AJAX expand), (c) presenter `scope: roots` with lazy child loading. Recommendation: start with full load (sufficient for typical business trees), add lazy loading as a future enhancement if needed.

8. **Multi-tree models.** A model could have multiple self-referential FKs (e.g., `parent_id` and `reporting_to_id`). The current design supports one `tree` config per model. Multiple trees would need `trees: [...]` array syntax. Recommendation: defer — this is an edge case. If needed, the model can use `tree` for one hierarchy and manual associations for the other.

9. **Drag-and-drop between tree_view presenters.** Two presenters for the same model (e.g., "Active Categories" and "Archived Categories") could theoretically support drag-and-drop between them. Recommendation: out of scope — each presenter is an independent page. Cross-presenter drag would require a split-pane UI, which is a separate feature.

## Related Documents

- **[Model Options Infrastructure](model_options_infrastructure.md):** Defines shared patterns used by this design: `boolean_or_hash_option` (§3), `validate_boolean_or_hash_option` (§4), canonical Builder pipeline (§1), cross-feature interaction matrix (§9), error handling conventions (§10).
- **[Record Positioning](record_positioning.md):** `tree: { ordered: true }` delegates to the positioning feature with `scope: [parent_id]`.
- **[Soft Delete](soft_delete.md):** `dependent: :discard` cascade behavior on tree associations. ConfigurationValidator enforces `soft_delete: true` when tree uses `dependent: discard`.
- **[Auditing](auditing.md):** Reparenting (`parent_id` change) is audited as a normal field change. No tree-specific audit logic needed.
- **[Scoped Permissions](scoped_permissions.md):** Subtree-based permission scopes (`scope: subtree_of(...)`) build on the `subtree_ids` method.
