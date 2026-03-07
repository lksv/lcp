define_presenter :delete_reason_dialog do
  model :showcase_delete_reason

  dialog size: :small, title_key: "lcp_ruby.dialogs.delete_reason_title"

  form do
    section "Reason" do
      field :reason, input_type: :textarea, input_options: { rows: 3 },
        autofocus: true, placeholder: "Why is this record being deleted?"
      field :notify_owner, input_type: :toggle
    end
  end
end
