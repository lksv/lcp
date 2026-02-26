# Files and Attachments — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## File Upload

- [x] Drag & drop upload (single and multi-file) — Active Storage direct upload
- [x] Upload via file picker dialog
- [ ] Paste from clipboard (images, screenshots)
- [ ] Upload from URL (download file from remote source)
- [ ] Upload from mobile device (camera, gallery)
- [ ] Chunked upload for large files (resumable — interrupted upload can be completed)
- [x] Progress bar with percentage upload status — Active Storage direct upload progress
- [ ] Parallel upload of multiple files simultaneously
- [x] Maximum file size (configurable per entity / per field / globally) — `max_size` validation
- [x] Maximum number of attachments per record (configurable) — `max_files` validation
- [ ] Maximum total attachment size per record / per tenant
- [x] Allowed MIME types / extensions (whitelist from metadata) — `content_type` validation with wildcards
- [ ] Forbidden MIME types / extensions (blacklist — .exe, .bat...)
- [ ] Backend MIME type validation (not just by extension, but magic bytes)
- [ ] Temporary upload (file uploaded but record not yet saved — garbage collection)

## Storage Backend

- [x] Storage abstraction (unified interface — local FS, S3, Azure Blob, MinIO, GCS) — Active Storage services
- [x] Storage configuration per tenant / per entity / per environment
- [ ] File encryption at-rest (server-side encryption)
- [ ] Content deduplication (content-addressable storage — same file stored once)
- [ ] Storage quotas per tenant / per user
- [ ] Storage usage monitoring (dashboard, alerting on limit reached)
- [ ] Migration between storage backends (move from local FS to S3 without downtime)
- [ ] Tiered storage (hot / cold — active files on fast storage, archived on cheap storage)
- [ ] Geographic replication (files close to user — CDN integration)

## File Metadata

- [x] Automatically captured metadata: name, size, MIME type, extension, uploaded_by, uploaded_at
- [x] File hash (SHA-256 — integrity, deduplication) — Active Storage checksum
- [ ] EXIF metadata for images (resolution, GPS, camera...)
- [ ] Custom metadata per file (description, category, tags — configurable from metadata)
- [ ] Full-text indexing of file content (PDF, DOCX, XLSX — text extraction)
- [ ] Language detection of file content
- [ ] OCR for scanned documents / images

## Previews and Thumbnails

- [x] Thumbnail generation for images (configurable dimensions) — Active Storage variants
- [ ] Thumbnail for PDF (first page)
- [ ] Thumbnail for video (frame from video)
- [ ] Icon by file type (for files without preview)
- [ ] In-browser preview for common formats (PDF, images, video, audio, text, CSV)
- [ ] Office document preview (DOCX, XLSX, PPTX — conversion to PDF or HTML)
- [x] Lazy loading thumbnails (on-demand generation, cache) — Active Storage variant processing
- [ ] Lightbox / gallery mode for images (arrow navigation, zoom)
- [ ] Audio / video player directly in UI

## Image Processing

- [x] Automatic resize on upload (generating variants — thumbnail, medium, large) — Active Storage variants config
- [ ] Crop / trim (defined aspect ratio per field — e.g., 1:1 for avatar)
- [ ] Watermark (automatic watermark addition per entity / per tenant)
- [ ] Format conversion (PNG → WebP, TIFF → JPEG for optimization)
- [ ] Image compression (configurable quality level)
- [ ] Strip EXIF metadata (privacy protection — remove GPS coordinates)
- [ ] Generate responsive variants (srcset for different devices)

## Document Processing

- [ ] PDF generation from templates (Mustache / Handlebars + record data → PDF)
- [ ] PDF merge (combine multiple PDFs into one)
- [ ] PDF split (split PDF into pages)
- [ ] PDF signing (e-signature, stamp, timestamp)
- [ ] Conversion to PDF (DOCX → PDF, XLSX → PDF, HTML → PDF)
- [ ] PDF form filling from record data
- [ ] DOCX generation from templates (mail merge style)
- [ ] XLSX report generation from data

## File Versioning

- [ ] File version history (each re-upload creates a new version)
- [ ] Version list display with metadata (who, when, size)
- [ ] Version comparison (diff for text files, visual comparison for images)
- [ ] Download any historical version
- [ ] Restore older version as current
- [ ] Configurable maximum number of versions (per entity / globally)
- [ ] Automatic old version deletion (retention policy)
- [ ] File locking during editing (check-out / check-in pattern)

