# Integration and API — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Metadata-Driven API

- [ ] REST API automatically generated for each entity (CRUD endpoints)
- [ ] GraphQL API automatically generated from metadata (schema, queries, mutations)
- [ ] API documentation automatically generated (OpenAPI / Swagger, GraphQL introspection)
- [ ] API versioning (v1, v2... — old versions run in parallel)
- [ ] API endpoints respect authorization rules (row-level, column-level, role-based)
- [ ] Partial response support (field selection — sparse fieldsets / GraphQL fields)
- [ ] Nested resource support (include related entities in one request)
- [ ] Filtering, sorting, pagination support via query parameters
- [ ] Bulk operations via API (batch create / update / delete)
- [ ] HATEOAS / hypermedia links (navigation between related resources)
- [ ] Content negotiation (JSON, XML, CSV — by Accept header)

## API Authentication and Authorization

- [ ] API key authentication (per application / per integration)
- [ ] OAuth2 / OIDC authentication (authorization code, client credentials)
- [ ] JWT token with configurable expiration
- [ ] Scoped API keys (key with limited permissions — read-only, specific entity only)
- [ ] Rate limiting per API key / per user / per endpoint
- [ ] IP whitelist per API key
- [ ] API key rotation without downtime (overlap period)
- [ ] API access audit log (who, when, which endpoint, response code)

## Outgoing Webhooks

- [ ] Webhook configuration from UI / metadata (without deployment)
- [ ] Triggers: create, update, delete, workflow state change, custom event
- [ ] Trigger filter (webhook fires only when condition met — e.g., state = approved)
- [ ] Configurable payload (entire record, changed fields only, custom template)
- [ ] Payload format (JSON, XML, form-encoded)
- [ ] Payload signing (HMAC signature for authenticity verification)
- [ ] Retry strategy on failure (exponential backoff, max retry count)
- [ ] Dead letter queue (failed webhooks for manual processing)
- [ ] Webhook log (call history — request, response, status code, latency)
- [ ] Manual re-trigger from UI (resend specific webhook)
- [ ] Timeout configuration per webhook
- [ ] Webhook deactivation / pause without deletion

## Incoming Webhooks

