# Record Rules → Action Visibility — Design Document

> **Status: Implemented.** `action_permitted_for_record?` added to `ActionSet`, integrated into `single_actions` pipeline. Only built-in `update`/`destroy` actions are filtered; `show` is excluded. Alias resolution fixed in `can_for_record?`.

## Overview

When a permission definition includes `record_rules` that deny CRUD
operations for specific records (e.g., "archived records are read-only"),
these rules currently only take effect on **individual record access**
(show/edit/destroy via Pundit policies). They do **not** affect the action
buttons shown on the **index page**.

This means the "edit" and "destroy" buttons appear for records that the
server will reject when the user actually clicks them. To hide those
buttons, the configuration author must duplicate the same condition in two
places: `permissions/record_rules` (server-side enforcement) and
`presenter/actions/visible_when` (UI visibility).

### Duplication Example

```yaml
# permissions/deal.yml — server-side enforcement
record_rules:
  - name: closed_deals_readonly
    condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

```yaml
# presenters/deals.yml — UI visibility (duplicated logic)
actions:
  single:
    - name: edit
      type: built_in
      visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
    - name: destroy
      type: built_in
      visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
```

These two definitions can easily get out of sync. When someone adds a new
record_rule, they may forget the corresponding `visible_when`, resulting in
buttons that appear but produce 403 errors.

---

## Current Architecture

### How Actions Are Filtered on Index

```
ResourcesController#index
  │
  ├─ authorize @model_class         # role-level check (once)
  ├─ policy_scope(@model_class)     # SQL WHERE for row filtering
  ├─ @records = scope.page(...)     # paginated records
  │
  └─ @action_set = ActionSet.new(presenter, evaluator)
       │
       └─ single_actions(record)     # called per row in template
            │
            ├─ filter_actions(...)    # role-level: can?(action) / can_execute_action?
            ├─ resolve_confirm(...)
            ├─ visible_when check     # ConditionEvaluator per record
            └─ disable_when check     # ConditionEvaluator per record
```

**Missing step:** No `can_for_record?` check. Record_rules are never
consulted for action visibility.

### Where `can_for_record?` IS Used

- `PolicyFactory` generates Pundit policies that call `can_for_record?` for
  `show?`, `update?`, `destroy?` — but only when the user navigates to a
  specific record (not on index).
- On index, `authorize @model_class` checks role-level `can?(:index)` once.
  Individual records are not authorized.

### Latent Bug: Action Alias Resolution

`can_for_record?` (`permission_evaluator.rb:27-44`) checks
`denied.include?(action.to_s)` against `deny_crud` values. But `deny_crud`
uses canonical names (`update`, `destroy`), while presenter actions use
display names (`edit`). The `can?` method resolves aliases via
`ACTION_ALIASES`, but `can_for_record?` does not.

This is harmless today (PolicyFactory always passes canonical names), but
becomes a bug when ActionSet starts calling `can_for_record?("edit", record)`.

---

## Proposed Solution

### A) ActionSet Calls `can_for_record?` for Built-in Actions

Add a permission check before `visible_when` evaluation:

```ruby
# lib/lcp_ruby/presenter/action_set.rb

def single_actions(record = nil)
  actions = filter_actions(presenter_definition.single_actions)
  actions = actions.map { |a| resolve_confirm(a) }
  return actions unless record

  actions
    .select { |a| action_permitted_for_record?(a, record) }
    .select { |a| action_visible_for_record?(a, record) }
    .map { |a| a.merge("_disabled" => action_disabled_for_record?(a, record)) }
end

private

def action_permitted_for_record?(action, record)
  return true unless action["type"] == "built_in"
  permission_evaluator.can_for_record?(action["name"], record)
end
```

**Only built_in actions** are affected. Custom actions use
`can_execute_action?` which has no record-level rules.

### B) Fix Alias Resolution in `can_for_record?`

```ruby
# lib/lcp_ruby/authorization/permission_evaluator.rb

def can_for_record?(action, record)
  resolved = ACTION_ALIASES[action.to_s] || action.to_s
  return false unless can?(action)

  permission_definition.record_rules.each do |rule|
    rule = rule.transform_keys(&:to_s) if rule.is_a?(Hash)
    next unless matches_condition?(record, rule["condition"])

    denied = (rule.dig("effect", "deny_crud") || []).map(&:to_s)
    except_roles = (rule.dig("effect", "except_roles") || []).map(&:to_s)

    if denied.include?(resolved) && (roles & except_roles).empty?
      return false
    end
  end

  true
