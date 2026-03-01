# Tier 1 — Design Details for 9 Easiest Items

## i18n Convention (applies to all items)

All user-visible text in the platform uses Rails i18n. No `label` keys in YAML — structure and text are separated.

**Lookup pattern:**

```ruby
# Built-in toolbar buttons, actions, system messages:
I18n.t("lcp_ruby.toolbar.copy_url", default: "Copy link")
I18n.t("lcp_ruby.toolbar.copied", default: "Copied!")
I18n.t("lcp_ruby.actions.show", default: "Show")

# Predefined filters — key derived from filter name:
I18n.t("lcp_ruby.filters.without_phone", default: "Without phone")

# Section titles — key derived from presenter + section name:
I18n.t("lcp_ruby.presenters.deal.sections.details", default: "Details")
```

The `default:` fallback is always the humanized name or a hardcoded English string. Host app overrides by adding keys to its locale files. No configuration in presenter YAML for labels/text.

**Locale file structure** (`config/locales/en.yml`):

```yaml
en:
  lcp_ruby:
    toolbar:
      back_to_list: "Back to list"
      copy_url: "Copy link"
      copied: "Copied!"
      copy_value: "Copy"
      copied_value: "Copied!"
    actions:
      show: "Show"
      edit: "Edit"
      delete: "Delete"
      create: "New"
      confirm_delete: "Are you sure?"
    empty_value: "—"
    errors:
      not_found: "Page not found"
      not_found_message: "The page you're looking for doesn't exist."
      record_not_found_message: "The record you're looking for doesn't exist or has been deleted."
```

---

## 1. Empty value display (configurable placeholder for null/empty fields)

### How it works

When a field value is `nil` or empty string, instead of rendering blank space, display a configurable placeholder text (e.g., "—").

### Configuration

Two levels — global engine default and per-presenter override:

```ruby
# Global engine default
LcpRuby.configure do |config|
  config.empty_value = "—"    # default: nil (= render nothing, current behavior)
end
```

```yaml
# Per-presenter override
presenter:
  name: deal
  options:
    empty_value: "—"
```

The displayed text comes from i18n:

```ruby
I18n.t("lcp_ruby.empty_value", default: resolved_empty_value)
```

### Implementation

Apply empty_value check only in the **no-renderer fallback** path (both in index and show templates). Renderers keep their own nil handling — this is intentional, each renderer decides how to display nil.

In index template and show template, change the raw `<%= value %>` fallback:

```erb
<% if value.nil? || (value.respond_to?(:blank?) && value.blank? && !value.is_a?(FalseClass)) %>
  <% placeholder = current_presenter.options&.dig("empty_value") || LcpRuby.configuration.empty_value %>
  <% if placeholder %>
    <span class="lcp-empty-value"><%= t("lcp_ruby.empty_value", default: placeholder) %></span>
  <% end %>
<% else %>
  <%= value %>
<% end %>
```

### Edge cases

- **`false` vs `nil`** — boolean `false` is not empty. The check excludes `FalseClass`. `BooleanIcon` renderer handles this correctly already (renders "No").
- **`0` and `0.0`** — valid values, not empty. `blank?` returns `false` for numbers, so they pass through.
- **Empty arrays** (`[]`) — `[].blank?` is `true`, so they show the placeholder. Correct.
- **Whitespace-only strings** — `"   ".blank?` is `true`, so they show the placeholder. Correct.
- **Renderers with nil values** — e.g., `date` renderer on a nil date. Not affected — renderers handle nil themselves. If a renderer returns nil/blank, the template outputs nothing. This is the renderer's responsibility to handle well (and a separate improvement if needed).

### Drawbacks

- Does not apply to fields with renderers. Each renderer should decide its own nil display independently.

---

## 2. Copy URL to clipboard ("Share link" button)

### How it works

A button on the show page that copies the current page URL to the clipboard. Visual feedback changes the button text/icon to "Copied!" for 2 seconds.

### Configuration

Always visible on show page by default. Can be disabled per presenter:

```yaml
show:
  copy_url: false    # default: true
```

### Implementation

In `show.html.erb` toolbar:

```erb
<% unless current_presenter.show_config["copy_url"] == false %>
  <button type="button" class="btn lcp-copy-url"
          data-url="<%= request.original_url %>"
          data-copied-text="<%= t('lcp_ruby.toolbar.copied') %>"
          title="<%= t('lcp_ruby.toolbar.copy_url') %>">
    <%= t("lcp_ruby.toolbar.copy_url") %>
  </button>
<% end %>
```

