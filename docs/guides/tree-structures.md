# Tree Structures

Tree structures let you model parent-child hierarchies — categories, organizational units, threaded comments, folder structures — with a single `tree: true` option. The platform handles associations, traversal methods, cycle detection, and a dedicated tree index view.

## Quick Setup

### 1. Define the Model

Add a `parent_id` field and enable `tree`:

```yaml
# config/lcp_ruby/models/category.yml
model:
  name: category
  fields:
    - name: name
      type: string
      validations:
        - type: presence
    - name: parent_id
      type: integer
    - name: active
      type: boolean
      default: true
  options:
    timestamps: true
    label_method: name
    tree: true
```

**DSL equivalent:**

```ruby
LcpRuby.define_model(:category) do
  field :name, :string, validations: [{ type: "presence" }]
  field :parent_id, :integer
  field :active, :boolean, default: true
  timestamps
  label_method :name
  tree
end
```

This automatically creates:
- `belongs_to :parent` and `has_many :children` associations
- `roots` and `leaves` scopes
- Traversal methods (`ancestors`, `descendants`, `depth`, `path`, `root`, `siblings`, `subtree`)
- Cycle detection validation
- Database index on `parent_id`

### 2. Create the Presenter

Enable `tree_view` on the index:

```yaml
# config/lcp_ruby/presenters/categories.yml
presenter:
  name: categories
  model: category
  slug: categories

  index:
    tree_view: true
    default_expanded: 1
    table_columns:
      - { field: name, width: "40%", link_to: show }
      - { field: "parent.name", label: "Parent" }
      - { field: active, renderer: boolean }

  form:
    sections:
      - title: "Category Details"
        fields:
          - { field: name }
          - field: parent_id
            input_type: tree_select
            input_options:
              parent_field: parent_id
              label_method: name
              max_depth: 5
          - { field: active, input_type: boolean }

  show:
    sections:
      - title: "Category Details"
        fields:
          - { field: name }
          - { field: "parent.name", label: "Parent" }
          - { field: active }
```

### 3. Add Permissions

```yaml
# config/lcp_ruby/permissions/category.yml
permissions:
  model: category
  roles:
    admin:
      crud: [create, read, update, delete]
      fields:
        readable: [name, parent_id, active, created_at, updated_at]
        writable: [name, parent_id, active]
    viewer:
      crud: [read]
      fields:
        readable: [name, parent_id, active, created_at, updated_at]
```

## Tree Index View

With `tree_view: true`, the index page displays records as a hierarchical tree instead of a flat paginated table.

### Expand/Collapse

- Click the chevron (`▶`) next to a node to toggle its children
- `default_expanded` controls the initial state:
  - `0` — everything collapsed (only roots visible)
  - `1` — roots and their direct children visible
  - `2` — two levels expanded
  - `"all"` — entire tree expanded
- Expand/collapse state persists in the browser session (via `sessionStorage`)

### Search in Tree Views

When you search or filter in a tree view:
1. Matching records are highlighted normally
2. Ancestor nodes of matches are included for context (so you can see where matches sit in the hierarchy)
3. Ancestor-only nodes appear dimmed with no action buttons
4. The tree is always fully expanded during search (your saved collapse state is ignored)

When you clear the search, the tree returns to your previous expand/collapse state.

## Drag-and-Drop Reparenting

Enable `reparentable: true` to let users move nodes by dragging:

```yaml
index:
  tree_view: true
  default_expanded: 1
  reparentable: true
```

### How It Works

- Each row gets a drag handle (hamburger icon on the left)
- Drag a row and drop it onto another row to make it a child
- Drop onto the "Drop here to make root" zone to remove the parent
- Invalid drops (e.g., dropping a parent onto its own descendant) are prevented with a red highlight
- Uses optimistic locking — if another user changed the tree, you get a conflict notification and the page reloads

### Drop Zones

When dragging over a target row, the drop position depends on cursor location:
- **Top 25%** — reposition before target (same parent)
- **Middle 50%** — reparent as child of target
- **Bottom 25%** — reposition after target (same parent)

### Permissions

Reparenting requires:
- `update` CRUD permission on the model
- Write access to the `parent_id` field (or whatever `parent_field` is configured to)

If the user lacks either, the drag handles won't appear.

### Reparenting During Search

Drag handles are hidden when a search query is active. Clear the search to enable reparenting.

## Custom Tree Options

### Custom Association Names

```yaml
options:
  tree:
    parent_field: parent_department_id
    parent_name: parent_department
    children_name: sub_departments
```

This creates `belongs_to :parent_department` and `has_many :sub_departments`.

### Limiting Tree Depth

```yaml
options:
  tree:
    max_depth: 3
```

Attempting to create a chain deeper than 3 levels triggers a validation error: "would exceed maximum tree depth of 3".

### Child Deletion Strategy

```yaml
options:
  tree:
    dependent: nullify    # children become roots when parent is deleted
```

Available strategies:
- `destroy` — recursively delete children (default)
- `nullify` — set children's parent to NULL (they become roots)
- `restrict_with_exception` — raise an error if parent has children
- `restrict_with_error` — add a validation error if parent has children
- `discard` — cascade soft-delete (requires `soft_delete: true`)

## Ordered Trees

Enable sibling ordering with `ordered: true`:

```yaml
options:
  tree:
    ordered: true
    position_field: sort_order    # default: "position"
```

This integrates with the `positioning` gem, scoped to the parent field. Siblings within the same parent can be reordered. When `reparentable: true`, drag-and-drop also sends position information.

If the model already has an explicit `positioning` config, the tree's ordering config is skipped (the explicit config takes precedence).

## Using Tree Methods in Code

### Querying

```ruby
Category = LcpRuby.registry.model_for("category")

# Get all root categories
Category.roots

# Get leaf nodes (no children)
Category.leaves
```

### Traversal

```ruby
node = Category.find(5)

node.root?          # => false
node.leaf?          # => true
node.depth          # => 2

node.ancestors      # => [parent, grandparent] (ActiveRecord relation, nearest-first)
node.descendants    # => [child1, grandchild1, ...] (ActiveRecord relation)
node.subtree        # => [self, child1, grandchild1, ...] (ActiveRecord relation)
node.subtree_ids    # => [5, 8, 12] (array of IDs)
node.siblings       # => other nodes with same parent (ActiveRecord relation)
node.path           # => [root, ..., parent, self] (root-first order)
node.root           # => root ancestor
```

### Cycle Prevention

```ruby
# Self-reference is blocked
node.update(parent_id: node.id)
# => false, errors on parent_id: "cannot reference itself"

# Circular chains are blocked
parent.update(parent_id: child.id)
# => false, errors on parent_id: "would create a cycle in the tree"

# Max depth is enforced
deep_node.update(parent_id: some_id)
# => false if resulting depth exceeds max_depth
```

## Tree Select Widget

The `tree_select` input type renders a hierarchical dropdown for parent selection in forms:

```yaml
form:
  sections:
    - fields:
        - field: parent_id
          input_type: tree_select
          input_options:
            label_method: name
            max_depth: 5
            include_blank: "-- No Parent --"
```

The dropdown shows the full tree hierarchy with indentation and expand/collapse toggles, making it easy to find the right parent in deep trees.

## See Also

- [Tree Structures Reference](../reference/tree-structures.md) — complete option, method, and endpoint reference
- [Models Reference — `tree` option](../reference/models.md#tree) — model YAML option
- [Presenters Reference — `tree_view`](../reference/presenters.md#tree_view) — presenter index options
- [Record Positioning](../design/record_positioning.md) — positioning gem integration for ordered trees
