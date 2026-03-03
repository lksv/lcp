define_presenter :training_course do
  model :training_course
  label "Training Courses"
  slug "training-courses"
  icon "book-open"

  index do
    column :title, link_to: :show, sortable: true
    column :category, renderer: :badge
    column :format, renderer: :badge
    column :duration_hours, renderer: :decimal, options: { suffix: "hrs" }
    column :max_participants
    column :starts_at, renderer: :datetime, sortable: true
    column :active, renderer: :boolean_icon
  end

  show do
    section "Course Details", columns: 2 do
      field :title, renderer: :heading
      field :category, renderer: :badge
      field :description, renderer: :rich_text
      field :format, renderer: :badge
      field :duration_hours, renderer: :decimal, options: { suffix: "hrs" }
      field :max_participants
      field :instructor
      field :location,
        visible_when: { field: :format, operator: :in, value: %w[in_person hybrid] }
      field :url, renderer: :url_link,
        visible_when: { field: :format, operator: :in, value: %w[online hybrid] }
      field :starts_at, renderer: :datetime
      field :ends_at, renderer: :datetime
      field :active, renderer: :boolean_icon
    end

    association_list "Enrollments", association: :training_enrollments
  end

  form do
    section "Course Details", columns: 2 do
      field :title, autofocus: true
      field :category, input_type: :select
      field :description, input_type: :rich_text
      field :format, input_type: :select
      field :duration_hours, input_type: :number, suffix: "hrs"
      field :max_participants, input_type: :number
      field :instructor
      field :location,
        visible_when: { field: :format, operator: :in, value: %w[in_person hybrid] }
      field :url,
        visible_when: { field: :format, operator: :in, value: %w[online hybrid] }
      field :starts_at, input_type: :datetime
      field :ends_at, input_type: :datetime
      field :active, input_type: :toggle
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Course", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true
end
