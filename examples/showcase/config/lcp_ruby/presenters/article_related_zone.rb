define_presenter :article_related_zone do
  model :article
  label "Related Articles"

  index do
    per_page 5
    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", published: "green", archived: "orange" }
    }
    column :word_count, renderer: :number

    includes :category
  end
end
