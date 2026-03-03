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

    column :title, link_to: :show, sortable: true, renderer: :truncate, options: { max: 50 }
    column "category.name", label: "Category", sortable: true
    column "author.name", label: "Author", sortable: true
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", published: "green", archived: "orange" }
    }, sortable: true
    column :word_count, renderer: :number

    includes :category, :author
  end

  show do
    description "Demonstrates association display, display templates, and rich content."

    section "Article Details", columns: 2, description: "Basic article information with association fields." do
      field :title, renderer: :heading, copyable: true
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", published: "green", archived: "orange" }
      }
      field "category.name", label: "Category", copyable: true
      field "author.name", label: "Author"
      field :word_count, renderer: :number
      field :created_at, renderer: :relative_date
    end

    section "Content" do
      field :body, renderer: :rich_text
    end

    association_list "Comments", association: :comments, display_template: :default, link: false,
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

    advanced_filter do
      enabled true
      max_conditions 10
      max_nesting_depth 2
      max_association_depth 1
      allow_or_groups true
      query_language true

      filterable_fields :title, :status, :word_count, :created_at,
        "category.name", "author.name"

      field_options :status, operators: %i[eq not_eq in not_in present blank]

      saved_filters do
        enabled true
        display :dropdown
        max_visible_pinned 3
      end
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Article"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
