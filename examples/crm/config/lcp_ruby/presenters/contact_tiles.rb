define_presenter :contact_tiles, inherits: :contact do
  label "Contacts (Tiles)"
  slug "contacts-tiles"

  index do
    layout :tiles
    default_sort :last_name, :asc
    per_page 12

    tile do
      title_field :full_name
      subtitle_field "company.name"
      description_field :position, max_lines: 2
      columns 4
      card_link :show
      actions :dropdown

      field :email, renderer: :email_link
      field :phone, renderer: :phone_link
      field :active, label: "Active", renderer: :boolean_icon
      field :activities_count, label: "Activities"
    end

    sort_field :last_name, label: "Last Name"
    sort_field :first_name, label: "First Name"
    sort_field "company.name", label: "Company"
    sort_field :activities_count, label: "Activities"

    per_page_options 12, 24, 48

    item_class "lcp-row-muted", when: { field: :active, operator: :eq, value: false }
  end
end
