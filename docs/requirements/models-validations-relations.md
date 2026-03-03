# Models, Validations and Relations — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Model Definition

- [x] Model defined in metadata (without DB migration on change) — YAML + DSL, auto-migration at boot
- [ ] Support for multiple data stores (PostgreSQL, Oracle, MSSQL...)
- [ ] Model schema versioning (change history, rollback)
- [ ] Abstract / inherited models (shared fields across entities — timestamps, audit, soft-delete)
- [x] Dynamic field addition at runtime (EAV / JSONB extension without migration) — Custom Fields subsystem
- [x] Namespace / module grouping (logical entity grouping) — presenter slugs, view groups
- [x] Entity metadata (label, icon, plural name, searchability...)

## Field Data Types

- [x] Basic types: string, text, integer, float, decimal, boolean, date, datetime, time
- [x] Special types: email, phone, URL, IP address, color, JSON, UUID — built-in business types + custom type registry
- [x] Enums / codelists (inline definition and reference to codelist table)
- [x] File / attachment field (with metadata: MIME type, size, preview) — Active Storage integration
- [ ] Image field (with thumbnail generation, crop, resize)
- [x] Rich text field (HTML / Markdown with configurable allowed tags) — Action Text
- [ ] Geolocation field (lat/lng, address, polygon)
- [ ] Monetary field (amount + currency as a unit)
- [ ] Range types (date range, number range)
- [ ] Polymorphic field (type changes based on context — e.g., custom field value)

## Validations — Basic

- [x] Required / optional driven by metadata
- [x] Easy text field stripping on save — transform: strip
- [x] Min / max length (string)
- [x] Min / max value (number, date) — numericality validations
- [x] Regex pattern validation
- [x] Uniqueness (unique within table, within scope — e.g., unique per tenant)
- [x] Allowed values (whitelist / blacklist) — inclusion / exclusion validations
- [x] Format validations (email, phone, ID numbers...) — built-in types with transforms
- [x] MIME type and size validation for files — attachment validations

## Validations — Conditional and Advanced

- [x] Conditional validations (required field only in certain state) — `when:` conditions
- [ ] Conditional validations by user role
- [x] Conditional validations by other field value — `when:` with field conditions
- [x] Cross-field validation (end date must be after start date) — comparison validators (gt, gte, lt, lte)
- [ ] Cross-entity validation (validation against data in another table — e.g., duplicates)
- [x] Custom validators (user-defined logic) — `validates_with` + service validators
- [ ] Asynchronous validation (verification against external API — e.g., company registry)
- [x] Record-level validation as a whole (not just per field)
- [ ] Different validation sets for different actions (saving draft vs. submitting for approval)
- [ ] Validation groups (rule grouping, activation by context)

## Validations — Error Messages

- [ ] Localized error messages (multilingual)
- [x] Custom error messages per rule per field
- [ ] Error messages with interpolation (e.g., "Value must be less than {max}")
- [ ] Warning vs. error (warning that doesn't block save vs. hard error)
- [ ] Frontend and backend validation (shared rules from metadata)

## Default Values

- [x] Static default values (fixed value from metadata)
- [x] Dynamic default values (current date, current user, sequence...) — service-based defaults
- [ ] Default values from context (from parent record, URL parameter, previous record)
- [ ] Default values by role
- [ ] Default values by workflow state
- [ ] Copy-on-create (when creating a record copy — which fields to copy, which to reset)

## Computed / Derived Fields

- [x] Calculation from other fields of the same record (concatenation, arithmetic, formatting) — template-based computed fields
- [ ] Calculation from related records (SUM, COUNT, AVG, MIN, MAX across relation)
- [ ] Calculation on read (virtual field — not stored in DB)
- [x] Calculation on write (persisted — stored, recalculated on source data change) — before_save callbacks
- [ ] Chaining computed fields (A depends on B, B depends on C)
- [ ] Cyclic dependency detection between computed fields
- [ ] Lazy vs. eager recalculation (recalculate immediately vs. asynchronously / in batch)
- [x] Invalidation strategy (when to recalculate — on record change, on related record change, periodically)

## Relations

- [x] Belongs-to (N:1) — foreign key
- [x] Has-many (1:N)
- [x] Many-to-many (M:N) via join table — through associations
- [x] Has-one (1:1)
- [x] Polymorphic relations (foreign key + type — one field references different entities)
- [x] Self-referential relations (tree structure — parent/child within one entity)
- [x] Through relations (access via intermediate entity — A → B → C)
- [ ] Metadata on join table (M:N with attributes — e.g., user role in project)
- [ ] Soft-reference (reference to record without FK constraint — cross-service, archived data)

## Relation Behavior

- [x] Cascade delete / soft-delete / restrict / set null — configurable from metadata — `dependent:` option
- [x] Eager vs. lazy loading (configurable per use-case) — IncludesResolver auto-detection + manual overrides
- [x] Nested create / update (create child record with parent) — `accepts_nested_attributes_for`
- [x] Inline editing of related records (edit child directly in parent form) — nested fields in presenter
- [x] Child record ordering (default sorting, drag & drop order) — positioning gem
- [ ] Limits on related record count (min/max children)
- [ ] Relation integrity validation during import / bulk operations
- [ ] Archive / detach related record (preserve history without FK)

## Record Lifecycle

- [x] Timestamps (created_at, updated_at) automatically
- [x] Soft-delete (deleted_at) with restore capability — SoftDeleteApplicator with `discard!`/`undiscard!`, cascade discard, archive presenters, `discarded_at` column
- [ ] Record versioning (history of all changes, diff between versions)
- [x] Audit trail (who, when, what changed — per field) — AuditWriter with field-level diffs, JSON/custom field expansion, nested changes, user snapshot
- [ ] Record locking (pessimistic lock during editing, concurrent edit protection)
- [ ] Optimistic locking (version / updated_at check on save)
- [ ] Old record archival (move to archive table / storage)
- [ ] TTL / record expiration (automatic deletion / archival after time period)

## Multitenancy and Data Isolation

- [ ] Tenant ID on every record (automatic filtering)
- [ ] Shared codelists across tenants vs. tenant-specific codelists
- [x] Tenant-specific model extensions (custom fields per tenant) — Custom Fields subsystem
- [ ] Data isolation at DB level (schema per tenant vs. shared schema with tenant_id)
- [ ] Cross-tenant queries for superadmin / reporting

## Indexes and Performance

- [ ] Index definitions in metadata (single, composite, partial, unique)
- [ ] Full-text search indexes (per field, per entity)
- [x] Automatic FK column indexing — SchemaManager
- [ ] Missing index detection / recommendations based on query patterns
- [ ] Partitioning strategy for large tables (per tenant, per date)

---

## Key Points

- **Different validation sets for different actions** — this is crucial in practice. A draft saves with empty required fields, but on submission for approval everything must be filled. Without this, users can't work on a record incrementally.
- **Warning vs. error** — sometimes you want to alert the user (e.g., "unusually high amount") but not block them. Many platforms lack this and it's solved with workarounds.
- **Cyclic dependency detection for computed fields** — once A depends on B and B on A, without detection it falls into an infinite loop. Solved with topological sorting.
- **Optimistic locking** — in multi-user environments without this, two users overwrite each other's changes. A simple updated_at check on save is sufficient.
- **Polymorphic relations** — powerful feature, but you need a clear strategy for indexing and integrity (FK constraints on polymorphic relations are not possible).
- **Tenant-specific model extensions** — in enterprise low-code platforms this will be one of the first customer requests. JSONB/EAV column for custom fields per tenant is the typical solution.
