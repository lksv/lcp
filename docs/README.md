# LCP Ruby Documentation

LCP Ruby is a Rails mountable engine that generates full CRUD information systems from YAML metadata.

## Quick Start

- [Getting Started](getting-started.md) — Install, configure, create your first model/presenter/permission

## YAML Reference

Complete attribute reference for every YAML configuration file:

- [Models](reference/models.md) — Fields, validations, associations, scopes, events, display templates
- [Types](reference/types.md) — Custom business types (email, phone, url, color, and user-defined)
- [Presenters](reference/presenters.md) — Index, show, form, search, actions, navigation
- [View Groups](reference/view-groups.md) — Navigation menu, view switching, auto-creation
- [Menu](reference/menu.md) — Configurable navigation: top bar, sidebar, dropdowns, badges, role visibility
- [Custom Fields](reference/custom-fields.md) — Runtime user-defined fields: definitions, types, permissions, querying
- [Role Source](reference/role-source.md) — DB-backed role model: contract, registry, cache invalidation, generator
- [Permission Source](reference/permission-source.md) — DB-backed permissions: JSON definitions, registry, cache invalidation, generator
- [Groups](reference/groups.md) — Organizational groups: YAML, DB, host adapter, role mapping, resolution strategies
- [Permissions](reference/permissions.md) — Roles, CRUD, field access, scopes, record rules
- [Condition Operators](reference/condition-operators.md) — Shared operator reference for `visible_when`, `record_rules`, etc.
- [Auditing](reference/auditing.md) — Change tracking: audit log model, field diffs, JSON/custom field expansion, configuration
- [Eager Loading](reference/eager-loading.md) — Auto-detection, manual overrides, strategy resolution, strict_loading
- [Tree Structures](reference/tree-structures.md) — Declarative tree hierarchies: model options, traversal, reparenting, tree index view
- [View Slots](reference/view-slots.md) — Extensible page layout injection points: registry, slot names, SlotContext, position ordering
- [Engine Configuration](reference/engine-configuration.md) — `LcpRuby.configure` options

## DSL Reference

