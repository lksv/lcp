define_presenter :activity_tiles, inherits: :activity do
  label "Activities (Tiles)"
  slug "activities-tiles"

  index do
    layout :tiles
    default_sort :scheduled_at, :desc
    per_page 12
    empty_message "No activities found"

    tile do
      title_field :subject
      subtitle_field :activity_type, renderer: :badge, options: {
        color_map: { call: "blue", meeting: "purple", email: "cyan", note: "gray", task: "orange" }
      }
      description_field :description, max_lines: 3
      columns 3
      card_link :show
      actions :dropdown

      field "company.name", label: "Company"
      field "contact.full_name", label: "Contact"
      field :scheduled_at, label: "Scheduled", renderer: :datetime
      field :completed, label: "Done", renderer: :boolean_icon
    end

    sort_field :subject, label: "Subject"
    sort_field :activity_type, label: "Type"
    sort_field :scheduled_at, label: "Scheduled"
    sort_field :completed, label: "Completed"

    per_page_options 12, 24, 48
  end
end