- [ ] Incoming webhook endpoints per entity / per action
- [ ] Incoming payload mapping to entity fields (field mapping from metadata)
- [ ] Incoming payload validation (schema validation, required fields)
- [ ] Sender verification (HMAC, API key, IP whitelist)
- [ ] Data transformation on receipt (expressions, lookup, default values)
- [ ] Idempotence (deduplication based on key — repeated calls don't create duplicates)
- [ ] Queue for processing (asynchronous incoming webhook processing)
- [ ] Incoming webhook log (raw payload, processing result, errors)

## Data Import

- [ ] Import from CSV / XLSX / JSON
- [ ] File column to entity field mapping (UI with preview)
- [ ] Automatic mapping detection (by column name)
- [ ] Pre-import validation (dry-run — show errors without saving)
- [ ] Partial import (import valid rows, skip erroneous ones)
- [ ] Duplicate strategy (skip, update, error — based on unique key)
- [ ] Transformation during import (trim, format, FK value lookup)
- [ ] Related record import (nested import — order with items)
- [ ] Scheduled / recurring import (from shared folder, FTP, S3)
- [ ] Large file import (streaming, background processing with progress bar)
- [ ] Import log (how many imported, skipped, errors — with per-row detail)
- [ ] Import undo / rollback (delete imported records)

## Data Export

- [ ] Export to CSV / XLSX / JSON / PDF / XML
- [ ] Export respects current filter, sorting, and visible columns
- [ ] Export respects permissions (column-level — hidden fields not exported)
- [ ] Configurable export templates (per entity — which fields, order, formatting)
- [ ] Related data export (flatten or nested)
- [ ] Scheduled / recurring export (cron → export → save to S3 / FTP / email)
- [ ] Asynchronous export for large datasets (background job with notification on completion)
- [ ] Streaming export (generation on-the-fly without holding entire dataset in memory)
- [ ] Export with change history (audit trail per record)
- [ ] GDPR data export (complete export of all user data)

## External System Connectors

- [ ] Connector framework (unified interface for all integrations)
- [ ] Connector configuration from UI / metadata (connection string, credentials, mapping)
- [ ] Credential management (encrypted storage, vault integration)
- [ ] Health check per connector (is external system available?)
- [ ] Circuit breaker pattern (automatic disconnect on repeated failure)
- [ ] Retry strategy per connector
- [ ] Connection pooling (efficient connection utilization)
- [ ] Logging and monitoring per connector (latency, error rate, throughput)

## Specific Connectors

- [ ] LDAP / Active Directory (user sync, groups, authentication)
- [ ] OAuth2 / OIDC provider (SSO integration)
- [ ] SMTP / IMAP (sending and receiving emails)
- [x] S3 / Azure Blob / MinIO (file storage) — Active Storage service adapters
- [ ] Business registries (company validation, data retrieval)
- [ ] ERP systems (SAP, etc. — via API or DB link)
- [ ] CRM systems (Salesforce, HubSpot...)
- [ ] Accounting systems
- [ ] DMS / SharePoint (document synchronization)
- [ ] Messaging (Slack, MS Teams — notifications, bots)
- [ ] Calendar (Google Calendar, Outlook — event sync)
- [ ] Payment gateway
- [ ] SMS gateway (sending SMS notifications)
- [ ] PDF generator (external service or library)
- [ ] E-signature (Signi, DocuSign — electronic signing)

## Data Synchronization

- [ ] One-way synchronization (push / pull)
- [ ] Bidirectional synchronization with conflict resolution
- [ ] Conflict resolution strategy (last-write-wins, source-priority, manual merge)
- [ ] Incremental sync (changes only since last sync — timestamp / change tracking)
- [ ] Full sync (complete re-sync — for initialization or correction)
- [ ] Scheduled sync (cron — every hour, daily, weekly...)
- [ ] Event-driven sync (immediate sync on change — via webhook / message queue)
- [ ] Field mapping between systems (field A in our platform = field B in external system)
- [ ] Data transformation during sync (format, units, lookup, enrichment)
- [ ] Sync log (what synchronized, what failed, conflicts)
- [ ] Sync status monitoring (last successful sync, pending change count)
- [ ] Manual sync trigger from UI

## Message Queue / Event Bus

- [x] Internal event bus (entity events: created, updated, deleted, state_changed) — Events::Dispatcher + HandlerRegistry
- [ ] Publishing events to external message broker (RabbitMQ, Kafka, Redis Streams)
- [ ] Consuming events from external broker
- [ ] Event schema defined from metadata (automatic serialization)
- [ ] Guaranteed delivery (at-least-once, exactly-once)
- [ ] Event replay (replay event history — for corrective syncs or new consumers)
- [ ] Dead letter queue for unsuccessfully processed events
- [ ] Event filtering (consumer subscribes only to relevant events)

## ETL and Data Pipelines

- [ ] Visual ETL designer (extract → transform → load steps)
- [ ] Sources: DB query, API call, file (CSV/XLSX/JSON), message queue
- [ ] Transforms: mapping, filtering, aggregation, lookup, enrichment, deduplication
- [ ] Targets: internal entity, external API, file, message queue
- [ ] Scheduled execution (cron)
- [ ] Manual execution from UI
- [ ] Pipeline monitoring (status, duration, processed record count, errors)
- [ ] Partial failure handling (continue vs. stop on error)
- [ ] Idempotent pipeline (repeated execution doesn't produce duplicates)

## API Gateway and Management

- [ ] Central API gateway (single entry point)
- [ ] API throttling / rate limiting (per tenant, per key, per endpoint)
- [ ] Request / response transformation (enrichment, stripping)
- [ ] API analytics (call count, latency, error rate per endpoint)
- [ ] API deprecation management (mark endpoints as deprecated, sunset date)
- [ ] CORS configuration per tenant / per application
- [ ] API sandbox / test environment (isolated from production)
- [ ] Mock API (generated from metadata for frontend development without backend)

## Integration Security

- [ ] Data encryption in-transit (TLS for all outgoing / incoming connections)
- [ ] Credential encryption at-rest (vault, KMS)
- [ ] Sensitive data masking in logs (API keys, passwords, personal data)
- [ ] Integration operation audit trail
- [ ] Least privilege principles (connectors have only needed permissions)
- [ ] Timeout and circuit breaker on all external calls
- [ ] Sandboxing (integration cannot affect platform core)

---

## Key Points

- **Metadata-driven API** — this is the main value of a low-code platform for integrators. Add an entity in metadata and the REST/GraphQL endpoint exists automatically. Without this, every integration is custom work.
- **Webhook signing (HMAC)** — without authenticity verification, anyone can send a fake webhook and manipulate data. HMAC signature is standard.
- **Idempotence for incoming webhooks** — in distributed environments, webhooks occasionally get delivered multiple times. Without a deduplication key, duplicate records are created.
- **Circuit breaker** — if an external system goes down, without circuit breaker the platform repeatedly calls a dead endpoint, floods queues, and the whole thing slows down.
- **Dry-run for import** — users import thousands of rows and then discover 80% have errors. Dry-run shows problems upfront without writing to DB.
- **Event replay** — extremely useful. When you add a new connector or fix a sync bug, you can replay event history and fill in data without manual intervention.
- **Import undo** — often overlooked but saves situations when someone imports the wrong file into production.
