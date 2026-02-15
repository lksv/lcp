# LCP Ruby Documentation

LCP Ruby is a Rails mountable engine that generates full CRUD information systems from YAML metadata.

## Quick Start

- [Getting Started](getting-started.md) — Install, configure, create your first model/presenter/permission

## YAML Reference

Complete attribute reference for every YAML configuration file:

- [Models](reference/models.md) — Fields, validations, associations, scopes, events
- [Presenters](reference/presenters.md) — Index, show, form, search, actions, navigation
- [Permissions](reference/permissions.md) — Roles, CRUD, field access, scopes, record rules
- [Condition Operators](reference/condition-operators.md) — Shared operator reference for `visible_when`, `record_rules`, etc.
- [Engine Configuration](reference/engine-configuration.md) — `LcpRuby.configure` options

## DSL Reference

- [Model DSL](reference/model-dsl.md) — Ruby DSL alternative to YAML for model definitions
- [Presenter DSL](reference/presenter-dsl.md) — Ruby DSL alternative to YAML for presenter definitions (with inheritance)

## Guides

- [Custom Actions](guides/custom-actions.md) — Writing domain-specific operations beyond CRUD
- [Event Handlers](guides/event-handlers.md) — Responding to lifecycle events and field changes
- [Developer Tools](guides/developer-tools.md) — `lcp_ruby:validate` and `lcp_ruby:erd` rake tasks

## Internals

- [Architecture](architecture.md) — Module structure, data flow, controllers, views

## Examples

- [Example Apps](examples.md) — TODO and CRM app walkthroughs
