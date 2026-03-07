define_presenter :quick_note_dialog do
  model :showcase_quick_note

  dialog size: :small, title_key: "lcp_ruby.dialogs.quick_note_title"

  form do
    section "Note" do
      field :title, autofocus: true, placeholder: "Note title..."
      field :body, input_type: :textarea, input_options: { rows: 2 },
        placeholder: "Write a quick note..."
      field :priority, input_type: :select
    end
  end
end