JavaScript (add to `ui_components.js`):

```javascript
document.addEventListener('click', function(e) {
  var btn = e.target.closest('.lcp-copy-url');
  if (!btn) return;
  var url = btn.getAttribute('data-url') || window.location.href;
  var originalText = btn.textContent;
  var copiedText = btn.getAttribute('data-copied-text') || 'Copied!';

  navigator.clipboard.writeText(url).then(function() {
    btn.textContent = copiedText;
    setTimeout(function() { btn.textContent = originalText; }, 2000);
  });
});
```

### Edge cases

- **`navigator.clipboard` unavailable** (HTTP, older browsers) — hide the button when clipboard API is not available: `if (!navigator.clipboard) btn.style.display = 'none'`.
- **URL with query params** (filter, page, sort) — copies the full URL including params. Correct behavior — recipient sees the same view.

### Drawbacks

- None significant. Pure frontend, no backend changes.

---

## 3. Copy-to-clipboard on field values

### How it works

A small copy icon appears next to field values on the show page. Clicking copies the raw value (not rendered HTML) to the clipboard.

### Configuration

Per-field opt-in in presenter:

```yaml
show:
  layout:
    - section: "Details"
      fields:
        - { field: email, renderer: email_link, copyable: true }
        - { field: api_key, copyable: true }
```

### Implementation

In `show.html.erb`, after the field value:

```erb
<div class="lcp-field-value">
  <%= rendered_value %>
  <% if field_config["copyable"] && !@current_evaluator.field_masked?(field_name) %>
    <button type="button" class="lcp-copy-value"
            data-value="<%= value.is_a?(Array) ? value.join(', ') : strip_tags(value.to_s) %>"
            data-copied-text="<%= t('lcp_ruby.toolbar.copied_value') %>"
            title="<%= t('lcp_ruby.toolbar.copy_value') %>">
      <span class="lcp-icon lcp-icon-copy"></span>
    </button>
  <% end %>
</div>
```

Same JS pattern as #2, but copies `data-value`.

### Edge cases

- **Rich text / HTML values** — `data-value` uses `strip_tags(value.to_s)` to get plain text.
- **Array values** — comma-separated: `value.join(", ")`.
- **Masked fields** — `field_masked?` check hides the copy button. Users must not be able to copy masked data.
- **Nil values** — if value is nil, the copy button is useless. Hide it when value is blank: add `&& value.present?` to the condition.

### Drawbacks

- Adds visual clutter if enabled on many fields. Best used on fields where copying is genuinely useful (emails, URLs, codes, IDs).

---

## 4. Sticky table header / sidebar

### How it works

The table header row (`<thead>`) stays fixed at the top when scrolling a long table. The sidebar stays fixed when scrolling the main content.

### Configuration

None. Always active. Host app can override via CSS.

### Implementation

Pure CSS in `application.css`:

```css
/* Sticky table header */
.lcp-table thead th {
  position: sticky;
  top: 0;
  z-index: 10;
  background: var(--lcp-bg-color, #fff);
}

/* Sticky sidebar */
.lcp-layout-with-sidebar .lcp-sidebar {
  position: sticky;
  top: 0;
  height: 100vh;
  overflow-y: auto;
}
```

### Edge cases

- **Nested scroll containers** — `position: sticky` only works relative to the nearest scrolling ancestor. If the table is inside an `overflow: auto` container, sticky won't work relative to the viewport. The current layout does not wrap `.lcp-table` in such a container, so this works out of the box.
- **Table with horizontal scroll** — if the table is wider than the viewport and needs `overflow-x: auto` on a wrapper, the sticky header still works vertically inside the wrapper. Both scroll axes function independently.
- **`z-index` conflicts** — `z-index: 10` for thead is safely below modals (1000+) and dropdowns (100+).

### Drawbacks

- None practical. The only concern is that a very tall header with many columns takes vertical space when stuck, but column labels are typically short.

---

## 5. NULL / empty value as filter condition

### How it works

Allow filtering records where a specific field is NULL/empty via predefined filter scopes.

### Configuration

