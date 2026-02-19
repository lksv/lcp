define_presenter :contact_short, inherits: :contact do
  label "Contacts (Short)"
  slug "contacts-short"

  index do
    default_view :table
    default_sort :last_name, :asc
    per_page 50
    row_click :show

    column :full_name, width: "50%", link_to: :show, sortable: true
    column :email, width: "50%", display: :email_link
  end

  show do
    section "Contact Summary" do
      field :full_name, display: :heading
      field :email, display: :email_link
    end
  end
end
