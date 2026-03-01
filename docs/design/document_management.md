# Design: Document Management (DMS)

**Status:** Proposed
**Date:** 2026-03-01

## Problem

The platform currently supports file attachments via Active Storage — upload, download, validation (size, MIME type, max files), and image variants. This covers the basic "attach a file to a record" use case.

However, real-world information systems need more from file management:

- **Per-file metadata** — description, category, tags for each attached file (not just for the record). With `has_many_attached`, there is no place to store per-file attributes on the parent model.
- **Versioning** — users re-upload a document and need to see what changed, when, and by whom. The old version should remain accessible.
- **Document as a first-class entity** — in some scenarios, the document itself is the primary business object (contracts archive, regulatory filings), not just an attachment on something else.
- **Folder / category organization** — navigating and filtering documents across records.

### DMS Spectrum

Where a system sits on this spectrum determines the design:

| Level | Description | Example |
|-------|-------------|---------|
| **Attachments** | Files pinned to records, no per-file metadata | Current LCP state |
| **Smart attachments** | Per-file metadata, ordering, categories | Invoice attachments with description and type |
| **Lightweight DMS** | Versioning, workflow, cross-record linking | Contract management within a CRM |
| **Full DMS** | Documents as primary entities, folder trees, full-text search | Alfresco, SharePoint, M-Files |

This design targets **smart attachments** with a clear path toward **lightweight DMS**. Full DMS is a separate product and is out of scope.

## Goals

- Per-file metadata for attachment fields, configurable from YAML
- Attachment metadata is a **regular LCP dynamic model** — fields, validations, permissions, positioning, and presenters all work out of the box
- File ordering via existing `positioning` infrastructure
- Clean data model that can later support versioning and cross-record linking

## Non-Goals

- Full DMS (standalone document entities, folder trees, full-text indexing)
- Document versioning (planned as a follow-up)
- Document workflow / approval (see [Workflow and Approvals](workflow_and_approvals.md))
- File sharing via public links
- Antivirus scanning, DLP, encryption at-rest (infrastructure concerns, not platform metadata)

## Design

### The Core Problem: Where to Store Per-File Data

Active Storage schema:

```
documents (your model)         active_storage_attachments        active_storage_blobs
┌──────────────┐              ┌─────────────────────────┐       ┌──────────────────┐
│ id           │◄──────────── │ record_type: "Document"  │       │ id               │
│ title        │              │ record_id: 1             │──────►│ filename         │
│ status       │              │ name: "files"            │       │ content_type     │
└──────────────┘              │ blob_id: 42              │       │ byte_size        │
                              └─────────────────────────┘       │ checksum         │
                                                                │ metadata (json)  │
                                                                └──────────────────┘
```

For `has_one_attached` — metadata fields can live directly on the parent model (one file = one row). No new infrastructure needed.

For `has_many_attached` — each file needs its own metadata row. Options considered:

| Approach | Pros | Cons |
|----------|------|------|
| Use blob `metadata` JSON column | Zero migration | Shared with AS internals, no indexes, global side-effects |
| **New `lcp_attachment_metadata` table** | Clean separation, indexable, extensible | Extra table and join |
| EAV key-value table | Unlimited flexibility | Over-engineered for structured metadata |

**Decision:** Attachment metadata is a **regular LCP dynamic model** — defined in YAML, built by ModelFactory, with its own table, fields, validations, presenter, and permissions. This reuses all existing platform infrastructure instead of inventing a parallel system.

### Data Model

The metadata model has a `belongs_to` association to `ActiveStorage::Attachment`. Its fields are defined in YAML like any other model — no hardcoded columns.

```
active_storage_attachments          lcp_document_metadata (example)
┌─────────────────────────┐        ┌──────────────────────────┐
│ id                      │◄────── │ attachment_id (FK, UQ)    │
│ record_type             │        │ description (string)      │
│ record_id               │        │ category (string/enum)    │
│ name                    │        │ tags (json)               │
│ blob_id                 │        │ position (integer)        │
│ created_at              │        │ ... any fields you define │
└─────────────────────────┘        └──────────────────────────┘
```

Because it's a standard LCP model, you get for free:
- **Field types** — string, enum, boolean, date, json, etc.
- **Validations** — presence, length, format, numericality
- **Positioning** — `position` field with `positioning: true` (drag & drop reorder scoped per parent record)
- **Permissions** — field-level read/write, role-based access
- **Custom fields** — runtime-defined fields if enabled
- **Presenters** — the metadata model can have its own presenter for standalone CRUD, or be rendered inline within the parent form

