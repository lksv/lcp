define_presenter :employees_tiles, inherits: :employees do
  label "Employees (Tiles)"
  slug "employees-tiles"

  index do
    layout :tiles
    default_sort :name, :asc
    per_page 8

    tile do
      title_field :name
      subtitle_field :role, renderer: :badge, options: {
        color_map: { admin: "red", manager: "purple", developer: "blue", designer: "cyan", intern: "gray" }
      }
      columns 4
      card_link :show
      actions :none

      field :email, label: "Email", renderer: :email_link
      field "department.name", label: "Department"
      field :status, label: "Status", renderer: :badge, options: {
        color_map: { active: "green", on_leave: "orange", terminated: "red", archived: "gray" }
      }
    end

    sort_field :name, label: "Name"
    sort_field :role, label: "Role"
    sort_field :email, label: "Email"

    per_page_options 8, 16, 32
  end
end
