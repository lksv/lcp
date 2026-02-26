# Scheduler and Background Jobs — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Job Definitions

- [ ] Jobs defined in metadata (without deployment)
- [ ] Job types: scheduled (cron), event-driven (trigger), manual (on-demand), chained (pipeline)
- [ ] Parameterized jobs (input parameters — date, entity, filter...)
- [ ] Job priority (high / normal / low — affects queue order)
- [ ] Job categorization (import, export, sync, notification, maintenance, reporting...)
- [ ] Job templates (pre-built patterns — daily sync, cleanup, report generation)
- [ ] Job definition versioning

## Scheduling

- [ ] Cron expressions (minutes, hours, days, months, weekdays)
- [ ] Human-readable scheduling (every day at 6:00, every Monday, first day of month...)
- [ ] One-time scheduling (run at specific date and time)
- [ ] Repeated execution with interval (every N minutes / hours)
- [ ] Business calendar (run only on business days / hours)
- [ ] Timezone-aware scheduling (job runs in user / tenant timezone)
- [ ] Blackout windows (don't run at defined times — maintenance windows, holidays)
- [ ] Dependency-based scheduling (job B runs only after job A completes)
- [ ] Debounce (if trigger fires multiple times quickly, run only once)

## Execution and Triggers

- [ ] Manual execution from UI ("Run now" button)
- [ ] Execution via API (REST endpoint for remote trigger)
- [x] Event trigger (execution on record change — create, update, delete, state change) — Events::Dispatcher + async handlers
- [ ] Webhook trigger (incoming webhook triggers job)
- [ ] File trigger (new file on FTP / S3 triggers import)
- [ ] Conditional trigger (run only if condition met — count > 0, flag = true)
- [ ] Trigger with debounce / throttle (max 1 execution per N seconds)
- [ ] Chained trigger (completion of one job triggers next)

## Processing and Execution

- [~] Asynchronous processing (job runs in background, doesn't block UI) — Active Job integration available in host app
- [ ] Worker pool (configurable number of parallel workers)
- [ ] Queues (named queues — separate queues for different job types)
- [ ] Priority queues (high-priority jobs jump ahead)
- [ ] Concurrency limits (max N instances of same job simultaneously)
- [ ] Singleton jobs (max 1 instance running at given time — deduplication)
- [ ] Idempotent jobs (repeated execution produces same result)
- [ ] Transactional processing (job completes entirely or rolls back)
- [ ] Batch processing (process large record count in batches with configurable size)
- [ ] Streaming processing (process record by record without holding entire dataset in memory)
- [ ] Timeout per job (kill after exceeding maximum runtime)
- [ ] Graceful shutdown (on server restart, complete running jobs or safely interrupt)

## Retry and Error Handling

- [ ] Automatic retry on failure (configurable attempt count)
- [ ] Retry strategy: fixed delay, exponential backoff, exponential backoff with jitter
- [ ] Configurable delay between retries
- [ ] Retry only for certain error types (transient vs. permanent failure)
- [ ] Dead letter queue (jobs that failed after all retries)
- [ ] Manual re-trigger from dead letter queue
- [ ] Partial failure handling (continue processing remainder on single record error)
- [ ] Compensating actions on failure (undo / cleanup)
- [ ] Circuit breaker (if job repeatedly fails, pause scheduling)

## Monitoring and Observability

- [ ] Running jobs dashboard (realtime overview — what's running, waiting, failed)
- [ ] Execution history per job (start time, end time, duration, status, error detail)
- [ ] Progress tracking (percentage progress — processed X of Y records)
- [ ] Live log streaming (display running job logs in real time)
- [ ] Metrics per job: average runtime, success rate, throughput
- [ ] Alerting on failure (email, Slack, webhook notification)
- [ ] Alerting on SLA breach (job running longer than usual)
- [ ] Alerting on queue fill (queue depth > threshold)
- [ ] Trend analysis (is job slowing down over time? is data volume growing?)
- [ ] Distributed tracing (trace ID across entire job chain)

## Administration

- [ ] UI for job management (list, detail, start, stop, pause, resume)
- [ ] Job activation / deactivation without deletion
- [ ] Manual kill of running job
- [ ] Bulk operations (stop all jobs of type X, restart failed)
- [ ] Worker pool configuration from UI (worker count, queue assignment)
- [ ] Job definition import / export between environments (dev → staging → prod)
- [ ] Dry-run mode (run job without actual side effects — for testing)
- [ ] Audit log (who created job, changed scheduling, manually triggered)

## Scaling and Infrastructure

- [ ] Horizontal worker scaling (add more worker nodes)
- [ ] Auto-scaling based on queue depth
- [ ] Kubernetes CronJobs / Jobs support
- [ ] Message broker support (Redis, RabbitMQ, Kafka) as queue backend
- [ ] Leader election (for singleton jobs in cluster — only one node triggers)
- [ ] Queue persistence (jobs survive server restart)
- [ ] Tenant isolation (one tenant's jobs don't affect another's performance)
- [ ] Resource limits per job / per tenant (CPU, memory, I/O)

## Built-in System Jobs

- [ ] Cleanup / garbage collection (temporary files, expired sessions, soft-deleted records)
- [ ] Search engine re-indexing
- [ ] Thumbnail / preview regeneration
- [ ] Old data archival
- [ ] DB maintenance (vacuum, analyze, index rebuild)
- [ ] External system health check
- [ ] External system synchronization (LDAP, ERP...)
- [ ] Scheduled report generation
- [ ] Digest notification sending (daily / weekly summary)
- [ ] SLA monitoring and escalation

---

## Key Points

- **Singleton jobs and leader election** — without this, the same cron job runs on every node in a cluster. In Kubernetes environments this is critical — you need either leader election or a CronJob resource.
- **Idempotence** — jobs occasionally run twice (retry, race condition). If a job isn't idempotent, it creates duplicates or corrupts data.
- **Graceful shutdown** — during deployment, the worker receives SIGTERM. Without graceful shutdown, the running job is interrupted mid-execution and data remains in an inconsistent state.
- **Tenant isolation** — one tenant with a massive import must not block the queue for others. Solution: separate queues per tenant or fair scheduling.
- **Dead letter queue** — without it, failed jobs disappear and nobody knows what happened. DLQ enables inspection, correction, and manual re-trigger.
- **Dry-run mode** — for testing jobs in production environments without real impact. Especially valuable for imports and synchronizations.
- **Distributed tracing** — when job A triggers job B, which calls an API and triggers job C, without a trace ID you have no chance of debugging a failure in the chain.
