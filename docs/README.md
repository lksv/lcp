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
- [Permissions](reference/permissions.md) — Roles, CRUD, field access, scopes, record rules
- [Condition Operators](reference/condition-operators.md) — Shared operator reference for `visible_when`, `record_rules`, etc.
- [Eager Loading](reference/eager-loading.md) — Auto-detection, manual overrides, strategy resolution, strict_loading
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
- [Display Types](guides/display-types.md) — Visual guide to all display renderers (including dot-notation, templates, and collections)
- [Custom Renderers](guides/custom-renderers.md) — Creating custom display renderers for host applications
- [Eager Loading](guides/eager-loading.md) — N+1 prevention, strict_loading, manual overrides
- [Impersonation](guides/impersonation.md) — "View as Role X" for testing permissions
- [Developer Tools](guides/developer-tools.md) — `lcp_ruby:validate`, `lcp_ruby:erd`, and `lcp_ruby:permissions` rake tasks

## Internals

- [Architecture](architecture.md) — Module structure, data flow, controllers, views

## Examples

- [Example Apps](examples.md) — TODO and CRM app walkthroughs
