define_presenter :authors do
  model :author
  label "Authors"
  slug "authors"
  icon "user"

  index do
    description "Simple model used as belongs_to target for articles."
    default_sort :name, :asc
    per_page 25

    column :name, link_to: :show, sortable: true
    column :email, renderer: :email_link
  end

  show do
    section "Author Details", columns: 2 do
      field :name, renderer: :heading
      field :email, renderer: :email_link
      field :bio
    end

    association_list "Articles", association: :articles, display_template: :default, link: true,
      sort: { created_at: :desc }, empty_message: "No articles yet."
  end

  form do
    section "Author Information", columns: 2 do
      field :name, placeholder: "Author name...", autofocus: true
      field :email
      field :bio, input_type: :textarea, col_span: 2
    end
  end

  action :create, type: :built_in, on: :collection
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
