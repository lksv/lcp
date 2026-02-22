# Design: Multiselect and Batch Actions

**Status:** Proposed
**Date:** 2026-02-22

## Problem

The platform supports single-record actions (show, edit, delete, custom actions) but provides no way to act on multiple records at once. Users working with lists of 10–1000 records regularly need to:

- Delete 15 obsolete deals in one go instead of clicking delete 15 times
- Change the status of 30 orders from "pending" to "approved"
- Export a filtered subset of records to CSV
- Compare two or three records side by side to spot differences
- Assign an owner/category to a batch of newly imported records

Without multiselect, these workflows require either per-record clicking (tedious, error-prone) or direct database access (dangerous, unaudited).

The backend infrastructure for batch actions already exists — routes (`POST /batch_actions/:action_name`), controller (`ActionsController#execute_batch`), and action base class (`BaseAction` with `records` attribute) are implemented. What's missing is the UI layer (checkbox selection, toolbar, JavaScript) and a set of built-in batch actions covering the most common use cases.

## Goals

- Add checkbox-based record selection to the index table view
- Provide a batch action toolbar that appears when records are selected
- Define a set of built-in batch actions: delete, update, export, assign
- Support custom batch actions defined by the host app (same pattern as single custom actions)
- Integrate with existing permission system — batch actions respect `can_execute_action?` and per-record permission rules
- Integrate with soft delete — bulk discard instead of hard delete when model has `soft_delete: true`
- Integrate with auditing — each record in a batch operation gets its own audit log entry
- Handle cross-page selection (select records across paginated pages)
- Support `visible_when` conditions on batch action buttons (based on selection state)

## Non-Goals

- Batch edit with a form UI (inline editing of multiple records in a spreadsheet-like view) — this is a separate, much larger feature
- Real-time progress bars for long-running batch operations (use flash messages for now; async processing with progress is a future enhancement)
- Batch actions on nested/child records (only top-level index records)
- Record comparison/diff UI (mentioned as a use case; the batch action provides the data, but the diff view is a separate presenter feature)

## Use Cases

### Built-in Batch Actions

| Action | Description | When useful |
|--------|-------------|-------------|
| **Bulk delete** | Soft-delete or hard-delete selected records | Cleaning up obsolete data |
| **Bulk update** | Set one or more fields to the same value on all selected records | Mass status change, category reassignment, owner assignment |
| **Bulk export** | Export selected records to CSV (or other format) | Reporting, data extraction, sharing a subset |

### Custom Batch Actions (host app defined)

| Action | Description | Example |
|--------|-------------|---------|
| **Bulk approve** | Transition selected records through a workflow step | Approve 20 expense reports at once |
| **Bulk assign** | Assign selected records to a user/team | Distribute leads to sales reps |
| **Bulk tag** | Add/remove tags from selected records | Categorize imported records |
| **Bulk email** | Send a notification to contacts linked to selected records | Campaign outreach |
| **Bulk archive** | Move selected records to an archive state | End-of-quarter cleanup |
| **Bulk clone** | Duplicate selected records with modifications | Create next quarter's budget from current |
| **Bulk print** | Generate a printable view or PDF for selected records | Invoice batch printing |
| **Merge** | Combine 2-3 duplicate records into one | CRM deduplication |

Custom batch actions follow the same pattern as single custom actions — a Ruby class in `app/actions/` that receives `records` instead of `record`.

## Design

### Presenter Configuration

Batch actions are configured in the presenter YAML under `actions.batch`:

```yaml
# presenters/deals.yml
presenter:
  name: deals
  model: deal
  label: "Deals"
  slug: deals

  actions:
    collection:
      - { name: create, type: built_in, label: "New Deal", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
    batch:
      - { name: destroy, type: built_in, label: "Delete Selected", icon: trash, confirm: true, style: danger }
      - { name: update, type: built_in, label: "Update Selected", icon: pencil }
      - { name: export, type: built_in, label: "Export Selected", icon: download }
      - name: approve
        type: custom
        label: "Approve Selected"
        icon: check
        confirm: true
        confirm_message: "Approve %{count} selected deals?"
```

**Key differences from single actions:**