```yaml
# Model YAML — define scopes
scopes:
  - name: without_phone
    where: { phone: null }
  - name: with_phone
    where_not: { phone: null }

# Presenter YAML — reference as predefined filter
search:
  predefined_filters:
    - { name: without_phone, scope: without_phone }
    - { name: with_phone, scope: with_phone }
```

Filter label comes from i18n:

```ruby
I18n.t("lcp_ruby.filters.without_phone", default: "Without phone")
```

### Current state

This **likely already works**. YAML parses `null` as Ruby `nil`. `ScopeApplicator` passes the hash to `where()`, and ActiveRecord generates `WHERE phone IS NULL` for `where(phone: nil)`.

### Implementation

1. Verify with a test that `where: { phone: null }` works end-to-end.
2. If it works, add documentation and test coverage.
3. If not (e.g., `ScopeApplicator` filters out nil values), fix the nil passthrough.

### Edge cases

- **Empty string vs NULL** — `where(phone: nil)` matches only SQL NULL, not `""`. For a "truly empty" filter, use: `where(phone: [nil, ""])`. This also already works with AR — `[nil, ""]` generates `WHERE phone IS NULL OR phone = ''`.
- **Boolean fields** — `where(active: nil)` is valid for three-state booleans (true/false/null). Works correctly.

### Drawbacks

- None. This is likely a documentation-only task.

---

## 6. Catch-all / fallback route (custom 404 page)

### How it works

When a user navigates to a URL with an unknown presenter slug, show a user-friendly 404 page instead of a Rails error.

### Configuration

```ruby
LcpRuby.configure do |config|
  config.not_found_handler = :default    # built-in 404 page (default)
  # config.not_found_handler = :raise    # raise RoutingError (let host app handle)
end
```

### Implementation

No catch-all route needed. The engine's `set_presenter_and_model` already raises `MetadataError` when a slug is not found. Handle it gracefully:

```ruby
def set_presenter_and_model
  slug = params[:lcp_slug]
  return unless slug

  @presenter_definition = Presenter::Resolver.find_by_slug(slug)
rescue MetadataError
  if LcpRuby.configuration.not_found_handler == :raise
    raise ActionController::RoutingError, "No page found at /#{slug}"
  else
    flash.now[:alert] = t("lcp_ruby.errors.not_found_message")
    render "lcp_ruby/errors/not_found", status: :not_found
  end
end
```

Create `app/views/lcp_ruby/errors/not_found.html.erb`:

```erb
<div class="lcp-error-page">
  <h1>404</h1>
  <p><%= flash[:alert] %></p>
</div>
```

The same pattern applies to record not found (`ActiveRecord::RecordNotFound` in show/edit/update/destroy):

```ruby
rescue ActiveRecord::RecordNotFound
  flash[:alert] = t("lcp_ruby.errors.record_not_found_message")
  redirect_to resources_path
end
```

### Edge cases

- **Engine mounted at sub-path** (`/admin`) — the 404 page's back link should go to the engine root, not `/`. Use the first available presenter's path or `lcp_ruby.root_path` if defined.

### Drawbacks

- Minimal. The `:raise` option lets host apps with custom error handling take over.

---

## 7. Configurable redirect after CRUD actions

### How it works

After a successful create/update/destroy, redirect to a configurable target instead of the hardcoded default (create/update → show, destroy → index).

### Configuration

```yaml
presenter:
  name: deal
  options:
    redirect_after:
      create: index     # after create → go to list (default: show)
      update: index     # after update → go to list (default: show)
```

Allowed values: `index`, `show`, `edit`, `new`. Destroy always goes to `index`.

### Implementation

```ruby
# In ResourcesController

def create
  # ... existing code ...
  if @record.errors.none? && @record.save
    redirect_to redirect_path_for(:create, @record),
                notice: t("lcp_ruby.flash.created", model: current_model_definition.label)
  else
    # ...
  end
end

private

def redirect_path_for(action, record = nil)
  target = current_presenter.options&.dig("redirect_after", action.to_s)

  case target
  when "index" then resources_path
  when "edit"  then edit_resource_path(record)
  when "new"   then new_resource_path
  when "show"  then resource_path(record)
  else
    # Default behavior
    action == :destroy ? resources_path : resource_path(record)
  end
end
```

Note: flash messages also move to i18n:

```yaml
en:
  lcp_ruby:
    flash:
      created: "%{model} was successfully created."
      updated: "%{model} was successfully updated."
      deleted: "%{model} was successfully deleted."
```

### Edge cases

