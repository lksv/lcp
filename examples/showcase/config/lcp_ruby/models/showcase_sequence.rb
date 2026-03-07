define_model :showcase_sequence do
  label "Sequenced Record"
  label_plural "Sequenced Records"

  # 1. Global sequence — formatted string, never resets
  field :ticket_code, :string,
    sequence: { format: "TKT-%{sequence:06d}" }

  # 2. Yearly scope — resets each year
  field :invoice_number, :string,
    sequence: { scope: [ :_year ], format: "INV-%{_year}-%{sequence:04d}" }

  # 3. Field-based scope — independent counter per category
  field :category_seq, :string,
    sequence: { scope: [ :category ], format: "%{category}-%{sequence:05d}" }

  # 4. Raw integer — no format, simple counter
  field :raw_counter, :integer,
    sequence: true

  # 5. Custom start and step
  field :order_ref, :integer,
    sequence: { start: 1000, step: 10 }

  # 6. assign_on: always — fills blank values on update
  field :backfill_code, :string,
    sequence: { format: "BF-%{sequence:04d}", assign_on: "always" }

  # Regular fields for context
  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end

  field :category, :enum, label: "Category", default: "general",
    values: {
      general: "General",
      support: "Support",
      billing: "Billing",
      engineering: "Engineering"
    }

  field :description, :text, label: "Description"

  timestamps true
  label_method :title
end
