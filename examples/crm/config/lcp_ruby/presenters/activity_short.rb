define_presenter :activity_short, inherits: :activity do
  label "Activities (Short)"
  slug "activities-short"

  index do
    default_view :table
    default_sort :scheduled_at, :desc
    per_page 50
    row_click :show

    column :subject, width: "50%", link_to: :show, sortable: true
    column :activity_type, width: "25%", renderer: :badge, options: {
      color_map: { call: "blue", meeting: "purple", email: "cyan", note: "gray", task: "orange" }
    }, sortable: true
    column :scheduled_at, width: "25%", renderer: :datetime, sortable: true
  end
end
