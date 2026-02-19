define_model :showcase_attachment do
  label "Attachment"
  label_plural "Attachments"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end

  # Single image with variants
  field :avatar, :attachment, label: "Avatar", options: {
    multiple: false,
    max_size: "5MB",
    content_types: %w[image/jpeg image/png image/gif image/webp],
    variants: {
      thumbnail: { resize_to_limit: [80, 80] },
      medium: { resize_to_limit: [300, 300] }
    }
  }

  # Single file (PDF only)
  field :resume, :attachment, label: "Resume", options: {
    multiple: false,
    max_size: "10MB",
    content_types: %w[application/pdf]
  }

  # Multiple images (gallery)
  field :gallery, :attachment, label: "Gallery", options: {
    multiple: true,
    max_files: 10,
    max_size: "5MB",
    content_types: %w[image/jpeg image/png image/gif image/webp],
    variants: {
      thumbnail: { resize_to_limit: [100, 100] },
      medium: { resize_to_limit: [400, 400] }
    }
  }

  # Multiple files (documents)
  field :documents, :attachment, label: "Documents", options: {
    multiple: true,
    max_files: 20,
    max_size: "50MB",
    content_types: %w[application/pdf image/jpeg image/png]
  }

  timestamps true
  label_method :title
end
