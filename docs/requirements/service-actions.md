# Service Actions and Cross-Language Protocol — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Typed Service Contracts

- [x] Custom actions with `(record, user, params) → Result` contract — BaseAction + ActionExecutor
- [x] Custom event handlers with `(record, changes) → void` contract — HandlerBase + Dispatcher
- [x] Custom transforms `(value) → value` — TransformApplicator + TypeRegistry transforms
- [x] Custom validations `(record, field, value) → errors` — custom validation type in model YAML
- [x] Custom scopes `(relation) → relation` — ScopeApplicator with registered scope classes
- [ ] `param` DSL on BaseAction — typed, validated, JSON-serializable parameter schemas
- [ ] `description` class method on actions and handlers — machine-readable service descriptions
- [ ] `to_contract` — JSON-serializable service description for actions and handlers
- [ ] `includes` DSL — declare needed associations for eager loading in action context
- [ ] Param validation before action execution (required params, type coercion)

## Parameter Schema

- [ ] Supported param types: string, integer, float, boolean, date, datetime, enum
- [ ] Required / optional parameters with defaults
- [ ] Enum parameter with allowed values
- [ ] Parameter descriptions for UI generation
- [ ] Backward compatible — actions without params work unchanged

## Cross-Language Execution Architecture

- [ ] `FunctionRunner` abstraction (Base, RubyRunner, ProcessRunner)
- [ ] `RubyRunner` — thin wrapper over current direct Ruby class execution
- [ ] `ProcessRunner` — JSON-RPC subprocess execution for external language support
- [ ] `Mutation` value object — side-effect instructions (create / update / destroy)
- [ ] `Protocol` — JSON-RPC 2.0 message builders, context serialization, response parsing

## JSON-RPC Protocol

- [ ] JSON-RPC 2.0 message format over stdin/stdout
- [ ] `execute_action` method — record snapshot in, mutations out
- [ ] `execute_handler` method — record + changes snapshot in, mutations out
- [ ] Record serialization as `{ id, model, attributes }` — plain data, never AR objects
- [ ] Association serialization — pre-loaded associations in snapshot via `includes` declaration
- [ ] Context includes: record, current_user, params, changes (for handlers)
- [ ] Mutations applied in a single AR transaction on the Ruby side
- [ ] Standard JSON-RPC 2.0 error codes (-32700 parse, -32601 method not found, -32000 application)
- [ ] Protocol versioning (`lcp_protocol_version`)

## Future Extensions (Designed For)

- [ ] Computed / derived fields as pure functions: `(record_attributes) → value`
- [ ] Dynamic defaults: `(partial_attributes) → default_value`
- [ ] Bidirectional protocol — actions can request additional data mid-execution
- [ ] Rich SDK with proxy objects for external languages (v2 — not blocked by v1 architecture)

---

## Key Points

- **Snapshot + mutations pattern** — external processes receive a serialized data snapshot and return mutation instructions. This is the explicit boundary that enables any language without coupling to ActiveRecord.
- **`includes` declaration** — actions declare what associations they need upfront. Benefits Ruby actions too (avoids N+1 queries) and enables complete snapshots for external processes.
- **Backward compatibility** — the `param` DSL is additive. Existing actions without typed params continue to work unchanged.
- **Three approaches considered**: thin protocol (data in, mutations out), rich SDK (proxy objects), and snapshot with eager-loaded associations. The recommended approach (C) combines the simplicity of thin protocol with association access via pre-loading.
