define_presenter :showcase_attachments do
  model :showcase_attachment
  label "Attachments"
  slug "showcase-attachments"
  icon "paperclip"

  index do
    description "Demonstrates file upload with Active Storage: single/multiple, images/files, variants."
    default_sort :created_at, :desc
    per_page 25

    column :title, link_to: :show, sortable: true
    column :avatar, renderer: :attachment_preview
  end

  show do
    description "Each section shows a different attachment configuration."

    section "Single Image (Avatar)", columns: 2, description: "Single image with variants: thumbnail (80x80) and medium (300x300)." do
      field :title, renderer: :heading
      field :avatar, renderer: :attachment_preview
    end

    section "Single File (Resume)", columns: 1, description: "Single file restricted to PDF. Max size: 10MB." do
      field :resume, renderer: :attachment_link
    end

    section "Multiple Images (Gallery)", columns: 1, description: "Up to 10 images with thumbnail and medium variants." do
      field :gallery, renderer: :attachment_preview
    end

    section "Multiple Files (Documents)", columns: 1, description: "Up to 20 files. PDF and images only." do
      field :documents, renderer: :attachment_list
    end
  end

  form do
    description "Upload files using drag and drop or the file picker."

    section "Single Image (Avatar)", columns: 1, description: "Accepts JPEG, PNG, GIF, WebP. Max size: 5MB." do
      info "This field uses has_one_attached with image variants configured for thumbnail and medium sizes."
      field :title, placeholder: "Record title...", autofocus: true
      field :avatar, input_options: { preview: true, drag_drop: true }
    end

    section "Single File (Resume)", columns: 1, description: "Accepts PDF only. Max size: 10MB." do
      info "Content type is restricted to application/pdf. No image variants are configured."
      field :resume, input_options: { preview: true, drag_drop: true }
    end

    section "Multiple Images (Gallery)", columns: 1, description: "Accepts up to 10 images. Max 5MB each." do
      info "This field uses has_many_attached. Each uploaded image gets thumbnail and medium variants."
      field :gallery, input_options: { preview: true, drag_drop: true }
    end

    section "Multiple Files (Documents)", columns: 1, description: "Accepts up to 20 files. PDF and images. Max 50MB each." do
      info "Mixed content types are supported. No image variants — files are served as downloads."
      field :documents, input_options: { preview: true, drag_drop: true }
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Record"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
