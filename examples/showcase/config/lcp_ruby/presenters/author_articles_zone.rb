define_presenter :author_articles_zone do
  model :article
  label "Articles"

  index do
    per_page 5
    column :title, renderer: :truncate, options: { max: 40 }
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", published: "green", archived: "orange" }
    }
  end
end
