define_presenter :articles do
  model :article
  label "Articles"
  slug "articles"
  icon "file-text"

  index do
    description "Central model demonstrating associations, nested forms, and display templates."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true, display: :truncate, display_options: { max: 50 }
    column "category.name", label: "Category", sortable: true
    column "author.name", label: "Author", sortable: true
    column :status, display: :badge, display_options: {
      color_map: { draft: "gray", published: "green", archived: "orange" }
    }, sortable: true
    column :word_count, display: :number

    includes :category, :author
  end

  show do
    description "Demonstrates association display, display templates, and rich content."

    section "Article Details", columns: 2, description: "Basic article information with association fields." do
      field :title, display: :heading
      field :status, display: :badge, display_options: {
        color_map: { draft: "gray", published: "green", archived: "orange" }
      }
      field "category.name", label: "Category"
      field "author.name", label: "Author"
      field :word_count, display: :number
      field :created_at, display: :relative_date
    end

    section "Content" do
      field :body, display: :rich_text
    end

    association_list "Comments", association: :comments, display: :default, link: false,
      sort: { position: :asc }, empty_message: "No comments yet."

    association_list "Tags", association: :tags, link: true,
      empty_message: "No tags assigned."

    includes :category, :author, :comments, :tags
  end

  form do
    description "Demonstrates association_select, multi_select, and nested_fields."

    section "Article Details", columns: 2, description: "Select fields for belongs_to associations." do
      field :title, placeholder: "Article title...", autofocus: true, col_span: 2
      field :category_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
      field :author_id, input_type: :association_select,
        input_options: { search: true, sort: { name: :asc }, label_method: :name }
      field :status, input_type: :select
    end

    section "Content" do
      field :body, input_type: :rich_text_editor
    end

    section "Tags", description: "Multi-select for has_many :through association." do
      info "Tags are assigned via a join table (article_tags). Select up to 5 tags."
      field :tag_ids, input_type: :multi_select,
        input_options: { sort: { name: :asc }, label_method: :name, max: 5 }
    end

    nested_fields "Comments", association: :comments,
      description: "Nested forms for has_many association with sortable rows.",
      allow_add: true, allow_remove: true, sortable: true, min: 0, max: 20,
      add_label: "Add Comment", empty_message: "No comments yet." do
      field :author_name, placeholder: "Commenter name"
      field :body, input_type: :textarea, input_options: { rows: 2 }
    end

    includes :comments, :tags
  end

  search do
    searchable_fields :title
    placeholder "Search articles..."
    filter :all, label: "All", default: true
    filter :published, label: "Published", scope: :published
    filter :drafts, label: "Drafts", scope: :drafts
  end

  action :create, type: :built_in, on: :collection, label: "New Article"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
