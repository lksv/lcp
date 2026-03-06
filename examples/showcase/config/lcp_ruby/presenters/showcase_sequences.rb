define_presenter :showcase_sequences do
  model :showcase_sequence
  label "Sequences"
  slug "showcase-sequences"
  icon "hash"

  index do
    description "Demonstrates gap-free auto-numbering sequences. Each column shows a different sequence type: global, yearly, field-scoped, raw integer, custom start/step, and backfill-on-update."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :ticket_code, label: "Global", sortable: true
    column :invoice_number, label: "Yearly", sortable: true
    column :category_seq, label: "By Category", sortable: true
    column :title, link_to: :show, sortable: true
    column :category, renderer: :badge, options: {
      color_map: { general: "gray", support: "blue", billing: "green", engineering: "purple" }
    }, sortable: true
    column :raw_counter, label: "Raw #"
    column :order_ref, label: "Order Ref"
    column :backfill_code, label: "Backfill"
  end

  show do
    description "All sequence values are assigned automatically on record creation. The 'Backfill code' also fills blank values on update (assign_on: always)."

    section "Sequence Values", columns: 2 do
      field :ticket_code, label: "Global Sequence (TKT-NNNNNN)"
      field :invoice_number, label: "Yearly Scope (INV-YYYY-NNNN)"
      field :category_seq, label: "Category Scope (CAT-NNNNN)"
      field :raw_counter, label: "Raw Integer (no format)"
      field :order_ref, label: "Custom Start/Step (1000, +10)"
      field :backfill_code, label: "Backfill on Update (assign_on: always)"
    end

    section "Record Details", columns: 2 do
      field :title, renderer: :heading
      field :category, renderer: :badge, options: {
        color_map: { general: "gray", support: "blue", billing: "green", engineering: "purple" }
      }
      field :description
      field :created_at, renderer: :datetime
    end
  end

  form do
    description "Sequence fields are readonly — they are assigned automatically when the record is saved. Only Title, Category, and Description are editable."

    section "Record Details", columns: 2 do
      field :title, placeholder: "Record title...", autofocus: true, col_span: 2
      field :category, input_type: :select
      field :description, input_type: :textarea, input_options: { rows: 3 }
    end
  end

  search do
    searchable_fields :title, :ticket_code, :invoice_number, :category_seq
    placeholder "Search by title or sequence number..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
