define_presenter :candidate do
  model :candidate
  label "Candidates"
  slug "candidates"
  icon "user-check"

  index do
    actions_position :dropdown
    empty_message "No candidates yet"

    column :full_name, link_to: :show
    column "job_posting.title"
    column :status, renderer: :badge, options: { color_map: { applied: "blue", screening: "yellow", interviewing: "orange", offer: "purple", hired: "green", rejected: "red", withdrawn: "gray" } }
    column :source, renderer: :badge
    column :rating, renderer: :rating, options: { max: 5 }
    column :created_at, renderer: :relative_date
  end

  show do
    section "Candidate Details", columns: 2 do
      field :full_name, renderer: :heading
      field :status, renderer: :status_timeline, options: { steps: %w[applied screening interviewing offer hired] }
      field :email, renderer: :email_link
      field :phone, renderer: :phone_link
      field "job_posting.title", renderer: :internal_link
      field :source, renderer: :badge
      field :resume, renderer: :attachment_link
      field :cover_letter
      field :rating, renderer: :rating, options: { max: 5 }
      field :notes, renderer: :rich_text
      field :rejection_reason,
        visible_when: { field: :status, operator: :eq, value: "rejected" }
    end

    association_list "Interviews", association: :interviews, sort: { scheduled_at: :desc }
  end

  form do
    section "Candidate Details", columns: 2 do
      field :first_name
      field :last_name
      field :email
      field :phone
      field :job_posting_id, input_type: :association_select
      field :status, input_type: :select
      field :source, input_type: :select
      field :resume
      field :cover_letter, input_type: :textarea
      field :rating, input_type: :slider, input_options: { min: 1, max: 5, step: 1 }
      field :notes, input_type: :rich_text
    end
  end

  search do
    searchable_fields :full_name, :email
  end

  action :create, type: :built_in, on: :collection, label: "New Candidate", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :advance, type: :custom, on: :single,
    label: "Advance Stage", icon: "arrow-right",
    visible_when: { field: :status, operator: :not_in, value: %w[hired rejected withdrawn] }
  action :reject_candidate, type: :custom, on: :single,
    label: "Reject", style: :danger,
    visible_when: { field: :status, operator: :not_in, value: %w[rejected hired withdrawn] }
  action :hire, type: :custom, on: :single,
    label: "Hire", icon: "check",
    visible_when: { field: :status, operator: :eq, value: "offer" }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