| Aspect | Single actions | Batch actions |
|--------|---------------|---------------|
| **Context** | One `record` | Array of `records` |
| **Visibility** | `visible_when` evaluates per record | `visible_when` evaluates against selection metadata (count, common field values) |
| **Permission** | `can_for_record?` per record | `can_execute_action?` on action name; per-record filtering at execution time |
| **Confirm message** | Static string | Supports `%{count}` interpolation |

### Built-in Batch Actions

#### `destroy` — Bulk Delete

Deletes all selected records. Respects soft delete — calls `discard!` on soft-deletable models, `destroy!` on others.

```ruby
# Internally handled by ActionsController, no separate action class needed
def execute_built_in_batch(action_name, records)
  case action_name
  when "destroy"
    batch_destroy(records)
  when "export"
    batch_export(records)
  end
end

def batch_destroy(records)
  destroyed = 0
  denied = 0

  records.each do |record|
    if current_evaluator.can_for_record?(:destroy, record)
      if current_model_definition.soft_delete?
        record.discard!
      else
        record.destroy!
      end
      destroyed += 1
    else
      denied += 1
    end
  end

  message = "#{destroyed} #{current_model_definition.label.pluralize(destroyed)} deleted."
  message += " #{denied} skipped (insufficient permissions)." if denied > 0
  Actions::Result.new(success: true, message: message, redirect_to: nil, data: nil, errors: [])
end
```

**Per-record permission check:** Even though the user has batch-level `can?(:destroy)`, individual records may be denied by record-level rules (e.g., "cannot delete closed deals"). The batch operation skips denied records and reports the count.

#### `update` — Bulk Update

Sets specified field values on all selected records. Requires a parameter form (modal) to collect the field/value pairs.

The `update` batch action uses the `param_schema` mechanism on `BaseAction`:

```yaml
# Presenter YAML
batch:
  - name: update
    type: built_in
    label: "Update Selected"
    icon: pencil
    fields: [stage, owner_id]        # which fields can be bulk-updated
```

The controller renders a modal form with the specified fields. On submit, each record is updated:

```ruby
def batch_update(records, update_params)
  updated = 0
  denied = 0
  failed = 0

  records.each do |record|
    if current_evaluator.can_for_record?(:update, record)
      # Filter to writable fields for this record
      writable = update_params.select { |k, _| current_evaluator.field_writable?(k) }
      if record.update(writable)
        updated += 1
      else
        failed += 1
      end
    else
      denied += 1
    end
  end

  parts = ["#{updated} updated"]
  parts << "#{denied} skipped (permissions)" if denied > 0
  parts << "#{failed} failed (validation)" if failed > 0
  Actions::Result.new(success: true, message: parts.join(", ") + ".", redirect_to: nil, data: nil, errors: [])
end
```

#### `export` — Bulk Export

Exports selected records to CSV. Uses the presenter's `table_columns` to determine which fields to export.

```ruby
def batch_export(records)
  columns = @column_set.visible_table_columns
  csv = CSV.generate do |csv|
    csv << columns.map { |c| c["label"] || c["field"].to_s.humanize }
    records.each do |record|
      csv << columns.map { |c| @field_resolver.resolve(record, c["field"]) }
    end
  end

  Actions::Result.new(
    success: true,
    message: "Exported #{records.size} records.",
    redirect_to: nil,
    data: { csv: csv, filename: "#{current_presenter.name}_export_#{Date.current}.csv" },
    errors: []
  )
end
```

The `ActionsController#handle_result` already handles CSV data responses — it sends the file as a download.

### Selection Model

#### Single-Page Selection

The simplest model: checkboxes are per-page, and navigating to another page clears the selection. This covers the majority of use cases (most batch operations happen on a filtered, single-page view).

#### Cross-Page Selection

For large datasets, users may need to select records across multiple pages. This requires client-side state that persists across page navigations.

**Approach: `sessionStorage`-based ID set**

```javascript
// Selection state stored in sessionStorage, keyed by presenter slug
var STORAGE_KEY = "lcp_batch_" + presenterSlug;

function getSelectedIds() {
  var raw = sessionStorage.getItem(STORAGE_KEY);
  return raw ? JSON.parse(raw) : [];
}

function setSelectedIds(ids) {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(ids));
}
```

This survives page navigation (Turbo or full reload) but is cleared when the browser tab is closed — appropriate for a transient selection.

#### "Select All" Semantics

