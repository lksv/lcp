# Tree Structures Reference

Tree structures enable declarative parent-child hierarchies on any model. A single `tree: true` option creates self-referential associations, traversal methods, cycle detection, and optional sibling ordering — replacing manual boilerplate with a complete tree infrastructure.

## Model Option

### `tree`

| | |
|---|---|
| **Default** | `false` (disabled) |
| **Type** | `true` or Hash |

**Simple form** — uses all defaults:

```yaml
options:
  tree: true
```

**Hash form** — custom configuration:

```yaml
options:
  tree:
    parent_field: parent_category_id
    parent_name: parent_category
    children_name: subcategories
    dependent: nullify
    max_depth: 5
    ordered: true
    position_field: position
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `parent_field` | string | `"parent_id"` | Foreign key column for the parent record |
| `parent_name` | string | `"parent"` | Name of the `belongs_to` parent association |
| `children_name` | string | `"children"` | Name of the `has_many` children association |
| `dependent` | string | `"destroy"` | Child strategy on parent delete (see [Dependent Options](#dependent-options)) |
| `max_depth` | integer | `10` | Maximum allowed tree depth, enforced by validation |
| `ordered` | boolean | `false` | Enable position-based sibling ordering |
| `position_field` | string | `"position"` | Column for sibling order (only when `ordered: true`) |

**DSL equivalent:**

```ruby
LcpRuby.define_model(:category) do
  field :name, :string
  field :parent_id, :integer
  tree                                    # all defaults
  # tree max_depth: 5, ordered: true      # with options
end
```

### Dependent Options

Controls what happens to children when a parent is deleted:

| Value | Behavior |
|-------|----------|
| `"destroy"` | Delete all children recursively (default) |
| `"nullify"` | Set children's parent_field to NULL (makes them roots) |
| `"restrict_with_exception"` | Raise `ActiveRecord::DeleteRestrictionError` if children exist |
| `"restrict_with_error"` | Add validation error if children exist |
| `"discard"` | Cascade soft-delete to children (requires `soft_delete: true` on the model) |

## Automatic Setup

The `TreeApplicator` runs at boot and automatically configures:

1. **Column** — `parent_field` as an integer column (you must declare it in `fields`)
2. **Associations** — `belongs_to :parent` (optional) and `has_many :children` (with `dependent` strategy)
3. **Scopes** — `roots` and `leaves`
4. **Instance methods** — 10 traversal methods (see below)
5. **Cycle detection** — validation preventing self-reference, circular chains, and max_depth violations
6. **Database index** — on the parent field for query performance
7. **Positioning** — when `ordered: true`, configures the `positioning` gem scoped to parent (unless the model already has explicit `positioning` config)

## Scopes

### `roots`

Returns records with no parent (`parent_field IS NULL`).

```ruby
Category.roots
# SELECT * FROM categories WHERE parent_id IS NULL
```

### `leaves`

Returns records that have no children (no other record references them as parent).

```ruby
Category.leaves
# SELECT * FROM categories WHERE id NOT IN (SELECT parent_id FROM categories WHERE parent_id IS NOT NULL)
```

## Instance Methods

### `root?`

Returns `true` if the record has no parent.

```ruby
root_category.root?       # => true
child_category.root?      # => false
```

### `leaf?`

Returns `true` if the record has no children.

```ruby
leaf_category.leaf?       # => true
parent_category.leaf?     # => false
```

### `ancestors`

Returns an ActiveRecord relation of all ancestors, ordered nearest-first (parent, grandparent, ...). Uses a recursive CTE for efficiency.

```ruby
deep_node.ancestors       # => [parent, grandparent, great_grandparent]
root_node.ancestors       # => [] (empty relation)
```

### `descendants`

Returns an ActiveRecord relation of all descendants at any depth. Uses a recursive CTE.

```ruby
root.descendants          # => [child1, child2, grandchild1, ...]
leaf.descendants          # => [] (empty relation)
```

### `subtree`

Returns an ActiveRecord relation containing the record itself plus all its descendants.

```ruby
node.subtree              # => [node, child1, child2, grandchild1, ...]
```

### `subtree_ids`

Returns an array of IDs for the record and all its descendants.

```ruby
node.subtree_ids          # => [1, 3, 5, 8]
```

### `siblings`

Returns an ActiveRecord relation of records with the same parent, excluding itself.

```ruby
node.siblings             # => [sibling1, sibling2]
root.siblings             # => other roots (parent_id IS NULL, excluding self)
```

### `depth`

Returns the depth of the record in the tree (0 for root nodes).

```ruby
root.depth                # => 0
child.depth               # => 1
grandchild.depth          # => 2
```

### `path`

Returns an ActiveRecord relation of records from the root down to (and including) itself, ordered root-first.

```ruby
grandchild.path           # => [root, parent, grandchild]
root.path                 # => [root]
```

### `root`

Returns the root ancestor of the record (walks up to the top of the tree).

```ruby
grandchild.root           # => root_record
root.root                 # => root (returns self)
```

## Cycle Detection

A validation (`lcp_tree_no_cycle`) runs whenever the parent field changes. It prevents three types of invalid states:

| Error | Condition | Error key |
|-------|-----------|-----------|
| Self-reference | Record set as its own parent | `:self_reference` |
| Cycle | Moving a record under one of its own descendants | `:cycle` |
| Max depth | Reparenting would exceed `max_depth` limit | `:too_deep` |

The validation walks the ancestor chain iteratively (not via CTE) and checks for visited nodes and depth limits.

```ruby
node.update(parent_id: node.id)
# => false, errors: { parent_id: ["cannot reference itself"] }