- [Model DSL](reference/model-dsl.md) — Ruby DSL alternative to YAML for model definitions
- [Presenter DSL](reference/presenter-dsl.md) — Ruby DSL alternative to YAML for presenter definitions (with inheritance)
- [Types](reference/types.md#dsl-type-definition) — Ruby DSL for defining custom business types

## Guides

- [Presenters](guides/presenters.md) — Step-by-step guide to building presenters (index, show, form, search, actions) with YAML and DSL examples
- [Extensibility](guides/extensibility.md) — All extension mechanisms: actions, events, transforms, validators, defaults, computed fields, condition services, scopes, model extensions
- [Conditional Rendering](guides/conditional-rendering.md) — `visible_when` and `disable_when` on fields, sections, and actions
- [Custom Actions](guides/custom-actions.md) — Writing domain-specific operations beyond CRUD
- [Event Handlers](guides/event-handlers.md) — Responding to lifecycle events and field changes
- [Custom Types](guides/custom-types.md) — Defining custom business types (percentage, postal_code, slug, hex_color)
- [View Groups](guides/view-groups.md) — Multi-view navigation and view switcher setup
- [Menu](guides/menu.md) — Custom navigation menus: dropdowns, sidebar, combined layouts, badges
- [Renderers](guides/display-types.md) — Visual guide to all built-in renderers (including dot-notation, templates, and collections)
- [Custom Renderers](guides/custom-renderers.md) — Creating custom renderers for host applications
- [Attachments](guides/attachments.md) — File upload with Active Storage
- [Userstamps](guides/userstamps.md) — Automatic created_by / updated_by tracking: setup, name snapshots, presenter display, seeds
- [Soft Delete](guides/soft-delete.md) — Discard/restore, cascade, archive presenters, permissions
- [Auditing](guides/auditing.md) — Change tracking: setup, field filtering, JSON expansion, custom writer, show page integration
- [Eager Loading](guides/eager-loading.md) — N+1 prevention, strict_loading, manual overrides
- [Tree Structures](guides/tree-structures.md) — Declarative tree hierarchies: setup, tree index view, drag-and-drop reparenting, search
- [Custom Fields](guides/custom-fields.md) — Runtime user-defined fields: enabling, defining, sections, permissions, programmatic access
- [Role Source](guides/role-source.md) — DB-backed role management: setup, validation, cache, testing
- [Permission Source](guides/permission-source.md) — DB-backed permission management: runtime editing, JSON definitions, testing
- [Groups](guides/groups.md) — Organizational groups: YAML, DB, host adapter, testing
- [Hierarchical Authorization](guides/hierarchical-authorization.md) — Multi-level parent-child access control (factory → production line → machine → sensor reading)
- [Impersonation](guides/impersonation.md) — "View as Role X" for testing permissions
- [View Slots](guides/view-slots.md) — Extending page layouts: custom toolbar buttons, widgets, conditional components, overriding built-ins
- [Developer Tools](guides/developer-tools.md) — `lcp_ruby:validate`, `lcp_ruby:erd`, `lcp_ruby:permissions`, and `lcp_ruby:create_admin` rake tasks

## Design Documents

Implemented:

- [Record Positioning](design/record_positioning.md) — Drag-and-drop reordering of top-level records with the `positioning` gem
- [External Field Accessors](design/fields_accessors.md) — Virtual fields with `source: external` and `source: { service: }` accessor delegation
- [Unified Condition Operators](design/unified_condition_operators.md) — Strict condition evaluation, shared 12-operator set across all contexts
- [Record Rules Action Visibility](design/record_rules_action_visibility.md) — Automatic hiding of edit/destroy buttons based on record_rules
- [Inline Collection Editor](design/inline_collection_editor.md) — Unified editing for nested associations, JSON arrays, and bulk records: row-scoped conditions, JSON field source, virtual models, sub-sections, presenter-driven manage page
- [Groups, Roles & Org Structure](design/groups_roles_and_org_structure.md) — Enterprise organizational units, groups, and group-to-role mapping
- [Model Options Infrastructure](design/model_options_infrastructure.md) — Shared patterns for model-level feature flags (soft_delete, auditing, userstamps, tree)
- [Userstamps](design/userstamps.md) — Automatic `created_by_id` / `updated_by_id` tracking
- [Soft Delete](design/soft_delete.md) — Discard/restore support with `discarded_at` timestamp, cascade discard/undiscard, archive presenters
- [Auditing](design/auditing.md) — Native change tracking and audit trail
- [Tree Structures](design/tree_structures.md) — Declarative parent-child hierarchies with traversal, cycle detection, and tree index view
- [Saved Filters & Parameterized Scopes](design/saved_filters.md) — User-persistent named filters with visibility levels, parameterized scopes with typed parameters, generator, CRUD API

In Progress:

- [Advanced Search & Filter Builder](design/advanced_search.md) — Type-aware quick search, Ransack-based filter builder, custom filter methods, query language (Phase 0–4 implemented)
- [Page Layouts & View Slots](design/page_layout_and_slots.md) — Extensible page layout system: slot registry (Phase 1 implemented), layout variants (planned)
- [Deep Filter Enhancements](design/recursive_association_field_picker.md) — Recursive association field picker and recursive condition nesting (AND/OR tree)

Proposed:
- [Data Retention](design/data_retention.md) — Automatic purge policies for audit logs, soft-deleted records, and attachments
- [Multiselect and Batch Actions](design/multiselect_and_batch_actions.md) — Checkbox selection and bulk operations on index pages
- [Array Field Type](design/array_field_type.md) — Native array fields with typed items and array-specific operators
- [Advanced Search & Filter Builder](design/advanced_search.md) — Multi-field search, saved filters, and visual filter builder
- [Context-Aware Presenters](design/context_aware_presenters.md) — Parent-context-dependent presenter resolution for polymorphic sub-resources
- [Dynamic Presenters](design/dynamic_presenters.md) — DB-backed presenter overrides (user/role/system personalization layer)
- [Scoped Permissions](design/scoped_permissions.md) — Context-dependent permission definitions for polymorphic sub-resources
- [Context-Aware View Switcher](design/view_switcher_context.md) — View switcher integration with context-aware presenters
- [Document Management](design/document_management.md) — File-centric document management (versioning, preview, metadata, workflows)
- [Workflow & Approvals](design/workflow_and_approvals.md) — Metadata-driven state machines and approval processes

Research:

- [Basepack Search Lessons](design/basepack_lessons.md) — Lessons learned from Basepack search system for advanced search design

## Internals

- [Architecture](architecture.md) — Module structure, data flow, controllers, views

## Examples

- [Example Apps](examples.md) — TODO and CRM app walkthroughs
