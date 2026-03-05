define_presenter :showcase_item_classes do
  model :showcase_item_class
  label "Row Styling (item_classes)"
  slug "showcase-item-classes"
  icon "palette"

  index do
    description "Demonstrates all item_classes use-cases: every built-in CSS class, every condition operator, service conditions, multiple classes per rule, and rule accumulation. Each row is styled based on its field values."
    default_sort :name, :asc
    per_page 50
    row_click :show

    column :name, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { active: "green", completed: "blue", cancelled: "red", on_hold: "orange", draft: "gray" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
    }, sortable: true
    column :score, renderer: :number, sortable: true
    column :amount, renderer: :currency, options: { currency: "USD" }, sortable: true
    column :code, renderer: :code
    column :email, renderer: :email_link
    column :notes, renderer: :truncate, options: { max: 30 }
    column :due_date, renderer: :date

    # --- USE CASE 1: eq operator + lcp-row-muted + lcp-row-strikethrough (multiple classes per rule) ---
    # Cancelled records are grayed out and crossed through
    item_class "lcp-row-muted lcp-row-strikethrough",
      when: { field: :status, operator: :eq, value: "cancelled" }

    # --- USE CASE 2: eq operator + lcp-row-success ---
    # Completed records get a green background
    item_class "lcp-row-success",
      when: { field: :status, operator: :eq, value: "completed" }

    # --- USE CASE 3: eq operator + lcp-row-danger ---
    # Critical priority records get a red background
    item_class "lcp-row-danger",
      when: { field: :priority, operator: :eq, value: "critical" }

    # --- USE CASE 4: eq operator + lcp-row-warning ---
    # On-hold records get a yellow background
    item_class "lcp-row-warning",
      when: { field: :status, operator: :eq, value: "on_hold" }

    # --- USE CASE 5: eq operator + lcp-row-bold ---
    # High priority records are bold
    item_class "lcp-row-bold",
      when: { field: :priority, operator: :eq, value: "high" }

    # --- USE CASE 6: gt operator (numeric comparison) + lcp-row-info ---
    # High-score records (> 90) get a blue background
    item_class "lcp-row-info",
      when: { field: :score, operator: :gt, value: 90 }

    # --- USE CASE 7: lt operator (numeric comparison) ---
    # Low-score records (< 20) get a custom CSS class
    item_class "lcp-item-low-score",
      when: { field: :score, operator: :lt, value: 20 }

    # --- USE CASE 8: blank operator (presence check) ---
    # Records without notes get a subtle visual cue
    item_class "lcp-item-missing-notes",
      when: { field: :notes, operator: :blank }

    # --- USE CASE 9: matches operator (regex on string field) ---
    # Records with code starting with "TEMP" get highlighted
    item_class "lcp-item-temp-code",
      when: { field: :code, operator: :matches, value: "^TEMP" }

    # --- USE CASE 10: service condition (server-side logic) ---
    # Overdue records (due_date < today) get a danger highlight
    item_class "lcp-item-overdue",
      when: { service: :overdue_check }
  end

  show do
    section "Record Details", columns: 2 do
      field :name, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { active: "green", completed: "blue", cancelled: "red", on_hold: "orange", draft: "gray" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
      }
      field :score, renderer: :number
      field :amount, renderer: :currency, options: { currency: "USD" }
      field :code, renderer: :code
      field :email, renderer: :email_link
      field :notes
      field :due_date, renderer: :date
    end
  end

  form do
    section "Record Details", columns: 2 do
      field :name, placeholder: "Record name...", autofocus: true
      field :status, input_type: :select
      field :priority, input_type: :select
      field :score, input_type: :number, hint: "0-100 scale. Rows with score > 90 get blue (info) highlight, < 20 get custom class."
      field :amount, input_type: :number, prefix: "$"
      field :code, placeholder: "e.g. TEMP-001 or PROD-042", hint: "Codes starting with TEMP get custom highlight."
      field :email
      field :notes, input_type: :textarea, input_options: { rows: 3 }, hint: "Leave blank to see the missing-notes custom class."
      field :due_date, input_type: :date_picker, hint: "Set a past date to trigger the overdue service condition."
    end
  end

  search do
    searchable_fields :name, :code, :email
    placeholder "Search row styling demo..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
