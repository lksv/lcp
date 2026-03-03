define_presenter :leave_request do
  model :leave_request
  label "Leave Requests"
  slug "leave-requests"
  icon "calendar-plus"
  redirect_after create: :index

  index do
    default_sort :created_at, :desc
    per_page 25
    row_click :show
    actions_position :dropdown

    column "employee.full_name", label: "Employee", width: "20%", sortable: true
    column "leave_type.name", label: "Leave Type", width: "15%", sortable: true
    column :start_date, width: "12%", renderer: :date, sortable: true
    column :end_date, width: "12%", renderer: :date, sortable: true
    column :days_count, width: "8%"
    column :status, width: "12%", renderer: :badge, options: { color_map: { draft: "gray", pending: "yellow", approved: "green", rejected: "red", cancelled: "gray" } }, sortable: true
  end

  show do
    section "Request Details", columns: 2 do
      field :status, renderer: :status_timeline, options: { steps: %w[draft pending approved] }
      field "employee.full_name", label: "Employee", renderer: :internal_link
      field "leave_type.name", label: "Leave Type"
      field :start_date, renderer: :date
      field :end_date, renderer: :date
      field :days_count
      field :reason
      field :rejection_note, visible_when: { field: :status, operator: :eq, value: "rejected" }
      field "approved_by.full_name", label: "Approved By", renderer: :internal_link
      field :approved_at, renderer: :relative_date
      field :attachment, renderer: :attachment_preview
    end

    section "Audit History" do
    end
  end

  form do
    section "Leave Request", columns: 2 do
      field :employee_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :leave_type_id, input_type: :association_select,
        input_options: { sort: { name: :asc } }
      field :start_date, input_type: :date
      field :end_date, input_type: :date
      field :days_count, input_type: :number, readonly: true
      field :reason, input_type: :textarea
      field :attachment
      info "Attach supporting documents if required by leave type"
    end
  end

  search do
    searchable_fields :reason
    placeholder "Search leave requests..."

    filter :all, label: "All", default: true
    filter :pending, label: "Pending", scope: :pending
    filter :approved, label: "Approved", scope: :approved

    advanced_filter do
      enabled true
      allow_or_groups true
      query_language true

      filterable_fields "employee.full_name", "leave_type.name", :status,
                        :start_date, :end_date, :days_count

      field_options :status, operators: %i[eq not_eq in not_in]
      field_options :start_date, operators: %i[gt lt eq present blank]
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Request", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :submit, type: :custom, on: :single, label: "Submit", icon: "send",
    visible_when: { field: :status, operator: :eq, value: "draft" }
  action :approve, type: :custom, on: :single, label: "Approve", icon: "check-circle",
    visible_when: { field: :status, operator: :eq, value: "pending" }
  action :reject, type: :custom, on: :single, label: "Reject", icon: "x-circle", style: :danger,
    visible_when: { field: :status, operator: :eq, value: "pending" }
  action :cancel, type: :custom, on: :single, label: "Cancel", icon: "x",
    visible_when: { field: :status, operator: :in, value: %w[draft pending] }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