"Select all" has two reasonable interpretations:

1. **Select all on current page** — checks all visible checkboxes
2. **Select all matching current filter** — selects all records matching the current search/filter, even across pages

Option 1 is simpler and sufficient for the initial implementation. Option 2 requires a server roundtrip to get all matching IDs (or a "select all N matching records" banner like Gmail).

**Initial implementation: option 1 only.** A future enhancement can add a "Select all N records matching this filter" banner when the user checks the header checkbox on a paginated list.

### UI Components

#### Checkbox Column

A new leftmost column in the table with checkboxes:

```erb
<thead>
  <tr>
    <% if batch_actions_available? %>
      <th class="lcp-select-column">
        <input type="checkbox" class="lcp-select-all"
               data-batch-target="selectAll"
               title="Select all on this page">
      </th>
    <% end %>
    <%# ...existing columns... %>
  </tr>
</thead>
<tbody>
  <% @records.each do |record| %>
    <tr data-record-id="<%= record.id %>">
      <% if batch_actions_available? %>
        <td class="lcp-select-column">
          <input type="checkbox" class="lcp-select-row"
                 value="<%= record.id %>"
                 data-batch-target="rowCheckbox">
        </td>
      <% end %>
      <%# ...existing columns... %>
    </tr>
  <% end %>
</tbody>
```

The checkbox column is only rendered when the presenter has at least one batch action that the current user is permitted to execute.

#### Batch Action Toolbar

A toolbar that appears (slides in) when one or more records are selected:

```erb
<div class="lcp-batch-toolbar" data-batch-target="toolbar" hidden>
  <span class="lcp-batch-count">
    <span data-batch-target="count">0</span> selected
  </span>

  <div class="lcp-batch-actions">
    <% @action_set.batch_actions.each do |action| %>
      <button type="button"
              class="btn <%= 'btn-danger' if action['style'] == 'danger' %>"
              data-batch-action="<%= action['name'] %>"
              data-batch-url="<%= batch_action_path(action_name: action['name']) %>"
              data-confirm="<%= action['confirm'] %>"
              data-confirm-message="<%= action['confirm_message'] %>">
        <%= action["label"] || action["name"].humanize %>
      </button>
    <% end %>
  </div>

  <button type="button" class="btn btn-link lcp-batch-clear"
          data-batch-target="clearBtn">
    Clear selection
  </button>
</div>
```

**Toolbar positioning:** Fixed at the bottom of the viewport (sticky footer pattern), so it's always visible regardless of scroll position. This is the standard pattern in business applications (Gmail, Jira, etc.).

#### Interaction with Existing UI Elements

| Element | Behavior when selection active |
|---------|-------------------------------|
| **Row click** (navigate to show) | Disabled when checkboxes are visible — clicking the row toggles the checkbox instead. Users use the "show" single action link to navigate. |
| **Drag handles** (reorderable) | Hidden when batch toolbar is visible — reordering and batch selection are mutually exclusive modes. |
| **Single actions column** | Remains visible — users can still act on individual records even with a selection active. |
| **Pagination** | Works normally — selection persists via `sessionStorage` across pages. |
| **Search/filter** | Clears the selection — the selected IDs may no longer be in the result set after filtering. |

### JavaScript Implementation

Plain JavaScript, following the pattern of `index_sortable.js`:

