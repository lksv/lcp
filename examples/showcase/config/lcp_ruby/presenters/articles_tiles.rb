define_presenter :articles_tiles, inherits: :articles do
  label "Articles (Tiles)"
  slug "articles-tiles"

  index do
    layout :tiles
    default_sort :created_at, :desc
    per_page 12

    tile do
      title_field :title
      subtitle_field :status, renderer: :badge, options: {
        color_map: { draft: "gray", published: "green", archived: "orange" }
      }
      columns 3
      card_link :show
      actions :dropdown

      field "category.name", label: "Category"
      field "author.name", label: "Author"
      field :word_count, label: "Words", renderer: :number
      field :created_at, label: "Published", renderer: :relative_date
    end

    sort_field :title, label: "Title"
    sort_field :word_count, label: "Word Count"
    sort_field :created_at, label: "Date"

    per_page_options 6, 12, 24
  end
end