- **Destroy → show** — makes no sense (record deleted). `redirect_path_for` ignores destroy config and always returns `resources_path`.
- **Create → edit** — useful pattern (create, then immediately edit to fill more details).

### Drawbacks

- None significant. The `redirect_path_for` method is trivial.

---

## 8. Item sorting in selectbox

### How it works

Enum select fields display options in a configurable order. Association selects already support `sort` via `input_options`.

### Configuration

```yaml
form:
  sections:
    - fields:
        - field: priority
          input_type: select
          input_options:
            sort: alphabetical     # "alphabetical" | "reverse" | omitted (= definition order)
```

### Implementation

In `FormHelper`, add sorting to enum option generation:

```ruby
def enum_options(field_def, input_options)
  options = field_def.enum_values.map { |v| [v["label"] || v["value"], v["value"]] }

  case input_options&.dig("sort")
  when "alphabetical"
    options.sort_by! { |label, _| label.to_s.downcase }
  when "reverse"
    options.reverse!
  end

  options
end
```

### Edge cases

- **Blank/nil placeholder** ("-- Select --") — should always be first, regardless of sort. The placeholder is added separately by the `select_tag` helper, not as part of `options`, so sorting doesn't affect it.
- **Tom Select** — respects initial option order from server. When user types a search, Tom Select sorts by match relevance (its own behavior, not affected by our sorting).
- **i18n for enum labels** — enum values with translated labels should sort by the translated text. If `v["label"]` comes from i18n in the future, sorting will automatically use the translated text since we sort on the `label` tuple element.

### Drawbacks

- Minimal. A few lines added to `FormHelper`.

---

## 9. Debounce / throttle on search requests

### How it works

When typing in the search field, the form auto-submits after the user stops typing for 300ms. Reduces unnecessary requests during fast typing.

### Current state

Search uses a standard HTML form — user must press Enter or click "Search". No auto-search exists. Debounce is used internally in `conditional_rendering.js` for service conditions, but not for search.

### Configuration

```yaml
search:
  enabled: true
  auto_search: true         # default: false — opt-in
  debounce_ms: 300          # default: 300
  min_query_length: 2       # default: 2
```

### Implementation

Data attributes on the search form:

```erb
<%= form_tag resources_path, method: :get, class: "lcp-search-form",
    data: {
      "lcp-auto-search": search_config["auto_search"],
      "lcp-debounce": search_config["debounce_ms"] || 300,
      "lcp-min-query": search_config["min_query_length"] || 2
    } do %>
  <input type="hidden" name="filter" value="<%= params[:filter] %>" />
  <%= text_field_tag :q, params[:q], placeholder: t("lcp_ruby.search.placeholder", default: "Search...") %>
  <%= submit_tag t("lcp_ruby.search.submit", default: "Search"), class: "btn" %>
<% end %>
```

Note: hidden `filter` field preserves the active predefined filter during auto-search.

JavaScript (new `search.js` or added to `application.js`):

```javascript
document.querySelectorAll('.lcp-search-form[data-lcp-auto-search="true"]').forEach(function(form) {
  var input = form.querySelector('input[name="q"]');
  if (!input) return;

  var debounceMs = parseInt(form.getAttribute('data-lcp-debounce')) || 300;
  var minLength = parseInt(form.getAttribute('data-lcp-min-query')) || 2;
  var timer = null;

  input.addEventListener('input', function() {
    clearTimeout(timer);
    var q = input.value.trim();
    if (q.length >= minLength || q.length === 0) {
      timer = setTimeout(function() { form.submit(); }, debounceMs);
    }
  });
});
```

### Edge cases

- **Full page reload on each submit** — standard GET form submission causes full page reload. Acceptable for server-rendered apps, but noticeable page flash. Future improvement: Turbo Frames / HTMX for partial updates (larger architectural change, out of scope here).
- **`q.length === 0`** — clearing the search field triggers a search (removes the filter) after debounce. Correct behavior.
- **Predefined filter preservation** — the hidden `<input name="filter">` ensures the active filter is not lost during auto-search.
- **Mobile** — auto-search on typing can be annoying with virtual keyboards. The opt-in default (`auto_search: false`) addresses this — enable it only on presenters where it makes sense.

### Drawbacks

- **Full page reload** on every debounced submission. For this reason, `auto_search` defaults to `false`. The standard Enter/click behavior remains the default.
