define_presenter :save_filter_dialog do
  model :saved_filter

  dialog size: :small, title_key: "lcp_ruby.saved_filters.dialog_title"

  form do
    section "Filter" do
      field :name, autofocus: true
      field :description, input_type: :textarea, input_options: { rows: 2 }
      field :visibility, input_type: :select
      field :target_role, visible_when: { field: :visibility, operator: :eq, value: "role" }
      field :target_group, visible_when: { field: :visibility, operator: :eq, value: "group" }
      field :pinned, input_type: :toggle
      field :default_filter, input_type: :toggle
    end
  end
end