end
```

Change: `denied.include?(action.to_s)` → `denied.include?(resolved)`.

---

## Behavior After Change

### With Only record_rules (No visible_when)

```yaml
# permissions/deal.yml
record_rules:
  - condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

On the index page:
- **Admin** sees edit/destroy buttons on all records (excepted from rule)
- **Sales rep** sees edit/destroy on open deals, buttons hidden on closed deals
- No `visible_when` needed in the presenter

### With Both record_rules and visible_when

Both filters apply (AND semantics). `visible_when` can add additional
UI-only conditions beyond what record_rules cover. For example:

```yaml
# permissions — server enforcement
record_rules:
  - condition: { field: stage, operator: eq, value: archived }
    effect: { deny_crud: [update] }

# presenter — additional UI hint
actions:
  single:
    - name: edit
      type: built_in
      disable_when: { field: has_pending_review, operator: eq, value: true }
```

Here record_rules hide the button for archived records, while
`disable_when` grays it out for records with pending reviews.

### Ordering

`action_permitted_for_record?` runs before `action_visible_for_record?`:
1. Permission check is cheaper (hash lookups, no service calls)
2. If denied by record_rules, no point evaluating visible_when
3. Both are `.select` filters so order doesn't affect correctness

---

## Performance Considerations

`can_for_record?` will now be called once per record per built_in action on
the index page. With N records and M built_in actions:

- **N * M * R** comparisons, where R = number of record_rules (typically 0-3)
- Each comparison is a simple `record.send(field)` + string/numeric comparison
- No DB queries — condition fields are direct record attributes (already loaded)
- Typical cost: sub-millisecond for a page of 25 records with 3 actions and
  2 record_rules

If record_rules conditions reference association fields (e.g.,
`field: project`), a lazy load per record would occur. This is currently
discouraged by the platform design — record_rules conditions should reference
direct fields. The `IncludesResolver` does not scan record_rules for
associations. This could be addressed in the future if needed.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/lcp_ruby/presenter/action_set.rb` | Add `action_permitted_for_record?`, integrate into `single_actions` |
| `lib/lcp_ruby/authorization/permission_evaluator.rb` | Fix alias resolution in `can_for_record?` |
| `spec/lib/lcp_ruby/presenter/action_set_spec.rb` | Update mocks, add record_rules tests |
| `spec/lib/lcp_ruby/authorization/permission_evaluator_spec.rb` | Add alias resolution test |

## Test Plan

### ActionSet Tests (`spec/lib/lcp_ruby/presenter/action_set_spec.rb`)

**Update existing mocks:** Add `allow(evaluator).to receive(:can_for_record?).and_return(true)` to all evaluator doubles (preserves existing test behavior).

**New tests:**
1. Built_in action hidden when `can_for_record?` returns false
2. Custom action NOT affected by `can_for_record?` (verify it's not called)
3. Mixed built_in + custom: only built_in filtered by record_rules
4. Interaction with `visible_when`: both filters apply independently
5. No record passed: `can_for_record?` not called

### PermissionEvaluator Tests (`spec/lib/lcp_ruby/authorization/permission_evaluator_spec.rb`)

**New test:** `can_for_record?("edit", archived_record)` returns false when
`deny_crud: [update]` — verifies alias resolution fix.

### Integration Verification

```bash
bundle exec rspec spec/lib/lcp_ruby/presenter/action_set_spec.rb
bundle exec rspec spec/lib/lcp_ruby/authorization/permission_evaluator_spec.rb
bundle exec rspec spec/integration/crm_spec.rb
bundle exec rspec
```

---

## Open Questions

- **Should `visible_when` on built_in actions be deprecated?** With
  record_rules automatically hiding buttons, the main use case for
  `visible_when` on built_in actions disappears. However, `visible_when` can
  express conditions that don't map to CRUD denial (e.g., hide "show" button
  based on business logic that doesn't affect authorization). Keep both for now.

- **Should record_rules apply to `show` actions on index?** If `deny_crud`
  includes `show`, the show button/link would be hidden. But the record is
  still in the list (scope allowed it). Is that confusing? The scope should
  probably handle visibility of records, not record_rules. Consider whether
  `action_permitted_for_record?` should only check `update` and `destroy`,
  not `show` and `index`.

- **Future: IncludesResolver awareness of record_rules.** If record_rules
  start referencing association fields, `IncludesResolver` should scan them
  and add to the eager loading strategy. Not needed now (conditions
  reference direct fields), but worth noting as a future enhancement.
