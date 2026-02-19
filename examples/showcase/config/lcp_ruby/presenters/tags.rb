define_presenter :tags do
  model :tag
  label "Tags"
  slug "tags"
  icon "tag"

  index do
    description "Simple tag model with color. Used for has_many :through associations."
    default_sort :name, :asc
    per_page 50

    column :name, link_to: :show, sortable: true
    column :color, display: :color_swatch
  end

  show do
    section "Tag Details", columns: 2 do
      field :name, display: :heading
      field :color, display: :color_swatch
    end
  end

  form do
    section "Tag Information", columns: 2 do
      field :name, placeholder: "Tag name...", autofocus: true
      field :color
    end
  end

  action :create, type: :built_in, on: :collection
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
