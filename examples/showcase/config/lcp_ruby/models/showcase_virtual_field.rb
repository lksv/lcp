define_model :showcase_virtual_field do
  label "Virtual Field"
  label_plural "Virtual Fields"

  # Real columns
  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
    validates :length, maximum: 100
  end

  field :properties, :json, label: "Properties (JSON)"

  # --- Service accessor fields (source: json_field) ---

  # String stored in JSON
  field :color, :string, label: "Color",
    source: { service: "json_field", options: { column: "properties", key: "color" } }

  # Integer with numericality validation
  field :priority, :integer, label: "Priority",
    source: { service: "json_field", options: { column: "properties", key: "priority" } } do
    validates :numericality, only_integer: true, greater_than_or_equal_to: 1,
      less_than_or_equal_to: 5, allow_nil: true
  end

  # Decimal stored in JSON
  field :unit_price, :decimal, label: "Unit Price",
    source: { service: "json_field", options: { column: "properties", key: "unit_price" } }

  # Boolean stored in JSON
  field :featured, :boolean, label: "Featured",
    source: { service: "json_field", options: { column: "properties", key: "featured" } }

  # Enum with inclusion validation
  field :category, :enum, label: "Category",
    values: %w[electronics clothing food furniture other],
    source: { service: "json_field", options: { column: "properties", key: "category" } }

  # Static default value
  field :warehouse, :string, label: "Warehouse", default: "MAIN-01",
    source: { service: "json_field", options: { column: "properties", key: "warehouse" } }

  # Date stored in JSON
  field :release_date, :date, label: "Release Date",
    source: { service: "json_field", options: { column: "properties", key: "release_date" } }

  # Multiple fields from the same JSON column
  field :sku_code, :string, label: "SKU Code",
    source: { service: "json_field", options: { column: "properties", key: "sku_code" } }

  # Location parts (used by external fields below)
  field :city, :string, label: "City",
    source: { service: "json_field", options: { column: "properties", key: "city" } }

  field :country, :string, label: "Country",
    source: { service: "json_field", options: { column: "properties", key: "country" } }

  # --- External source fields ---

  # Computed from city + country (getter only, setter is no-op)
  field :full_location, :string, label: "Full Location", source: :external

  # Derived from priority integer (getter only, setter is no-op)
  field :priority_label, :string, label: "Priority Label", source: :external

  timestamps true
  label_method :name
end
