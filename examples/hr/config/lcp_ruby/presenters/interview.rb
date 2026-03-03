define_presenter :interview do
  model :interview
  label "Interviews"
  slug "interviews"
  icon "message-square"

  index do
    column "candidate.full_name"
    column :interview_type, renderer: :badge
    column :scheduled_at, renderer: :datetime, sortable: true
    column :duration_minutes
    column :status, renderer: :badge, options: { color_map: { scheduled: "blue", completed: "green", cancelled: "gray", no_show: "red" } }
    column :rating, renderer: :rating, options: { max: 5 }
    column :recommendation, renderer: :badge
  end

  show do
    section "Interview Details", columns: 2 do
      field "candidate.full_name", renderer: :internal_link
      field "interviewer.full_name", renderer: :internal_link
      field :interview_type, renderer: :badge
      field :scheduled_at, renderer: :datetime
      field :duration_minutes
      field :location
      field :meeting_url, renderer: :url_link
      field :status, renderer: :badge
      field :rating, renderer: :rating, options: { max: 5 }
      field :feedback
      field :recommendation, renderer: :badge, options: { color_map: { strong_yes: "green", yes: "green", neutral: "yellow", no: "red", strong_no: "red" } }
      field :notes
    end
  end

  form do
    section "Interview Details", columns: 2 do
      field :candidate_id, input_type: :association_select
      field :interviewer_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :interview_type, input_type: :select
      field :scheduled_at, input_type: :datetime
      field :duration_minutes, input_type: :number
      field :location
      field :meeting_url
      field :status, input_type: :select
      field :rating, input_type: :slider, input_options: { min: 1, max: 5, step: 1 }
      field :feedback, input_type: :textarea
      field :recommendation, input_type: :radio
      field :notes, input_type: :textarea
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Interview", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :complete_interview, type: :custom, on: :single,
    label: "Complete",
    visible_when: { field: :status, operator: :eq, value: "scheduled" }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true
end