```javascript
// app/assets/javascripts/lcp_ruby/batch_select.js

(function () {
  document.addEventListener("DOMContentLoaded", function () {
    var toolbar = document.querySelector(".lcp-batch-toolbar");
    if (!toolbar) return;

    var table = document.querySelector("table.lcp-table");
    var tbody = table ? table.querySelector("tbody") : null;
    if (!tbody) return;

    var selectAllCheckbox = document.querySelector(".lcp-select-all");
    var countDisplay = toolbar.querySelector("[data-batch-target='count']");
    var clearBtn = toolbar.querySelector("[data-batch-target='clearBtn']");
    var presenterSlug = document.querySelector("[data-presenter-slug]")
      ?.getAttribute("data-presenter-slug") || "default";
    var STORAGE_KEY = "lcp_batch_" + presenterSlug;

    // --- State ---

    function getSelectedIds() {
      try {
        return JSON.parse(sessionStorage.getItem(STORAGE_KEY) || "[]");
      } catch (e) {
        return [];
      }
    }

    function setSelectedIds(ids) {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(ids));
      updateUI();
    }

    // --- UI Updates ---

    function updateUI() {
      var ids = getSelectedIds();
      countDisplay.textContent = ids.length;
      toolbar.hidden = ids.length === 0;

      // Sync checkboxes with stored state
      var checkboxes = tbody.querySelectorAll(".lcp-select-row");
      checkboxes.forEach(function (cb) {
        cb.checked = ids.indexOf(cb.value) !== -1;
      });

      // Update select-all checkbox
      if (selectAllCheckbox) {
        var allOnPage = Array.from(checkboxes).map(function (cb) { return cb.value; });
        var allChecked = allOnPage.length > 0 && allOnPage.every(function (id) {
          return ids.indexOf(id) !== -1;
        });
        selectAllCheckbox.checked = allChecked;
        selectAllCheckbox.indeterminate = !allChecked && allOnPage.some(function (id) {
          return ids.indexOf(id) !== -1;
        });
      }

      // Disable row click when selection is active
      var rows = tbody.querySelectorAll("tr.lcp-row-clickable");
      rows.forEach(function (row) {
        if (ids.length > 0) {
          row.classList.add("lcp-row-select-mode");
        } else {
          row.classList.remove("lcp-row-select-mode");
        }
      });
    }

    // --- Event Handlers ---

    // Row checkbox toggle
    tbody.addEventListener("change", function (e) {
      if (!e.target.classList.contains("lcp-select-row")) return;
      var ids = getSelectedIds();
      var val = e.target.value;
      if (e.target.checked) {
        if (ids.indexOf(val) === -1) ids.push(val);
      } else {
        ids = ids.filter(function (id) { return id !== val; });
      }
      setSelectedIds(ids);
    });

    // Select all on current page
    if (selectAllCheckbox) {
      selectAllCheckbox.addEventListener("change", function () {
        var ids = getSelectedIds();
        var checkboxes = tbody.querySelectorAll(".lcp-select-row");
        checkboxes.forEach(function (cb) {
          if (selectAllCheckbox.checked) {
            if (ids.indexOf(cb.value) === -1) ids.push(cb.value);
          } else {
            ids = ids.filter(function (id) { return id !== cb.value; });
          }
        });
        setSelectedIds(ids);
      });
    }

    // Clear selection
    if (clearBtn) {
      clearBtn.addEventListener("click", function () {
        setSelectedIds([]);
      });
    }

    // Batch action button click
    toolbar.addEventListener("click", function (e) {
      var btn = e.target.closest("[data-batch-action]");
      if (!btn) return;

      var ids = getSelectedIds();
      if (ids.length === 0) return;

      // Confirmation
      if (btn.getAttribute("data-confirm") === "true") {
        var message = btn.getAttribute("data-confirm-message") || "Are you sure?";
        message = message.replace("%{count}", ids.length);
        if (!confirm(message)) return;
      }

      // Submit as form POST
      var url = btn.getAttribute("data-batch-url");
      var form = document.createElement("form");
      form.method = "POST";
      form.action = url;
      form.style.display = "none";

      // CSRF token
      var csrfToken = document.querySelector('meta[name="csrf-token"]');
      if (csrfToken) {
        var csrfInput = document.createElement("input");
        csrfInput.type = "hidden";
        csrfInput.name = "authenticity_token";
        csrfInput.value = csrfToken.getAttribute("content");
        form.appendChild(csrfInput);
      }

      // Record IDs
      ids.forEach(function (id) {
        var input = document.createElement("input");
        input.type = "hidden";
        input.name = "ids[]";
        input.value = id;
        form.appendChild(input);
      });

      document.body.appendChild(form);
      form.submit();

      // Clear selection after submission
      setSelectedIds([]);
    });

    // Initialize UI on page load (restore selection from sessionStorage)
    updateUI();

    // Clear selection when search/filter changes
    var searchForm = document.querySelector(".lcp-search-form");
    if (searchForm) {
      searchForm.addEventListener("submit", function () {
        setSelectedIds([]);
      });
    }
    var filterLinks = document.querySelectorAll(".lcp-filters .btn-filter");
    filterLinks.forEach(function (link) {
      link.addEventListener("click", function () {
        setSelectedIds([]);
      });
    });
  });
})();
```

