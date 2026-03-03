define_presenter :training_enrollment do
  model :training_enrollment
  label "Training Enrollments"
  slug "training-enrollments"
  icon "bookmark"

  index do
    column "employee.full_name"
    column "training_course.title"
    column :status, renderer: :badge, options: { color_map: { enrolled: "blue", completed: "green", cancelled: "gray", no_show: "red" } }
    column :completed_at, renderer: :datetime
    column :score
  end

  show do
    section "Enrollment Details", columns: 2 do
      field "employee.full_name"
      field "training_course.title"
      field :status, renderer: :badge
      field :completed_at,
        visible_when: { field: :status, operator: :eq, value: "completed" }
      field :score,
        visible_when: { field: :status, operator: :eq, value: "completed" }
      field :feedback
      field :certificate, renderer: :attachment_preview,
        visible_when: { field: :status, operator: :eq, value: "completed" }
    end
  end

  form do
    section "Enrollment Details", columns: 2 do
      field :employee_id, input_type: :association_select
      field :training_course_id, input_type: :association_select
      field :status, input_type: :select
      field :completed_at, input_type: :datetime,
        visible_when: { field: :status, operator: :eq, value: "completed" }
      field :score, input_type: :number,
        visible_when: { field: :status, operator: :eq, value: "completed" }
      field :feedback, input_type: :textarea
      field :certificate,
        visible_when: { field: :status, operator: :eq, value: "completed" }
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Enrollment", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true
end
