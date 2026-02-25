# Groups Guide

This guide walks through setting up groups to map organizational structure to authorization roles.

## Quick Start with YAML Groups

The simplest setup uses static group definitions in YAML.

### Step 1: Enable groups

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.group_source = :yaml
end
```

### Step 2: Define groups

```yaml
# config/lcp_ruby/groups.yml
groups:
  - name: engineering
    label: "Engineering Team"
    roles:
      - editor
      - viewer

  - name: management
    label: "Management"
    roles:
      - admin
```

### Step 3: Implement the group method on your User model

```ruby
class User < ApplicationRecord
  def lcp_groups
    # Return array of group name strings
    # This could come from a DB column, LDAP, or any other source
    Array(self[:groups])
  end
end
```

That's it. Users in the "engineering" group now get "editor" and "viewer" roles merged with their direct roles.

## DB-Backed Groups

For runtime group management through the platform UI.

### Step 1: Run the generator

```bash
rails generate lcp_ruby:groups
```

This creates:
- `config/lcp_ruby/models/group.yml` — Group model
- `config/lcp_ruby/models/group_membership.yml` — Membership join model
- `config/lcp_ruby/models/group_role_mapping.yml` — Role mapping model
- `config/lcp_ruby/presenters/groups.yml` — Management UI
- `config/lcp_ruby/permissions/group.yml` — Permissions
- `config/lcp_ruby/views/groups.yml` — Navigation entry

### Step 2: Start the server

```bash
rails s
```

Navigate to `/groups` to create groups, then add memberships and role mappings.

### Step 3: Membership-only mode (default)

Membership-only is the default — `group_role_mapping_model` is `nil` unless you explicitly set it. If you don't need groups to map to roles (just organizational grouping), simply omit the role mapping configuration:

```ruby
LcpRuby.configure do |config|
  config.group_source = :model
  # group_role_mapping_model defaults to nil — no role mapping
end
```

If you ran the generator, you can delete `config/lcp_ruby/models/group_role_mapping.yml` and remove the `config.group_role_mapping_model` line from the initializer.

**Note:** The generator creates UI artifacts (presenter, permissions, views) only for the group model. For full CRUD management of memberships and role mappings, create additional presenters, permissions, and view groups manually.

## Role Resolution Strategies

### Merged (default)

Direct roles + group-derived roles combined:

```ruby
config.role_resolution_strategy = :merged
```

Example: User has direct `viewer` role + belongs to "editors" group (maps to `editor` role). Effective roles: `["viewer", "editor"]`.

### Groups Only

Only group-derived roles, direct roles ignored:

```ruby
config.role_resolution_strategy = :groups_only
```

Use when all role assignment should go through groups.

### Direct Only

Only direct roles, groups ignored:

```ruby
config.role_resolution_strategy = :direct_only
```

Use when groups are informational only (organizational structure without role implications).

## Host Adapter for AD/LDAP

For enterprise environments where groups come from Active Directory or LDAP:

```ruby
class LdapGroupAdapter
  def all_group_names
    ldap_search("(objectClass=group)").map { |g| g[:cn] }
  end

  def groups_for_user(user)
    ldap_search("(&(objectClass=user)(sAMAccountName=#{user.login}))").first[:memberOf]
      .map { |dn| extract_cn(dn) }
  end

  def roles_for_group(group_name)
    GROUP_ROLE_MAP.fetch(group_name, [])
  end

  # Optional: single-query optimization
  def roles_for_user(user)
    groups_for_user(user).flat_map { |g| roles_for_group(g) }.uniq
  end

  private

  GROUP_ROLE_MAP = {
    "Domain Admins" => %w[admin],
    "Project Editors" => %w[editor viewer],
    "Readers" => %w[viewer]
  }.freeze
end

LcpRuby.configure do |config|
  config.group_source = :host
  config.group_adapter = LdapGroupAdapter.new
end
```

## Testing Groups

### Unit test with mock groups

```ruby
RSpec.describe "Project access" do
  before do
    LcpRuby::Groups::Registry.clear!
    mock_loader = double("GroupLoader")
    allow(mock_loader).to receive(:roles_for_user).and_return(%w[editor])
    LcpRuby::Groups::Registry.set_loader(mock_loader)
    LcpRuby::Groups::Registry.mark_available!
    LcpRuby.configuration.role_resolution_strategy = :merged
  end

  after do
    LcpRuby::Groups::Registry.clear!
  end

  it "grants editor permissions via group" do
    user = double("User", lcp_role: [], id: 1)
    perm_def = LcpRuby.loader.permission_definition("project")
    evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

    expect(evaluator.can?(:create)).to be true
  end
end
```

### Integration test with YAML groups

```ruby
before(:each) do
  load_integration_metadata!("my_fixture")
  LcpRuby.configuration.group_source = :yaml
  LcpRuby::Groups::Setup.apply!(LcpRuby.loader)
end
```

### Integration test with DB groups

```ruby
before(:each) do
  load_integration_metadata!("my_fixture")
  LcpRuby.configuration.group_source = :model
  LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"
  LcpRuby::Groups::Setup.apply!(LcpRuby.loader)
end

it "resolves roles via group membership" do
  group = group_model.create!(name: "editors", label: "Editors")
  mapping_model.create!(group_id: group.id, role_name: "editor")
  membership_model.create!(group_id: group.id, user_id: user.id)

  evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")
  expect(evaluator.can?(:create)).to be true
end
```
