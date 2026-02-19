define_presenter :showcase_extensibility do
  model :showcase_extensibility
  label "Extensibility"
  slug "showcase-extensibility"
  icon "puzzle"

  index do
    description "Demonstrates custom types, service-based computed fields, and transforms."
    default_sort :created_at, :desc
    per_page 25

    column :name, link_to: :show, sortable: true
    column :currency, display: :badge
    column :amount, display: :currency, display_options: { currency: "USD" }
    column :score, display: :number
    column :normalized_name, display: :code
  end

  show do
    description "Computed fields update automatically based on other field values."

    section "Record Details", columns: 2 do
      field :name, display: :heading
      field :currency, display: :badge
      field :amount, display: :currency, display_options: { currency: "USD" }
      field :score, display: :number
      field :normalized_name, display: :code
    end
  end

  form do
    description "Demonstrates custom transforms and service-based computed fields."

    section "Details", columns: 2 do
      info "The currency field is validated against a 3-letter ISO format. The score is computed from amount * currency multiplier."
      field :name, placeholder: "Record name...", autofocus: true
      field :currency, placeholder: "e.g. USD, EUR, GBP", hint: "3-letter ISO 4217 currency code."
      field :amount, input_type: :number, prefix: "$"
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Record"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