### Permission Integration

Batch actions use the same permission system as single and collection actions:

```yaml
# permissions/deal.yml
permissions:
  model: deal
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      actions:
        allowed: all
    sales_rep:
      crud: [index, show, create, update]
      actions:
        allowed: [approve]              # can batch-approve but not batch-delete
```

**Two-level permission check:**

1. **Action-level** (in `ActionSet#batch_actions`): Does the user's role permit this batch action? Controlled by `can?(:destroy)` for built-in actions and `can_execute_action?(:approve)` for custom actions. If denied, the button is not rendered.

2. **Record-level** (in `ActionsController#execute_batch`): For each record in the batch, check `can_for_record?(:destroy, record)`. Records that fail the check are skipped, and the result message reports the skip count.

This matches the existing single-action pattern where `ActionSet` filters visible buttons and the controller enforces per-record rules.

### Interaction with Other Features

#### Soft Delete

When a model has `soft_delete: true`, the built-in `destroy` batch action calls `discard!` instead of `destroy!` on each record — same as the single-record destroy behavior. No special configuration needed.

For archive presenters (`scope: discarded`), the batch actions `restore` and `permanently_destroy` can be configured:

```yaml
# presenters/deals_archive.yml
presenter:
  name: deals_archive
  model: deal
  scope: discarded

  actions:
    batch:
      - { name: restore, type: built_in, label: "Restore Selected", icon: undo }
      - { name: permanently_destroy, type: built_in, label: "Delete Permanently", icon: trash, confirm: true, style: danger }
```

#### Auditing

Batch operations create **one audit log entry per record** — not one entry for the entire batch. This follows the principle from `model_options_infrastructure.md`: the audit trail is per-record, matching the database state.

For built-in `update` and `destroy` batch actions, audit entries are created automatically via the existing `after_save` / `after_destroy` callbacks. No special handling needed — the batch action loops over records and calls `update` / `destroy!` on each, which fires callbacks normally.

For soft delete's `discard!` (which uses `update_columns`), the explicit `AuditWriter.log` call in `SoftDeleteApplicator` handles audit tracking as defined in `model_options_infrastructure.md`.

#### Positioning

Batch selection and drag-and-drop reordering are **mutually exclusive modes**. When the table has batch checkboxes visible and a selection is active, drag handles are hidden. When the selection is cleared, drag handles reappear.

This avoids confusing UX where a user tries to reorder selected records (undefined behavior).

#### Pagination

Selection persists across pages via `sessionStorage`. The batch action toolbar shows the total count of selected records across all pages. When the user submits a batch action, all stored IDs are sent — including IDs from other pages.

**Edge case:** A record selected on page 1 may have been deleted by another user before the batch action is submitted. The controller handles this gracefully — `@model_class.where(id: ids)` returns only records that still exist. The result message reports the actual count.

### Custom Batch Actions (Host App)

Host apps define custom batch actions the same way as single custom actions, with `records` instead of `record`:

```ruby
# app/actions/deal/bulk_approve.rb
class Deal::BulkApprove < LcpRuby::Actions::BaseAction
  def call
    approved = 0
    skipped = 0

    records.each do |record|
      if record.stage == "qualified"
        record.update!(stage: "approved", approved_at: Time.current)
        approved += 1
      else
        skipped += 1
      end
    end

    success(message: "#{approved} deals approved, #{skipped} skipped (not qualified).")
  end

  def self.authorized?(record, user)
    user.lcp_role == "admin" || user.lcp_role == "manager"
  end
end
```

```yaml
# presenters/deals.yml
actions:
  batch:
    - name: bulk_approve
      type: custom
      label: "Approve Selected"
      icon: check-circle
      confirm: true
      confirm_message: "Approve %{count} selected deals?"
```

The existing `ActionsController#execute_batch` and `ActionExecutor` handle this — no changes needed.

### Batch Action with Parameters (Modal Form)

Some batch actions need user input before execution — e.g., bulk update needs to know which fields to change and to what values.

The `param_schema` class method on `BaseAction` already exists for this purpose. For batch actions, it works the same way:

