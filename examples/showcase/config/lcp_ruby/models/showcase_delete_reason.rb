define_model :showcase_delete_reason do
  label "Delete Reason"
  table_name "_virtual"

  field :reason, :text, label: "Reason", null: false do
    validates :presence
    validates :length, minimum: 5
  end

  field :notify_owner, :boolean, label: "Notify Owner", default: false
end