## File Organization and Management

- [x] Attachments bound to record (attachment per entity)
- [ ] Shared file library (global storage, independent of record)
- [ ] Folder structure (virtual folders, tags, categories)
- [ ] Moving files between records / folders
- [ ] Linking one file to multiple records (without duplication — reference link)
- [ ] Attachment ordering (drag & drop order, default sorting)
- [ ] Bulk operations (multi-select → download ZIP, delete, move)
- [ ] Trash / soft-delete files (recovery after deletion)
- [ ] Favorite / pinned files

## Sharing and Access

- [ ] Shared link generation (public link with token)
- [ ] Time-limited link (link expires after X hours / days)
- [ ] Password-protected link
- [ ] Download count limit per link
- [ ] Share specific file version
- [x] File permissions by role (view, download, upload, delete) — field-level permissions apply to attachment fields
- [ ] Permissions per folder / per category
- [ ] Watermark on download (visible identifier — who downloaded)
- [ ] Download prohibition (view-only mode — preview yes, download no)

## Security

- [ ] Antivirus scan on upload (ClamAV or cloud service)
- [ ] Suspicious file quarantine (inaccessible until manual verification)
- [ ] File content validation (not just MIME type — polyglot file detection)
- [ ] Stripping macros / hidden content (macros in DOCX/XLSX, JS in PDF)
- [ ] File encryption at-rest (AES-256)
- [ ] Encryption in-transit (TLS)
- [x] Signed URLs for direct storage access (pre-signed S3 URLs) — Active Storage service URLs
- [ ] File access audit log (who downloaded, who viewed, who deleted)
- [ ] Data Loss Prevention (DLP) — sensitive data detection in files (SSN, card numbers)
- [ ] Retention policy (automatic file deletion after expiration — GDPR, compliance)

## External System Integration

- [ ] SharePoint / OneDrive synchronization
- [ ] Google Drive synchronization
- [ ] S3 bucket synchronization (bidirectional)
- [ ] Import from email (email attachments → record attachments)
- [ ] DMS integration (Alfresco, M-Files...)
- [ ] E-signature service integration (Signi, DocuSign — send for signing, download signed)
- [ ] Webhook / event on new file upload

## Performance and Optimization

- [ ] CDN for static file distribution (thumbnails, public documents)
- [ ] Lazy loading attachments (load attachment list asynchronously, not with entire record)
- [ ] Streaming download for large files
- [ ] Compression on download (ZIP on-the-fly for multi-file download)
- [x] Background processing (thumbnail generation, OCR, virus scan — asynchronous) — Active Storage async processing
- [x] Thumbnail and preview caching (with invalidation on file change)
- [ ] Mobile network optimization (progressive loading, smaller image variants)

## Bulk Operations

- [ ] Bulk upload (ZIP file → unpack and assign to records)
- [ ] Bulk download (select records → ZIP with all attachments)
- [ ] Bulk file migration between storage backends
- [ ] Bulk reprocessing (regenerate thumbnails, re-scan antivirus)
- [ ] File import from FTP / SFTP (scheduled cron job)

---

## Key Points

- **Antivirus scan** — in enterprise environments it's mandatory. Without it, a user uploads an infected file and spreads it to everyone who downloads it.
- **Chunked / resumable upload** — without it, uploading a 500 MB file on a slow connection fails and the user starts over. The tus.io protocol is a good standard.
- **Backend MIME type validation** — extension checking is insufficient. A user renames .exe to .pdf and it passes. Magic bytes validation detects the actual file type.
- **Deduplication** — in systems with thousands of users, the same document (template, logo, email attachment) gets uploaded hundreds of times. Content-addressable storage saves tens of percent of storage.
- **Retention policy and GDPR** — files containing personal data must be deletable on request and automatically after expiration. Without retention policy, storage fills indefinitely and you can't demonstrate compliance during a GDPR audit.
- **Signed URLs** — instead of downloading files through the application server (bottleneck), generate a pre-signed URL directly to S3. The client downloads directly from storage, offloading the application server.
- **File locking (check-out / check-in)** — without it, two users edit the same DOCX, both upload their version, and one overwrites the other's changes. A pessimistic lock prevents this.
- **DLP detection** — sensitive data (SSN, card numbers) in uploaded files is a compliance risk. Automatic detection and alerting saves manual audit effort.
