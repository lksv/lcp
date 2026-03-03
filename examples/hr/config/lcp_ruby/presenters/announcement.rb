define_presenter :announcement do
  model :announcement
  label "Announcements"
  slug "announcements"
  icon "megaphone"

  index do
    default_sort :created_at, :desc

    column :title, link_to: :show
    column :priority, renderer: :badge, options: { color_map: { normal: "gray", important: "yellow", urgent: "red" } }
    column :published, renderer: :boolean_icon
    column :pinned, renderer: :boolean_icon
    column :published_at, renderer: :datetime
    column :expires_at, renderer: :date
  end

  show do
    section "Announcement Details", columns: 2 do
      field :title, renderer: :heading
      field :body, renderer: :rich_text
      field :priority, renderer: :badge
      field :published, renderer: :boolean_icon
      field :published_at, renderer: :datetime
      field :pinned, renderer: :boolean_icon
      field :expires_at, renderer: :date
      field "organization_unit.name", renderer: :internal_link
    end
  end

  form do
    section "Announcement Details", columns: 2 do
      field :title, autofocus: true
      field :body, input_type: :rich_text
      field :priority, input_type: :select
      field :organization_unit_id, input_type: :tree_select
      field :published, input_type: :toggle
      field :pinned, input_type: :toggle
      field :expires_at, input_type: :date_picker
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Announcement", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