```ruby
class Deal::BulkAssign < LcpRuby::Actions::BaseAction
  def self.param_schema
    {
      fields: [
        { name: "owner_id", type: "association_select", label: "Assign to", required: true,
          target_model: "user" }
      ]
    }
  end

  def call
    owner_id = params[:owner_id]
    records.update_all(owner_id: owner_id)
    success(message: "#{records.count} deals assigned.")
  end
end
```

When a batch action has `param_schema`, clicking the toolbar button opens a modal dialog with the specified fields. The form is submitted with both the selected IDs and the action parameters.

**Initial implementation:** The modal renders a simple form based on `param_schema`. A future enhancement could reuse the platform's form builder for full field rendering (validation, conditional visibility, etc.).

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Shift+Click` on checkbox | Select range (all rows between last checked and clicked) |
| `Escape` | Clear selection |

These follow standard list selection conventions.

## Implementation

### File Changes Summary

| File | Change |
|------|--------|
| `app/views/lcp_ruby/resources/index.html.erb` | Add checkbox column, batch toolbar, `data-presenter-slug` attribute |
| `app/assets/javascripts/lcp_ruby/batch_select.js` | **New** — checkbox state management, toolbar visibility, form submission |
| `app/assets/stylesheets/lcp_ruby/batch_select.css` | **New** — toolbar styling, checkbox column width, selection highlighting |
| `app/controllers/lcp_ruby/actions_controller.rb` | Add built-in batch action handling (destroy, update, export) |
| `app/controllers/lcp_ruby/resources_controller.rb` | Add `batch_actions_available?` helper |
| `lib/lcp_ruby/presenter/action_set.rb` | No changes needed — `batch_actions` method already exists |
| `lib/lcp_ruby/actions/base_action.rb` | No changes needed — `records` attribute already exists |
| `config/routes.rb` | No changes needed — `batch_actions` route already exists |

### New Files

| File | Purpose |
|------|---------|
| `app/assets/javascripts/lcp_ruby/batch_select.js` | Client-side selection state, toolbar interaction, form submission |
| `app/assets/stylesheets/lcp_ruby/batch_select.css` | Batch toolbar styling (sticky footer), checkbox column, selection row highlight |

### Controller Changes

#### `ActionsController#execute_batch`

Extend to handle built-in batch actions alongside custom ones:

```ruby
def execute_batch
  ids = params[:ids] || []
  records = load_batch_records(ids)
  action_name = params[:action_name]

  unless current_evaluator.can_execute_batch_action?(action_name)
    raise Pundit::NotAuthorizedError, "not allowed to execute batch action #{action_name}"
  end

  result = if built_in_batch_action?(action_name)
    execute_built_in_batch(action_name, records)
  else
    action_key = find_batch_action_key
    Actions::ActionExecutor.new(action_key, {
      records: records,
      current_user: current_user,
      params: action_params,
      model_class: @model_class
    }).execute
  end

  handle_result(result)
end

private

def load_batch_records(ids)
  scope = @model_class
  scope = scope.kept if current_model_definition.soft_delete? && !archive_presenter?
  scope.where(id: ids)
end

def built_in_batch_action?(name)
  %w[destroy update export restore permanently_destroy].include?(name)
end
```

#### `ResourcesController`

Add helper method for views:

```ruby
def batch_actions_available?
  @action_set.batch_actions.any?
end
helper_method :batch_actions_available?
```

### View Changes

#### `index.html.erb`

Add `data-presenter-slug` to the wrapper div (for sessionStorage keying):

```erb
<div class="lcp-resources-index" data-presenter-slug="<%= current_presenter.slug %>">
```

Add checkbox column to thead/tbody (see UI Components section above).

Add batch toolbar before the table (rendered hidden, shown by JavaScript).

### JSON Schema

Add batch action schema to `presenter.json`:

```json
"batch": {
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "name": { "type": "string" },
      "type": { "type": "string", "enum": ["built_in", "custom"] },
      "label": { "type": "string" },
      "icon": { "type": "string" },
      "style": { "type": "string", "enum": ["default", "danger", "warning"] },
      "confirm": { "type": "boolean" },
      "confirm_message": {
        "type": "string",
        "description": "Supports %{count} interpolation for selected record count"
      },
      "fields": {
        "type": "array",
        "items": { "type": "string" },
        "description": "For built-in update: which fields can be bulk-updated"
      },
      "action_class": {
        "type": "string",
        "description": "Override action class key (default: model/action_name)"
      },
      "visible_when": { "$ref": "#/definitions/condition" },
      "min_selection": {
        "type": "integer",
        "minimum": 1,
        "description": "Minimum records that must be selected (default: 1)"
      },
      "max_selection": {
        "type": "integer",
        "minimum": 1,
        "description": "Maximum records that can be selected (e.g., 2 for compare)"
      }
    },
    "required": ["name", "type"]
  }
}
```

