define_model :showcase_array do
  label "Array Demo"
  label_plural "Array Demos"

  field :title, :string, label: "Title", limit: 150, null: false do
    validates :presence
  end

  field :description, :text, label: "Description"

  # String array — most common use case (tags, labels, categories)
  field :tags, :array, item_type: :string, default: [] do
    validates :array_length, maximum: 10
    validates :array_uniqueness
  end

  # String array with inclusion validation — only allowed values
  field :categories, :array, item_type: :string, default: [] do
    validates :array_inclusion, in: %w[frontend backend devops design qa management]
    validates :array_length, maximum: 3
  end

  # Integer array — scores, ratings, numeric lists
  field :scores, :array, item_type: :integer, default: [] do
    validates :array_inclusion, in: [1, 2, 3, 4, 5]
    validates :array_length, maximum: 5
  end

  # Float array — measurements, coordinates, weights
  field :measurements, :array, item_type: :float, default: []

  # String array with default values pre-populated
  field :default_labels, :array, item_type: :string,
    default: %w[important review]

  # Enum to drive conditional rendering based on array content
  field :record_type, :enum, label: "Type", default: "basic",
    values: { basic: "Basic", advanced: "Advanced", special: "Special" }

  # Boolean flag to drive additional conditionals
  field :featured, :boolean, label: "Featured", default: false

  timestamps true
  label_method :title
end
