define_presenter :extensibility_quick_edit_dialog do
  model :showcase_extensibility

  dialog size: :small, title_key: "lcp_ruby.dialogs.quick_edit_title"

  form do
    section "Quick Edit" do
      field :name, autofocus: true
      field :currency, placeholder: "e.g. USD, EUR"
      field :amount, input_type: :number, prefix: "$"
    end
  end
end