### CSS

```css
/* Batch selection */
.lcp-select-column {
  width: 40px;
  text-align: center;
}

.lcp-select-row,
.lcp-select-all {
  cursor: pointer;
  width: 16px;
  height: 16px;
}

tr.lcp-selected {
  background-color: var(--lcp-selection-bg, #e8f0fe);
}

/* Row click disabled in select mode */
tr.lcp-row-select-mode {
  cursor: default;
}

/* Batch toolbar — sticky footer */
.lcp-batch-toolbar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--lcp-toolbar-bg, #fff);
  border-top: 1px solid var(--lcp-border-color, #dee2e6);
  padding: 12px 24px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
  z-index: 100;
  transition: transform 0.2s ease;
}

.lcp-batch-toolbar[hidden] {
  transform: translateY(100%);
}

.lcp-batch-count {
  font-weight: 600;
  white-space: nowrap;
}
```

## ConfigurationValidator

Add validation for batch actions in presenter validation:

```ruby
def validate_presenter_batch_actions(presenter)
  presenter.batch_actions.each do |action|
    action = action.transform_keys(&:to_s) if action.is_a?(Hash)
    next unless action.is_a?(Hash)

    # Validate built-in batch action names
    if action["type"] == "built_in"
      valid_built_in = %w[destroy update export restore permanently_destroy]
      unless valid_built_in.include?(action["name"])
        @errors << "Presenter '#{presenter.name}', batch action '#{action['name']}': " \
                   "unknown built-in batch action. Valid: #{valid_built_in.join(', ')}"
      end

      # restore/permanently_destroy require soft_delete on model
      if %w[restore permanently_destroy].include?(action["name"])
        model_def = loader.model_definitions[presenter.model]
        if model_def && !model_def.soft_delete?
          @errors << "Presenter '#{presenter.name}', batch action '#{action['name']}': " \
                     "requires model '#{presenter.model}' to have soft_delete enabled"
        end
      end
    end

    # Validate min/max selection
    min = action["min_selection"]
    max = action["max_selection"]
    if min && max && min > max
      @errors << "Presenter '#{presenter.name}', batch action '#{action['name']}': " \
                 "min_selection (#{min}) cannot be greater than max_selection (#{max})"
    end

    # Validate bulk update fields reference model fields
    if action["name"] == "update" && action["fields"]
      model_def = loader.model_definitions[presenter.model]
      if model_def
        field_names = model_def.fields.map(&:name)
        action["fields"].each do |f|
          unless field_names.include?(f.to_s)
            @errors << "Presenter '#{presenter.name}', batch update action: " \
                       "references unknown field '#{f}' on model '#{presenter.model}'"
          end
        end
      end
    end
  end
end
```

## Examples

### Basic Batch Delete and Export

```yaml
# presenters/orders.yml
presenter:
  name: orders
  model: order
  slug: orders

  actions:
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
    batch:
      - name: destroy
        type: built_in
        label: "Delete Selected"
        icon: trash
        confirm: true
        confirm_message: "Delete %{count} selected orders?"
        style: danger
      - name: export
        type: built_in
        label: "Export to CSV"
        icon: download
```

### Bulk Update with Field Selection

```yaml
# presenters/deals.yml
actions:
  batch:
    - name: update
      type: built_in
      label: "Update Selected"
      icon: pencil
      fields: [stage, owner_id]     # modal shows only these fields
```

### Custom Batch Action

```yaml
# presenters/invoices.yml
actions:
  batch:
    - name: bulk_send
      type: custom
      label: "Send Selected"
      icon: send
      confirm: true
      confirm_message: "Send %{count} invoices to their recipients?"
      min_selection: 1
```