### YAML Configuration

The metadata model is a separate YAML file, like any other model. The parent model references it via `metadata_model`:

```yaml
# config/lcp_ruby/models/document_attachment.yml
name: document_attachment
positioning: true
fields:
  - name: attachment_id
    type: integer
    required: true
  - name: description
    type: string
    label: "Description"
  - name: category
    type: enum
    label: "Category"
    values: [contract, invoice, report, correspondence, other]
    default: other
  - name: tags
    type: json
    label: "Tags"
```

```yaml
# config/lcp_ruby/models/project.yml
name: project
fields:
  - name: title
    type: string
  - name: cover_image
    type: attachment
    options:
      accept: "image/*"
      max_size: "5MB"
      metadata_model: document_attachment   # works for single too
  - name: documents
    type: attachment
    options:
      multiple: true
      max_files: 20
      max_size: "50MB"
      metadata_model: document_attachment   # same model, different field
```

Key points:
- The metadata model is a **standalone YAML model** — full field definitions, validations, positioning
- `metadata_model` works on both `has_one_attached` and `has_many_attached`
- Multiple attachment fields can share the same metadata model, or each can have its own
- The `attachment_id` field links to `active_storage_attachments.id`

### Presenter Configuration

```yaml
# Presenter — show page
show:
  layout:
    - section: "Documents"
      fields:
        - field: documents
          renderer: attachment_table
          options:
            columns: [filename, category, description, size, uploaded_at]
            sortable: true

# Presenter — form
form:
  sections:
    - title: "Documents"
      fields:
        - field: documents
          input_options:
            drag_drop: true
            metadata_inline: true   # show metadata inputs next to each file
```

### UX Concept

On the form, each uploaded file expands to show its metadata fields inline:

```
┌─────────────────────────────────────────────────┐
│ ≡  faktura-2025-Q4.pdf  (2.3 MB)         [✕]   │
│    Description: [Quarterly invoice Q4     ]     │
│    Category:    [invoice ▾]                     │
│    Tags:        [finance] [quarterly] [+]       │
├─────────────────────────────────────────────────┤
│ ≡  smlouva-dodavatel.docx  (156 KB)       [✕]   │
│    Description: [Supplier agreement       ]     │
│    Category:    [contract ▾]                    │
│    Tags:        [legal] [+]                     │
├─────────────────────────────────────────────────┤
│         📎 Drop files here or click to upload    │
└─────────────────────────────────────────────────┘
```

- `≡` — drag handle for reordering (sort_position)
- `[✕]` — remove file
- Metadata fields appear after upload, before form save

## Edge Cases

- **Metadata lifecycle** — metadata record is created when attachment is created and destroyed with `dependent: :destroy`. Orphan cleanup needed if attachment is purged outside the normal flow.
- **Existing attachments** — adding `metadata_model` to a field that already has attachments: metadata rows are created lazily (on next edit/save), not via migration.
- **Enum values change** — if enum values are updated in YAML, existing records may have stale values. Same behavior as regular enum fields — no automatic migration.
- **Shared metadata model** — when multiple attachment fields reference the same metadata model, the `attachment_id` FK is the only discriminator. The metadata model doesn't need to know which field it belongs to.
- **Positioning scope** — `positioning: true` on the metadata model should scope position per parent record + attachment field name. This aligns with how the existing `positioning` infrastructure supports scoped columns.

## Open Questions

1. **Association mechanics** — the metadata model has `attachment_id` pointing to `active_storage_attachments`. This is a non-standard association (not a typical LCP model-to-model FK). How should `AttachmentApplicator` wire up the `has_one`/`has_many` relationship between the attachment and the metadata model? Should it monkey-patch `ActiveStorage::Attachment` or use a different approach?

2. **Inline editing UX** — when metadata is edited inline within the parent form, how are nested params structured and saved? This is similar to `nested_attributes` but goes through Active Storage attachments. Needs careful design of the form parameter structure.

3. **Standalone vs inline-only** — should the metadata model always have its own standalone presenter (list/show/edit), or can it be inline-only (edited exclusively within the parent form)? Both modes could be useful.

## Related Documents

- [Auditing](auditing.md) — attachment changes in audit log
- [Workflow and Approvals](workflow_and_approvals.md) — document approval workflows
- [Data Retention](data_retention.md) — automatic file cleanup policies
- [Attachments Guide](../guides/attachments.md) — current attachment implementation