parent.update(parent_id: child.id)
# => false, errors: { parent_id: ["would create a cycle in the tree"] }
```

I18n keys:
- `lcp_ruby.errors.tree.self_reference` — "cannot reference itself"
- `lcp_ruby.errors.tree.cycle` — "would create a cycle in the tree"
- `lcp_ruby.errors.tree.too_deep` — "would exceed maximum tree depth of %{max_depth}"

## Presenter Configuration

### Index: Tree View

Three presenter index options control tree rendering:

```yaml
presenter:
  name: categories
  model: category
  slug: categories
  index:
    tree_view: true
    default_expanded: 1
    reparentable: true
    table_columns:
      - { field: name, width: "40%", link_to: show }
      - { field: "parent.name", label: "Parent" }
      - { field: active, renderer: boolean }
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tree_view` | boolean | `false` | Enable tree index rendering. Requires model `tree` option |
| `default_expanded` | integer or `"all"` | `0` | Number of tree levels expanded by default. `0` = collapsed, `1` = roots + children, `"all"` = fully expanded |
| `reparentable` | boolean | `false` | Enable drag-and-drop reparenting. Requires `tree_view: true` |

**Validation rules** (checked by `ConfigurationValidator`):
- `tree_view: true` requires the model to have `tree` enabled
- `reparentable: true` requires `tree_view: true`
- `reparentable: true` requires model `tree` enabled

### Form: Tree Select

Use `input_type: tree_select` for parent field selection in forms:

```yaml
form:
  sections:
    - title: "Details"
      fields:
        - field: parent_id
          input_type: tree_select
          input_options:
            parent_field: parent_id
            label_method: name
            max_depth: 5
            include_blank: "-- None --"
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `parent_field` | string | `"parent_id"` | FK column used to build the hierarchy |
| `label_method` | string | auto-detected | Method to display as node label |
| `max_depth` | integer | `10` | Max depth for the dropdown tree |
| `include_blank` | string | i18n lookup | Text for the "no parent" option |
| `sort` | string | none | Column to sort nodes by |

## Tree Index View

When `tree_view: true`, the index page renders a hierarchical table instead of a flat paginated list.

### Rendering

- All records are loaded (no pagination)
- Root nodes appear at the top level
- Children are nested below their parents with indentation
- Connecting guide lines (`│`, `├`, `└`) show the tree structure
- Non-leaf nodes have a chevron toggle (`▶`) for expand/collapse
- Leaf nodes have an alignment spacer

### Expand/Collapse

