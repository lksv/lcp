define_presenter :project_public, inherits: :project do
  label "Projects"
  slug "public-projects"
  icon "globe"
  read_only true

  index do
    default_view :tiles
    views_available :tiles
    per_page 12
    column :title, sortable: true
    column :status, renderer: :badge
  end

  show do
    section "Project", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge
      field :description, renderer: :rich_text
    end
  end

  search do
    searchable_fields :title
  end
end
