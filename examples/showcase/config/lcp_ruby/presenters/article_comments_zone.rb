define_presenter :article_comments_zone do
  model :comment
  label "Comments"

  index do
    per_page 10
    column :author_name, sortable: true
    column :body, renderer: :truncate, options: { max: 80 }
    column :created_at, renderer: :relative_date
  end
end
