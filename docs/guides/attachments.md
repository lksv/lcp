# Attachments Guide

This guide covers file attachments in LCP Ruby using Active Storage. You can define single or multiple file attachment fields on your models, configure validations and image variants, and control how attachments are displayed and uploaded in forms.

## Prerequisites

LCP Ruby attachments are built on [Active Storage](https://guides.rubyonrails.org/active_storage_overview.html). Your host Rails application must have Active Storage set up before using attachment fields.

### 1. Require Active Storage

Ensure `active_storage/engine` is required in your `config/application.rb`:

```ruby
require "active_storage/engine"
```

### 2. Configure Storage Service

Create or verify `config/storage.yml`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

Set the active storage service in your environment config (e.g., `config/environments/development.rb`):

```ruby
config.active_storage.service = :local
```

For production, configure a cloud service (S3, GCS, Azure) as described in the [Active Storage guide](https://guides.rubyonrails.org/active_storage_overview.html#setup).

### 3. Install Active Storage Migrations

Run the Active Storage installation generator and migrate:

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

This creates the `active_storage_blobs`, `active_storage_attachments`, and `active_storage_variant_records` tables.

## Defining Attachment Fields

### Single Attachment

A single attachment field uses `has_one_attached` under the hood. Define it with `type: attachment`:

```yaml
model:
  name: employee
  fields:
    - name: avatar
      type: attachment
      label: "Profile Photo"
      options:
        accept: "image/*"
        max_size: 5MB
        content_types: ["image/jpeg", "image/png", "image/webp"]
        variants:
          thumbnail: { resize_to_limit: [100, 100] }
          medium: { resize_to_limit: [300, 300] }
```

### Multiple Attachments

Set `multiple: true` in options to use `has_many_attached`, allowing several files on a single field:

```yaml
model:
  name: document
  fields:
    - name: files
      type: attachment
      label: "Documents"
      options:
        multiple: true
        max_files: 10
        max_size: 50MB
        content_types: ["application/pdf", "image/*"]
```

### Complete Model Example

```yaml
model:
  name: document
  fields:
    - name: title
      type: string
      label: "Title"
      validations:
        - type: presence

    - name: photo
      type: attachment
      label: "Photo"
      options:
        accept: "image/*"
        max_size: 5MB
        content_types: ["image/jpeg", "image/png", "image/webp"]
        variants:
          thumbnail: { resize_to_limit: [100, 100] }
          medium: { resize_to_limit: [300, 300] }

    - name: files
      type: attachment
      label: "Documents"
      options:
        multiple: true
        max_files: 10
        max_size: 50MB
        content_types: ["application/pdf", "image/*"]
```

## Validation Options

Attachment fields support the following validation options inside `options:`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_size` | string | global default | Maximum file size per file (e.g., `"10MB"`, `"512KB"`) |
| `min_size` | string | none | Minimum file size per file |
| `content_types` | array | global default | Allowed MIME types. Supports wildcards like `"image/*"` |
| `max_files` | integer | none | Maximum number of files (only for `multiple: true`) |

Size strings support `KB`, `MB`, and `GB` suffixes.

```yaml
- name: contract
  type: attachment
  label: "Contract PDF"
  options:
    max_size: 20MB
    min_size: 1KB
    content_types: ["application/pdf"]

- name: gallery
  type: attachment
  label: "Gallery Images"
  options:
    multiple: true
    max_files: 20
    max_size: 10MB
    content_types: ["image/jpeg", "image/png", "image/gif", "image/webp"]
```

Global defaults for `max_size` and `content_types` can be set in the [engine configuration](../reference/engine-configuration.md) via `attachment_max_size` and `attachment_allowed_content_types`.

> **`accept` vs `content_types`:** The `accept` option sets the HTML `accept` attribute on the file input, which filters the file browser dialog — but it is **not validated on the server**. Use `content_types` for server-side MIME type validation. Both can be used together: `accept` for better UX, `content_types` for security.

## Image Variants

Define named image variants using the `variants` option. Variants use Active Storage's image processing capabilities (requires the `image_processing` gem in your host app).

```yaml
options:
  variants:
    thumbnail: { resize_to_limit: [100, 100] }
    medium: { resize_to_limit: [300, 300] }
    large: { resize_to_limit: [800, 800] }
```

Variant names can be referenced in presenter display options to control which size is shown. Variants are generated on first access and cached by Active Storage.

> **Note:** The `image_processing` gem must be installed in your host app's `Gemfile` for variants to work. Without it, variant references are silently ignored and the original image is displayed instead.

Common variant transformations:

| Transform | Description | Example |
|-----------|-------------|---------|
| `resize_to_limit` | Resize to fit within dimensions, maintaining aspect ratio | `[300, 300]` |
| `resize_to_fill` | Resize to fill dimensions, cropping as needed | `[300, 300]` |
| `resize_to_fit` | Resize to fit within dimensions, may be smaller | `[300, 300]` |
| `resize_and_pad` | Resize and pad to exact dimensions | `[300, 300]` |

## Form Configuration

Control how attachment fields appear in forms using `input_options` on the presenter field definition.

### Input Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `preview` | boolean | `false` | Show a preview of the current file (image thumbnail or filename) |
| `drag_drop` | boolean | `false` | Enable drag-and-drop upload zone |
| `direct_upload` | boolean | `false` | Use Active Storage direct upload (uploads before form submission) |

```yaml
presenter:
  name: document_form
  model: document

  form:
    sections:
      - title: "Details"
        fields:
          - field: title
          - field: photo
            input_options:
              preview: true
              drag_drop: true
              direct_upload: true
          - field: files
            input_options:
              preview: true
              drag_drop: true
```

When `direct_upload: true` is enabled, files are uploaded directly to the storage service as soon as the user selects them, before the form is submitted. This provides a better user experience for large files.

## Display Configuration

Attachment fields support three renderers for show pages and index tables.

### `attachment_preview`

Renders an image preview for image attachments, with a fallback to a download link for non-image files. Use the `variant` option to control which image variant is shown.

```yaml
show:
  layout:
    - section: "Details"
      fields:
        - field: photo
          renderer: attachment_preview
          options:
            variant: medium
```

### `attachment_list`

Renders a list of download links with filenames and file sizes. Best for multiple attachment fields.

```yaml
show:
  layout:
    - section: "Documents"
      fields:
        - field: files
          renderer: attachment_list
```

### `attachment_link`

Renders a single download link with the filename. Best for single non-image attachment fields.

```yaml
show:
  layout:
    - section: "Contract"
      fields:
        - field: contract
          renderer: attachment_link
```

### Complete Presenter Example

```yaml
presenter:
  name: document_admin
  model: document
  label: "Documents"
  slug: documents

  index:
    table_columns:
      - { field: title, link_to: show, sortable: true }
      - { field: photo, renderer: attachment_preview, options: { variant: thumbnail } }
      - { field: created_at, renderer: relative_date }

  show:
    layout:
      - section: "Details"
        columns: 2
        fields:
          - { field: title, renderer: heading }
          - field: photo
            renderer: attachment_preview
            options: { variant: medium }
          - field: files
            renderer: attachment_list

  form:
    sections:
      - title: "Document"
        fields:
          - { field: title, autofocus: true }
          - field: photo
            input_options:
              preview: true
              drag_drop: true
              direct_upload: true
          - field: files
            input_options:
              preview: true
              drag_drop: true

  actions:
    collection:
      - { name: create, type: built_in, label: "New Document", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

## Permissions

Attachment fields work like any other field in the permission system. Control read and write access through `readable` and `writable` field lists in your permissions YAML:

```yaml
permissions:
  model: document
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields:
        readable: all
        writable: all

    viewer:
      crud: [index, show]
      fields:
        readable: [title, photo, files]
        writable: []

    editor:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [title, photo, files]
```

When an attachment field is not writable for the current user, the file input is not rendered on the form. When not readable, the attachment is not shown on show pages or index tables.

## Removing Attachments

On edit forms, attachment fields include a "Remove" checkbox that allows users to detach the current file. For multiple attachments, each file has its own remove checkbox.

When the remove checkbox is checked and the form is submitted, the attachment is purged (the file is deleted from storage and the attachment record is removed).

The remove checkbox is only shown when:
- The field has an existing attachment
- The field is writable for the current user

## DSL Examples

### Single Attachment

```ruby
define_model :employee do
  field :name, :string, label: "Name" do
    validates :presence
  end

  field :avatar, :attachment, label: "Profile Photo", options: {
    accept: "image/*",
    max_size: "5MB",
    content_types: %w[image/jpeg image/png image/webp],
    variants: {
      thumbnail: { resize_to_limit: [100, 100] },
      medium: { resize_to_limit: [300, 300] }
    }
  }
end
```

### Multiple Attachments

```ruby
define_model :document do
  field :title, :string, label: "Title" do
    validates :presence
  end

  field :photo, :attachment, label: "Photo", options: {
    accept: "image/*",
    max_size: "5MB",
    content_types: %w[image/jpeg image/png image/webp],
    variants: {
      thumbnail: { resize_to_limit: [100, 100] },
      medium: { resize_to_limit: [300, 300] }
    }
  }

  field :files, :attachment, label: "Documents", options: {
    multiple: true,
    max_files: 10,
    max_size: "50MB",
    content_types: %w[application/pdf image/*]
  }
end
```

Source: `lib/lcp_ruby/model_factory/attachment_applicator.rb`
