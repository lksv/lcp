define_presenter :activity do
  model :activity
  label "Activities"
  slug "activities"
  icon "activity"

  index do
    default_view :table
    default_sort :scheduled_at, :desc
    per_page 25
    row_click :show
    empty_message "No activities found"

    column :subject, width: "25%", link_to: :show, sortable: true, renderer: :truncate, options: { max: 40 }
    column :activity_type, width: "10%", renderer: :badge, options: {
      color_map: { call: "blue", meeting: "purple", email: "cyan", note: "gray", task: "orange" }
    }, sortable: true
    column "company.name", label: "Company", width: "15%", sortable: true
    column "contact.full_name", label: "Contact", width: "15%"
    column "deal.title", label: "Deal", width: "15%", renderer: :truncate, options: { max: 25 }
    column :scheduled_at, width: "12%", renderer: :datetime, sortable: true
    column :completed, width: "8%", renderer: :boolean_icon

    item_class "lcp-row-muted", when: { field: :completed, operator: :eq, value: true }
  end

  show do
    section "Activity Details", columns: 2, responsive: { mobile: { columns: 1 } } do
      field :subject, renderer: :heading
      field :activity_type, renderer: :badge, options: {
        color_map: { call: "blue", meeting: "purple", email: "cyan", note: "gray", task: "orange" }
      }
      field "company.name", label: "Company"
      field "contact.full_name", label: "Contact"
      field "deal.title", label: "Deal"
      field :scheduled_at, renderer: :datetime
      field :completed, renderer: :boolean_icon
      field :description
      field :created_by_name
      field :updated_by_name
    end

    section "Outcome", columns: 1,
      visible_when: { field: :completed, operator: :eq, value: true } do
      field :outcome
      field :completed_at, renderer: :datetime
    end
  end

  form do
    section "Activity Details", columns: 2 do
      field :subject, placeholder: "Activity subject...", autofocus: true, col_span: 2
      field :activity_type, input_type: :select
      field :description, input_type: :textarea
      field :company_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
      field :contact_id, input_type: :association_select,
        input_options: {
          depends_on: { field: :company_id, foreign_key: :company_id },
          sort: { last_name: :asc },
          label_method: :full_name
        },
        visible_when: { field: :activity_type, operator: :not_eq, value: "note" }
      field :deal_id, input_type: :association_select,
        input_options: {
          depends_on: { field: :company_id, foreign_key: :company_id },
          sort: { title: :asc },
          label_method: :title
        },
        visible_when: { field: :activity_type, operator: :not_in, value: %w[note] }
      field :scheduled_at, input_type: :datetime_picker
    end

    section "Completion", columns: 2 do
      field :completed, input_type: :toggle
      field :completed_at, input_type: :datetime_picker,
        visible_when: { field: :completed, operator: :eq, value: true }
      field :outcome, input_type: :textarea, col_span: 2,
        visible_when: { field: :completed, operator: :eq, value: true }
    end
  end

  search do
    searchable_fields :subject
    placeholder "Search activities..."
    filter :all, label: "All", default: true
    filter :pending, label: "Pending", scope: :pending
    filter :completed, label: "Completed", scope: :completed_activities

    advanced_filter do
      enabled true
      max_conditions 10
      max_nesting_depth 2
      max_association_depth 1
      allow_or_groups true
      query_language true

      filterable_fields :subject, :activity_type, :scheduled_at, :completed,
                        :completed_at, :created_at,
                        "company.name", "company.industry",
                        "contact.last_name",
                        "deal.title", "deal.stage"

      field_options :activity_type, operators: %i[eq not_eq in not_in]

      saved_filters do
        enabled true
        display :inline
        max_visible_pinned 4
      end
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Activity", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :complete, type: :custom, on: :single,
    label: "Mark Complete", icon: "check-circle",
    confirm: true,
    visible_when: { field: :completed, operator: :eq, value: false }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
