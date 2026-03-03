define_model :saved_filter do
  label "Saved Filter"
  label_plural "Saved Filters"
  table_name "lcp_saved_filters"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end

  field :description, :text, label: "Description"
  field :target_presenter, :string, label: "Target Presenter", limit: 100, null: false do
    validates :presence
  end

  field :condition_tree, :json, label: "Condition Tree", null: false do
    validates :presence
  end

  field :ql_text, :text, label: "Query Language Text"

  field :visibility, :enum, label: "Visibility", default: "personal",
    values: {
      personal: "Personal",
      role: "Role",
      group: "Group",
      global: "Global"
    }

  field :owner_id, :integer, label: "Owner ID", null: false do
    validates :presence
  end

  field :target_role, :string, label: "Target Role", limit: 50
  field :target_group, :string, label: "Target Group", limit: 100
  field :position, :integer, label: "Position"
  field :icon, :string, label: "Icon", limit: 50
  field :color, :string, label: "Color", limit: 30

  field :pinned, :boolean, label: "Pinned", default: false
  field :default_filter, :boolean, label: "Default Filter", default: false

  scope :personal_only, where: { visibility: "personal" }
  scope :global_only, where: { visibility: "global" }
  scope :role_only, where: { visibility: "role" }
  scope :pinned_only, where: { pinned: true }

  timestamps true
  userstamps
  label_method :name
end
