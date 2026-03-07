define_presenter :showcase_conditions do
  model :showcase_condition
  label "Advanced Conditions"
  slug "showcase-conditions"
  icon "filter"

  index do
    description "Demonstrates all advanced condition features: compound (all/any/not), dot-path fields, collection quantifiers, dynamic value references (field_ref, current_user, date, lookup), value services, and string operators."
    default_sort :created_at, :desc
    per_page 50
    row_click :show
    includes [ :showcase_condition_category, :showcase_condition_tasks ]

    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", active: "green", review: "blue", approved: "cyan", closed: "red" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
    }, sortable: true
    column :amount, renderer: :currency, options: { currency: "USD" }, sortable: true
    column :budget_limit, renderer: :currency, options: { currency: "USD" }
    column :code, renderer: :code
    column :due_date, renderer: :date

    # --- COMPOUND (all): overdue AND not done ---
    # Red highlight for active records past their due date
    item_class "lcp-row-danger", when: proc {
      all do
        field(:status).not_eq("closed")
        field(:status).not_eq("approved")
        field(:due_date).lt({ "date" => "today" })
        field(:due_date).present
      end
    }

    # --- COMPOUND (any): early-stage records get info background ---
    item_class "lcp-row-info", when: proc {
      any do
        field(:status).eq("draft")
        field(:status).eq("review")
      end
    }

    # --- NOT: closed records get muted + strikethrough ---
    item_class "lcp-row-muted lcp-row-strikethrough", when: proc {
      not_condition do
        field(:status).not_eq("closed")
      end
    }

    # --- DOT-PATH: unverified category → warning ---
    item_class "lcp-row-warning",
      when: { field: "showcase_condition_category.verified", operator: :eq, value: "false" }

    # --- FIELD_REF: amount exceeds budget_limit → bold ---
    item_class "lcp-row-bold",
      when: { field: :amount, operator: :gt, value: { "field_ref" => "budget_limit" } }

    # --- COLLECTION (any): has at least one approved task → success ---
    item_class "lcp-row-success", when: proc {
      collection(:showcase_condition_tasks, quantifier: :any) do
        field(:status).eq("approved")
      end
    }

    # --- STARTS_WITH: code starting with "URGENT" ---
    item_class "lcp-item-urgent-code",
      when: { field: :code, operator: :starts_with, value: "URGENT" }

    # --- CONTAINS: code containing "temp" (case-insensitive) ---
    item_class "lcp-item-temp-code",
      when: { field: :code, operator: :contains, value: "temp" }

    # --- LOOKUP: amount exceeds threshold from another model ---
    item_class "lcp-row-highlight",
      when: { field: :amount, operator: :gt,
              value: { "lookup" => "showcase_condition_threshold",
                       "match" => { "key" => "high_amount" },
                       "pick" => "threshold" } }
  end

  show do
    # --- COMPOUND visible_when: only show details when active or in review ---
    section "Overview", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", active: "green", review: "blue", approved: "cyan", closed: "red" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
      }
      field :code, renderer: :code
      field :due_date, renderer: :date
      field :author_id, renderer: :number
    end

    section "Financial Details", columns: 2,
      visible_when: proc {
        any do
          field(:status).eq("active")
          field(:status).eq("review")
          field(:status).eq("approved")
        end
      } do
      field :amount, renderer: :currency, options: { currency: "USD" }
      field :budget_limit, renderer: :currency, options: { currency: "USD" }
    end

    # --- DOT-PATH visible_when: show category info only when category is verified ---
    section "Category Info",
      visible_when: { field: "showcase_condition_category.verified", operator: :eq, value: "true" } do
      field "showcase_condition_category.name"
      field "showcase_condition_category.industry"
      field "showcase_condition_category.country_code"
    end

    section "Description" do
      field :description
    end
  end

  form do
    description "This form uses advanced conditions: compound visible_when/disable_when, field_ref comparisons, current_user references, and lookup value references."

    section "Basic Info", columns: 2 do
      field :title, placeholder: "Enter title...", autofocus: true
      field :status, input_type: :select
      field :priority, input_type: :select
      field :code, placeholder: "e.g. URGENT-001 or TEMP-draft"
      field :due_date, input_type: :date_picker
      field :author_id, input_type: :number, hint: "Set to your user ID to test current_user conditions."
      field :showcase_condition_category_id, input_type: :association_select
    end

    section "Financial", columns: 2 do
      field :amount, input_type: :number, prefix: "$",
        hint: "When amount exceeds budget_limit, the row appears bold on the index."
      field :budget_limit, input_type: :number, prefix: "$",
        hint: "Reference value for field_ref comparison."
    end

    # --- COMPOUND visible_when (all): description only visible for non-draft high-priority ---
    section "Description", columns: 1,
      visible_when: proc {
        all do
          field(:status).not_eq("draft")
          field(:priority).in("high", "critical")
        end
      } do
      field :description, input_type: :textarea, input_options: { rows: 4 },
        hint: "This section appears only when status is not 'draft' AND priority is 'high' or 'critical'."
    end

    # --- disable_when: disable budget override when status is closed ---
    section "Budget Override", columns: 2,
      disable_when: { field: :status, operator: :eq, value: "closed" } do
      info "This section is disabled when status is 'closed'. Budget cannot be modified on closed records."
      field :budget_limit, input_type: :number, prefix: "$"
    end
  end

  search do
    searchable_fields :title, :code, :description
    placeholder "Search advanced conditions demo..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single

  # --- COMPOUND visible_when on action: approve only when in review AND has approved tasks ---
  action :approve, type: :custom, on: :single,
    label: "Approve", icon: "check-circle",
    confirm: true, confirm_message: "Mark this record as approved?",
    style: :success,
    visible_when: proc {
      all do
        field(:status).eq("review")
        collection(:showcase_condition_tasks, quantifier: :any) do
          field(:status).eq("approved")
        end
      end
    }

  # --- Page-based confirmation dialog: user must provide a reason before deleting ---
  action :destroy, type: :built_in, on: :single,
    confirm: { page: "delete_reason_dialog" }, style: :danger,
    visible_when: proc {
      not_condition do
        field(:status).eq("closed")
      end
    }
end