```ruby
# app/actions/invoice/bulk_send.rb
class Invoice::BulkSend < LcpRuby::Actions::BaseAction
  def call
    sent = 0
    skipped = 0

    records.each do |invoice|
      if invoice.status == "approved" && invoice.recipient_email.present?
        InvoiceMailer.send_invoice(invoice).deliver_later
        invoice.update!(status: "sent", sent_at: Time.current)
        sent += 1
      else
        skipped += 1
      end
    end

    success(message: "#{sent} invoices sent, #{skipped} skipped.")
  end
end
```

### Archive Presenter with Batch Restore

```yaml
# presenters/deals_archive.yml
presenter:
  name: deals_archive
  model: deal
  scope: discarded

  actions:
    batch:
      - name: restore
        type: built_in
        label: "Restore Selected"
        icon: undo
        confirm: true
        confirm_message: "Restore %{count} deals from archive?"
      - name: permanently_destroy
        type: built_in
        label: "Delete Permanently"
        icon: trash
        confirm: true
        confirm_message: "Permanently delete %{count} deals? This cannot be undone."
        style: danger
```

## Test Plan

### Unit Tests

1. **ActionSet — batch_actions** — filters by permission; returns empty when no batch actions defined; respects `can_execute_action?`
2. **ConfigurationValidator — batch actions** — accepts valid built-in names; rejects unknown built-in names; errors on `restore` without soft_delete; validates min/max selection; validates update field references
3. **Batch select JavaScript** — checkbox toggle adds/removes ID from state; select-all checks all on page; clear empties state; toolbar visibility toggles with selection count; confirm dialog fires before destructive actions; `%{count}` interpolation in confirm message; sessionStorage persistence across page load; search/filter clears selection; shift-click selects range

### Integration Tests

4. **Batch destroy** — `POST /deals/batch_actions/destroy` with IDs deletes records; returns count in message; uses soft delete when model has `soft_delete: true`
5. **Batch destroy with record rules** — records denied by record-level rules are skipped; message reports skip count
6. **Batch export** — `POST /deals/batch_actions/export` returns CSV download with correct columns and data
7. **Batch custom action** — `POST /deals/batch_actions/bulk_approve` calls action class with `records`
8. **Permission denied** — batch action button not rendered for role without permission; POST returns 403
9. **Empty selection** — POST with empty `ids[]` returns success with "0 records" message (not an error)
10. **Cross-page selection** — IDs from page 1 are processed when batch action is submitted from page 2
11. **Deleted records** — IDs referencing deleted records are silently skipped (no error)
12. **Batch restore** — `POST /deals-archive/batch_actions/restore` undiscards selected records
13. **Batch permanently_destroy** — `POST /deals-archive/batch_actions/permanently_destroy` hard-deletes selected records

### Fixture Requirements

- Add `batch` actions to at least one presenter in integration fixtures
- Include both built-in (`destroy`, `export`) and custom batch actions
- Add a soft-deletable model with batch `restore` in archive presenter
- Add permission fixtures with roles that have/lack batch action access

## Open Questions

1. **Should bulk update use `update_all` or per-record `update`?** `update_all` is faster but bypasses validations, callbacks, and auditing. Per-record `update` respects all model logic but is slower for large batches. Recommendation: per-record `update` for correctness — batch sizes in UI are typically < 100 records. A future "background batch job" feature can use `update_all` with explicit audit logging for large-scale operations.

2. **Should the toolbar show on card/board views (not just table)?** The index view supports `table` and `cards` layouts. Checkboxes in cards are visually different (overlay checkbox on the card). Recommendation: start with table view only. Card view can be added later with a click-to-select interaction (no visible checkbox, but card gets a selected border).

3. **Should "Select all matching filter" be in the initial implementation?** This requires a server endpoint that returns all matching IDs for the current search/filter. Recommendation: defer — "select all on current page" covers the common case. Add the "select all N matching" banner as a follow-up when users report the need.

4. **Maximum batch size?** Sending 10,000 IDs in a form POST is technically possible but may cause issues (request body size, long execution time). Recommendation: set a configurable limit (default: 500) and show a warning when exceeded. The limit is enforced server-side.

5. **Should batch action results show per-record details?** For a batch of 50 records where 3 fail, should the result show which 3 failed and why? Recommendation: yes, but only in the JSON response (for API consumers). The HTML response shows a summary count. A future enhancement could show a "results" modal with per-record status.