- Chevron click toggles child visibility
- State is saved to `sessionStorage` (persists across page navigations within session)
- State key: `lcp-tree-<slug>` (e.g., `lcp-tree-categories`)
- During search/filter, all matched nodes are always expanded (saved state is ignored)

### Search/Filter Behavior

When a search query or filter is active:
1. The search runs against all records to find matches
2. Ancestor nodes of matches are included for context (so the tree path is visible)
3. Ancestor-only nodes are dimmed (`.lcp-tree-ancestor-context` CSS class) with no action buttons
4. The tree is always fully expanded during search

## Reparenting Endpoint

### `PATCH /:lcp_slug/:id/reparent`

Moves a record to a new parent via drag-and-drop (or API call).

**Request body (JSON):**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `parent_id` | integer or `"null"` | yes | New parent ID, or `null`/`"null"` to make a root |
| `tree_version` | string | no | SHA256 hash for optimistic locking |
| `position` | object | no | Sibling position (only for ordered trees). Format: `{ "after": <id> }` or `{ "before": <id> }` |

**Responses:**

| Status | Meaning | Body |
|--------|---------|------|
| `200 OK` | Reparent succeeded | `{ "id": 5, "parent_id": 12, "tree_version": "abc..." }` |
| `409 Conflict` | Tree version mismatch (stale data) | `{ "error": "tree_version_mismatch", "tree_version": "new..." }` |
| `422 Unprocessable Entity` | Validation error (cycle, max_depth, etc.) | `{ "errors": { "parent_id": ["would create a cycle in the tree"] } }` |

**Authorization:** The user must have `update` CRUD permission and write access to the parent field.

### Optimistic Locking

The tree version is a SHA256 hash computed from all `"id:parent_id"` pairs in the tree. The client sends the version it loaded with; if the server version differs, a 409 Conflict is returned. The client typically reloads the page to get fresh data.

## CSS Classes

| Class | Element | Description |
|-------|---------|-------------|
| `lcp-tree-row` | `<tr>` | All tree rows |
| `lcp-tree-ancestor-context` | `<tr>` | Ancestor-only rows in filtered results (dimmed) |
| `lcp-tree-cell` | `<td>` | First column cell (contains guides + chevron + value) |
| `lcp-tree-node` | `<span>` | Flex wrapper inside first column |
| `lcp-tree-guide` | `<span>` | Ancestor-level guide element |
| `lcp-tree-guide-pipe` | `<span>` | Vertical continuation line (`│`) |
| `lcp-tree-guide-tee` | `<span>` | T-junction for non-last siblings (`├`) |
| `lcp-tree-guide-elbow` | `<span>` | L-junction for last siblings (`└`) |
| `lcp-tree-chevron` | `<button>` | Expand/collapse toggle (`▶` / rotated) |
| `lcp-tree-leaf-spacer` | `<span>` | Empty spacer for leaf node alignment |
| `lcp-drag-column` | `<td>` | Drag handle column |
| `lcp-drag-handle` | `<span>` | Draggable grip icon |
| `lcp-tree-root-drop-zone` | `<div>` | Drop target for making a node a root |
| `lcp-dragging` | `<tr>` | Applied to the row being dragged |
| `lcp-tree-drop-before` | `<tr>` | Drop indicator: reposition before target |
| `lcp-tree-drop-child` | `<tr>` | Drop indicator: reparent as child of target |
| `lcp-tree-drop-after` | `<tr>` | Drop indicator: reposition after target |
| `lcp-tree-drop-invalid` | `<tr>` | Invalid drop target (would create cycle) |

## Data Attributes

Row-level data attributes on `<tr>` elements:

| Attribute | Description |
|-----------|-------------|
| `data-record-id` | Record's primary key |
| `data-parent-id` | Parent's primary key (empty for roots) |
| `data-depth` | Nesting level (0 for roots) |
| `data-has-children` | `"true"` if record has children |
| `data-expanded` | `"true"` / `"false"` current expand state |
| `data-reparent-url` | PATCH URL for reparenting (if `reparentable`) |
| `data-subtree-ids` | Comma-separated descendant IDs (for drag-drop cycle prevention) |

Table-level: `data-lcp-tree-index="true"` on the `<table>` element.
