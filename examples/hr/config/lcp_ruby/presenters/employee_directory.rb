define_presenter :employee_directory do
  model :employee
  label "Employee Directory"
  slug "directory"
  icon "book"
  read_only true

  index do
    default_sort :last_name, :asc
    per_page 50
    empty_message "No employees in directory"

    column :photo, width: "5%", renderer: :avatar, options: { variant: "thumbnail", initials_fields: [ "first_name", "last_name" ] }
    column :full_name, width: "25%", sortable: true, pinned: :left
    column "position.title", label: "Position", width: "20%", sortable: true
    column "organization_unit.name", label: "Organization Unit", width: "20%", sortable: true
    column :work_email, width: "20%", renderer: :email_link, copyable: true
    column :phone, width: "10%", renderer: :phone_link
  end

  search do
    searchable_fields :full_name
    placeholder "Search directory..."
  end

  action :show, type: :built_in, on: :single, icon: "eye"
end
