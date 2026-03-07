define_presenter :employee_quick_add_dialog do
  model :employee

  dialog size: :small, title_key: "lcp_ruby.dialogs.quick_add_employee_title"

  form do
    section "New Employee" do
      field :name, autofocus: true, placeholder: "Employee name..."
      field :email, placeholder: "email@example.com"
      field :department_id, input_type: :association_select
      field :role, input_type: :select
    end
  end
end
