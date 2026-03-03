define_presenter :expense_claim do
  model :expense_claim
  label "Expense Claims"
  slug "expense-claims"
  icon "credit-card"
  redirect_after create: :show

  index do
    actions_position :dropdown

    column :title, link_to: :show
    column "employee.full_name"
    column :amount, renderer: :currency, options: { currency: "CZK" }
    column :category, renderer: :badge
    column :status, renderer: :badge, options: { color_map: { draft: "gray", submitted: "yellow", approved: "green", rejected: "red", reimbursed: "blue" } }
    column :expense_date, renderer: :date
  end

  show do
    section "Claim Details", columns: 2 do
      field :title, renderer: :heading
      field "employee.full_name"
      field :description
      field :amount, renderer: :currency, options: { currency: "CZK" }
      field :currency
      field :category, renderer: :badge
      field :status, renderer: :badge
      field :receipt, renderer: :attachment_list
      field :expense_date
      field "approved_by.full_name", label: "Approved by", renderer: :internal_link
      field :approved_at, renderer: :datetime
      field :rejection_note,
        visible_when: { field: :status, operator: :eq, value: "rejected" }
      field :items
    end

  end

  form do
    layout :tabs

    section "Claim Details", columns: 2 do
      field :title, autofocus: true
      field :description, input_type: :textarea
      field :employee_id, input_type: :association_select
      field :category, input_type: :select
      field :expense_date, input_type: :date_picker
      field :amount, input_type: :number, prefix: "CZK"
      field :currency, input_type: :select
      field :receipt, input_options: { preview: true, drag_drop: true }
    end

    section "Line Items" do
      field :items, input_type: :textarea
    end
  end

  search do
    filter :all, label: "All", default: true
    filter :pending, label: "Pending", scope: :pending
    filter :approved, label: "Approved", scope: :approved
  end

  action :create, type: :built_in, on: :collection, label: "New Claim", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :submit, type: :custom, on: :single,
    label: "Submit",
    visible_when: { field: :status, operator: :eq, value: "draft" }
  action :approve, type: :custom, on: :single,
    label: "Approve",
    visible_when: { field: :status, operator: :eq, value: "submitted" }
  action :reject, type: :custom, on: :single,
    label: "Reject", style: :danger,
    visible_when: { field: :status, operator: :eq, value: "submitted" }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
