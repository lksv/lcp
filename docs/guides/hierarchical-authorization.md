# Hierarchical Authorization

When models form a parent-child chain (e.g., `factory → production_line → machine`), users who lack access to a parent should not see its children. This guide shows how to enforce hierarchical access control using LCP Ruby's existing scope mechanism.

## When to Use This Pattern

Use hierarchical authorization when:

- Your data forms a multi-level parent-child chain (3+ levels)
- Access to child records depends on the user's access to ancestor records
- Different roles should see different subsets of the hierarchy
- You need row-level security that propagates down the chain

For simpler cases (single parent, no hierarchy), use the built-in `field_match` or `association` scope types directly. See the [Permissions Reference](../reference/permissions.md#scope).

## Concepts

The key insight: **don't check each ancestor individually — filter at the query level.** Instead of loading a sensor reading and then verifying access to its machine, production line, and factory one by one, build a scope that joins through the chain and filters at the root.

```
┌──────────┐    ┌─────────────────┐    ┌──────────┐    ┌────────────────┐
│  Factory  │◄───│ Production Line │◄───│ Machine  │◄───│ Sensor Reading │
└──────────┘    └─────────────────┘    └──────────┘    └────────────────┘
     ▲
     │
  User has access to
  specific factories
     │
     ▼
  Scope filters sensor
  readings through the
  entire chain
```

This approach:

- Avoids N+1 authorization checks (one query, not one per ancestor)
- Works naturally with pagination and search
- Uses standard ActiveRecord joins — no custom authorization framework needed

## Example: Industrial IoT Monitoring

This example demonstrates a 4-level hierarchy: **factories → production lines → machines → sensor readings**. Technicians are assigned to specific factories and should only see data from machines in their factories.

### Step 1: Define the Models

```yaml
# config/lcp_ruby/models/factory.yml
model:
  name: factory
  fields:
    - name: name
      type: string
      required: true
    - name: code
      type: string
      required: true
      unique: true
    - name: location
      type: string
    - name: active
      type: boolean
      default: true
  associations:
    - type: has_many
      name: production_lines
      target_model: production_line
      foreign_key: factory_id
      dependent: destroy
```

```yaml
# config/lcp_ruby/models/production_line.yml
model:
  name: production_line
  fields:
    - name: name
      type: string
      required: true
    - name: line_type
      type: enum
      values: { assembly: "Assembly", packaging: "Packaging", testing: "Testing" }
    - name: operational
      type: boolean
      default: true
  associations:
    - type: belongs_to
      name: factory
      target_model: factory
      required: true
    - type: has_many
      name: machines
      target_model: machine
      foreign_key: production_line_id
      dependent: destroy
  scopes:
    - name: accessible_by_user
      type: custom
```

```yaml
# config/lcp_ruby/models/machine.yml
model:
  name: machine
  fields:
    - name: serial_number
      type: string
      required: true
      unique: true
    - name: name
      type: string
      required: true
    - name: status
      type: enum
      values: { running: "Running", idle: "Idle", maintenance: "Maintenance", fault: "Fault" }
      default: idle
    - name: last_maintenance_at
      type: datetime
  associations:
    - type: belongs_to
      name: production_line
      target_model: production_line
      required: true
    - type: has_many
      name: sensor_readings
      target_model: sensor_reading
      foreign_key: machine_id
      dependent: destroy
  scopes:
    - name: accessible_by_user
      type: custom
```

```yaml
# config/lcp_ruby/models/sensor_reading.yml
model:
  name: sensor_reading
  fields:
    - name: sensor_type
      type: enum
      values:
        temperature: "Temperature"
        vibration: "Vibration"
        pressure: "Pressure"
        power: "Power Consumption"
      required: true
    - name: value
      type: decimal
      precision: 10
      scale: 4
      required: true
    - name: unit
      type: string
    - name: recorded_at
      type: datetime
      required: true
    - name: alert_level
      type: enum
      values: { normal: "Normal", warning: "Warning", critical: "Critical" }
      default: normal
  associations:
    - type: belongs_to
      name: machine
      target_model: machine
      required: true
  scopes:
    - name: accessible_by_user
      type: custom
```

### Step 2: Add `accessible_factory_ids` to the User Model

The user model in the host application must provide a method that returns the IDs of factories the user can access. How you determine this is up to you — it could come from a join table, an LDAP group, or a corporate IAM system.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :user_factory_assignments
  has_many :factories, through: :user_factory_assignments,
           class_name: "LcpRuby::Dynamic::Factory"

  # Returns IDs of all factories this user can access.
  # This is the single source of truth for hierarchical access.
  def accessible_factory_ids
    factories.pluck(:id)
  end
end
```

> If your factory hierarchy is deeper (factory contains sub-sites), implement tree traversal in `accessible_factory_ids`. The platform intentionally leaves this to the host app because the right strategy (recursive CTE, materialized path, nested set) depends on your database and scale. See the [Groups & Org Structure design](../design/groups_roles_and_org_structure.md#35-organizational-units) for details.

### Step 3: Define the Hierarchy Scopes

Register custom scopes on the dynamic models. Each model in the chain filters through its ancestors back to the root (factory).

```ruby
# config/initializers/lcp_ruby_extensions.rb
Rails.application.config.after_initialize do
  # Production line: filter by factory
  LcpRuby::Dynamic::ProductionLine.scope :accessible_by_user, ->(user) {
    where(factory_id: user.accessible_factory_ids)
  }

  # Machine: join through production line to factory
  LcpRuby::Dynamic::Machine.scope :accessible_by_user, ->(user) {
    joins(:production_line)
      .where(production_lines: { factory_id: user.accessible_factory_ids })
  }

  # Sensor reading: join through machine → production line to factory
  LcpRuby::Dynamic::SensorReading.scope :accessible_by_user, ->(user) {
    joins(machine: :production_line)
      .where(production_lines: { factory_id: user.accessible_factory_ids })
  }
end
```

Each level adds one more join, but the query remains a single SQL statement:

```sql
-- Generated SQL for sensor_readings.accessible_by_user
SELECT sensor_readings.*
FROM sensor_readings
INNER JOIN machines ON machines.id = sensor_readings.machine_id
INNER JOIN production_lines ON production_lines.id = machines.production_line_id
WHERE production_lines.factory_id IN (1, 3)    -- user's accessible factories
```

### Step 4: Wire Scopes into Permissions

Reference the custom scope in each model's permission YAML. The `ScopeBuilder` calls the scope method and passes the current user automatically.

```yaml
# config/lcp_ruby/permissions/factory.yml
permissions:
  model: factory
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      scope: all
    plant_manager:
      crud: [index, show, update]
      scope:
        type: association
        field: id
        method: accessible_factory_ids
    technician:
      crud: [index, show]
      scope:
        type: association
        field: id
        method: accessible_factory_ids
  default_role: technician
```

```yaml
# config/lcp_ruby/permissions/production_line.yml
permissions:
  model: production_line
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      scope: all
    plant_manager:
      crud: [index, show, create, update]
      scope:
        type: custom
        method: accessible_by_user
    technician:
      crud: [index, show]
      scope:
        type: custom
        method: accessible_by_user
  default_role: technician
```

```yaml
# config/lcp_ruby/permissions/machine.yml
permissions:
  model: machine
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      scope: all
    plant_manager:
      crud: [index, show, create, update]
      scope:
        type: custom
        method: accessible_by_user
    technician:
      crud: [index, show, update]
      fields:
        readable: all
        writable: [status, last_maintenance_at]
      scope:
        type: custom
        method: accessible_by_user
  default_role: technician
```

```yaml
# config/lcp_ruby/permissions/sensor_reading.yml
permissions:
  model: sensor_reading
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      scope: all
      fields: { readable: all, writable: all }
    plant_manager:
      crud: [index, show]
      scope:
        type: custom
        method: accessible_by_user
      fields: { readable: all, writable: [] }
    technician:
      crud: [index, show]
      scope:
        type: custom
        method: accessible_by_user
      fields:
        readable: [sensor_type, value, unit, recorded_at, alert_level]
        writable: []
  default_role: technician
```

Notice the pattern:

| Model | Scope type | Why |
|-------|-----------|-----|
| Factory (root) | `association` | Direct filtering — user has factory IDs, no joins needed |
| Production Line (level 2) | `custom` | One join to factory |
| Machine (level 3) | `custom` | Two joins through the chain |
| Sensor Reading (level 4) | `custom` | Three joins through the chain |

The root model can use the simpler `association` scope type because it filters on its own `id` column. Child models need `custom` scopes because they must join through the ancestor chain.

### Result

With this configuration, authorization propagates automatically:

| User assigned to | Sees factories | Sees lines | Sees machines | Sees readings |
|-----------------|----------------|------------|---------------|---------------|
| Factory "Plant Prague" | Plant Prague | Lines in Prague | Machines on those lines | Readings from those machines |
| Factories "Prague" + "Brno" | Both | Lines in both | Machines in both | Readings from both |
| No factories | (none) | (none) | (none) | (none) |
| Admin (scope: all) | All | All | All | All |

## Individual Record Authorization

The scopes above handle **listing** (index). However, individual record access (show, edit, destroy) loads the record via `Model.find(id)` and authorizes it separately — the scope filter is **not** applied. This means a user who knows a record's ID could access it even if it wouldn't appear in their index listing.

In practice this is a low risk — the user would need to guess a valid ID for a record outside their hierarchy. But if your security requirements demand strict enforcement, add a `record_rule` that checks the ancestor chain:

```yaml
# config/lcp_ruby/permissions/sensor_reading.yml
permissions:
  model: sensor_reading
  record_rules:
    - name: factory_access
      condition: { field: factory_id, operator: not_in, value: current_user_accessible_factory_ids }
      effect:
        deny_crud: [show, update, destroy]
```

This requires the `factory_id` to be denormalized on the sensor reading (see [Performance Considerations](#performance-considerations) below) and `accessible_factory_ids` to be available as a user method.

Alternatively, if you don't want to denormalize, walk the ancestor chain directly via a model extension:

```ruby
# config/initializers/lcp_ruby_extensions.rb
Rails.application.config.after_initialize do
  LcpRuby::Dynamic::SensorReading.class_eval do
    def accessible_by?(user)
      user.accessible_factory_ids.include?(machine.production_line.factory_id)
    end
  end
end
```

> This requires the association chain to be loaded. Use eager loading in the presenter to avoid N+1 queries.

## Performance Considerations

**Indexes:** Ensure foreign key columns have database indexes. LCP Ruby creates indexes on `belongs_to` foreign keys by default. For the root access check, index the user-factory assignment table as well.

**Eager loading:** When displaying child records with parent info (e.g., sensor reading list showing machine name and line), configure eager loading in the presenter to avoid N+1 queries:

```yaml
# config/lcp_ruby/presenters/sensor_reading.yml
presenter:
  eager_load:
    - machine
    - machine: { production_line: :factory }
```

**Caching `accessible_factory_ids`:** If the user's factory access rarely changes, consider caching the result on the user model to avoid repeated queries:

```ruby
def accessible_factory_ids
  @accessible_factory_ids ||= factories.pluck(:id)
end
```

For request-scoped caching this is sufficient. For cross-request caching, use Rails cache with appropriate invalidation.

**Deep hierarchies (5+ levels):** Each level adds one SQL JOIN. For most hierarchies (3-5 levels) this performs well. If you go deeper, consider denormalizing the root foreign key — store `factory_id` directly on the leaf model to avoid the full join chain:

```yaml
# config/lcp_ruby/models/sensor_reading.yml (denormalized)
model:
  name: sensor_reading
  fields:
    - name: factory_id
      type: integer
      description: "Denormalized from machine.production_line.factory_id"
```

```ruby
# Scope becomes a simple WHERE instead of multi-join
LcpRuby::Dynamic::SensorReading.scope :accessible_by_user, ->(user) {
  where(factory_id: user.accessible_factory_ids)
}
```

The trade-off: simpler queries at the cost of maintaining the denormalized field (via event handler or callback).

## Related Documentation

- [Permissions Reference — Scope](../reference/permissions.md#scope) — All scope types (`field_match`, `association`, `where`, `custom`)
- [Extensibility — Model Extensions](extensibility.md#model-extensions) — How to add custom scopes to dynamic models
- [Extensibility — Custom Scopes](extensibility.md#custom-scopes) — Declaring `type: custom` scopes in model YAML
- [Groups & Org Structure — Organizational Units](../design/groups_roles_and_org_structure.md#35-organizational-units) — OU-based scoping patterns
