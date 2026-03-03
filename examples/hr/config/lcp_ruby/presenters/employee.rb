define_presenter :employee do
  model :employee
  label "Employees"
  slug "employees"
  icon "users"
  redirect_after create: :show

  index do
    default_sort :last_name, :asc
    per_page 25
    row_click :show
    description "Manage employee records and personnel information"
    empty_message "No employees found"

    column :photo, width: "5%", renderer: :avatar, options: { variant: "thumbnail", initials_fields: ["first_name", "last_name"] }
    column :full_name, width: "20%", link_to: :show, sortable: true, pinned: :left
    column "organization_unit.name", label: "Organization Unit", width: "15%", renderer: :internal_link, sortable: true
    column "position.title", label: "Position", width: "12%", sortable: true
    column :status, width: "10%", renderer: :badge, options: { color_map: { active: "green", on_leave: "yellow", suspended: "orange", terminated: "red" } }, sortable: true
    column :work_email, width: "15%", renderer: :email_link
    column :phone, width: "10%", renderer: :phone_link, hidden_on: [:mobile]
    column :hire_date, width: "8%", renderer: :relative_date, sortable: true
    column :salary, width: "10%", renderer: :currency, options: { currency: "CZK" }, hidden_on: [:mobile], summary: :sum
  end

  show do
    copy_url true

    section "Overview", columns: 2, responsive: { mobile: { columns: 1 } } do
      field :photo, renderer: :avatar, options: { variant: "medium", initials_fields: ["first_name", "last_name"] }
      field :full_name, renderer: :heading
      field :status, renderer: :badge, options: { color_map: { active: "green", on_leave: "yellow", suspended: "orange", terminated: "red" } }
      field "organization_unit.name", label: "Organization Unit", renderer: :internal_link, copyable: true
      field "position.title", label: "Position"
      field :work_email, renderer: :email_link, copyable: true
      field :phone, renderer: :phone_link, copyable: true
      field :hire_date, renderer: :date
      field "manager.full_name", label: "Manager", renderer: :internal_link
      field :created_by_name, label: "Created By"
      field :updated_by_name, label: "Updated By"
    end

    section "Employment", columns: 2 do
      field :employment_type, renderer: :enum
      field :salary, renderer: :currency, options: { currency: "CZK" }
      field :currency
      field :hire_date, renderer: :date
      field :termination_date, renderer: :date, visible_when: { field: :status, operator: :eq, value: "terminated" }
      info "Salary information is restricted by role"
    end

    association_list "Leave Balances", association: :leave_balances, limit: 6, display_template: :default
    association_list "Leave Requests", association: :leave_requests, scope: :recent, limit: 10, sort: { created_at: :desc }, display_template: :default

    association_list "Performance Reviews", association: :performance_reviews, limit: 5, sort: { year: :desc }
    association_list "Goals", association: :goals, limit: 10

    association_list "Skills", association: :employee_skills, limit: 20

    association_list "Asset Assignments", association: :asset_assignments, display_template: :default
    association_list "Documents", association: :documents, limit: 10

    section "Emergency Contact", columns: 2 do
      field "emergency_contact.name", label: "Contact Name"
      field "emergency_contact.phone", label: "Contact Phone"
      field "emergency_contact.relationship", label: "Relationship"
    end

    section "Audit History" do
    end
  end

  form do
    layout :tabs

    section "Personal", columns: 2 do
      field :first_name, autofocus: true
      field :last_name
      field :date_of_birth, input_type: :date
      field :gender, input_type: :select
      field :photo, input_options: { preview: true, drag_drop: true }
      field :cv, hint: "PDF only, max 10MB"
    end

    section "Employment", columns: 2 do
      field :organization_unit_id, input_type: :tree_select
      field :position_id, input_type: :tree_select
      field :manager_id, input_type: :association_select,
        input_options: {
          depends_on: { field: :organization_unit_id, foreign_key: :organization_unit_id },
          sort: { full_name: :asc }
        }
      field :status, input_type: :select
      field :employment_type, input_type: :select
      field :hire_date, input_type: :date
      field :termination_date, input_type: :date, visible_when: { field: :status, operator: :eq, value: "terminated" }
      field :salary, input_type: :number, prefix: "CZK", hint: "Annual gross salary",
        disable_when: { service: :is_own_record }
      field :currency, input_type: :select
    end

    section "Contact", columns: 2 do
      field :work_email
      field :personal_email
      field :phone
      divider
      field "address.street", label: "Street"
      field "address.city", label: "City"
      field "address.zip", label: "ZIP"
      field "address.country", label: "Country"
      divider
      field "emergency_contact.name", label: "Emergency Contact Name"
      field "emergency_contact.phone", label: "Emergency Contact Phone"
      field "emergency_contact.relationship", label: "Relationship"
      info "Contact information is only visible to HR staff and the employee"
    end

    section "Notes" do
      field :notes, input_type: :rich_text, col_span: 2
    end
  end

  search do
    searchable_fields :full_name, :work_email
    placeholder "Search employees..."
    auto_search true
    debounce_ms 300

    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active
    filter :on_leave, label: "On Leave", scope: :on_leave
    filter :terminated, label: "Terminated", scope: :terminated

    advanced_filter do
      enabled true
      allow_or_groups true
      max_association_depth 2
      query_language true

      filterable_fields :full_name, :status, :employment_type, :hire_date,
                        "organization_unit.name", "position.title", :salary

      field_options :salary, operators: %i[gt gteq lt lteq eq]
      field_options :hire_date, operators: %i[gt lt eq present blank]

      preset :new_hires,
        label: "New Hires (Last 90 Days)",
        conditions: [
          { field: "status", operator: "eq", value: "active" }
        ]

      preset :high_salary,
        label: "High Salary",
        conditions: [
          { field: "salary", operator: "gt", value: "100000" }
        ]
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Employee", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true,
    confirm_message: "This will soft-delete the employee record. Use the archive to restore.",
    style: :danger
end
