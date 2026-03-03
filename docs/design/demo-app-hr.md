# Demo Application Design: HR Management System

**Status:** Proposed
**Date:** 2026-03-03

## 1. Why HR (and not Issues Tracker)

| Criterion | HR System | Issues Tracker |
|-----------|-----------|----------------|
| Domain complexity | Very high — people, org structure, leave, recruitment, reviews, assets, training | Medium — issues, projects, labels, milestones |
| Model count | 20+ interconnected models | 8–12 models |
| Natural tree structures | Departments (org chart), positions (hierarchy), skills (taxonomy) | Only project → sub-project |
| Permission complexity | Multi-level: admin, HR, manager (sees team), employee (sees self) | Simpler: admin, project lead, member |
| Approval workflows | Leave requests, expense claims, job requisitions — multiple approval patterns | Only issue status transitions |
| Overlap with existing examples | None — CRM covers sales, Todo covers task management | Partially overlaps with Todo (task tracking) |
| Real-world relatability | Every company has HR — universally understood domain | Developer-specific domain |
| Custom fields use case | Very natural — every company tracks different employee attributes | Less compelling — issue metadata is fairly standard |
| Attachment diversity | Photos, CVs, contracts, certificates, receipts | Mostly screenshots and logs |
| Reporting needs | Headcount, turnover, leave balances, department budgets | Mostly velocity/burndown charts |

**Recommendation:** HR system. It exercises nearly every platform feature, has a naturally complex and interconnected model, and produces a visually impressive demo that non-technical stakeholders can immediately understand.

---

## 2. Data Model Overview

### 2.1 Entity Relationship Diagram (conceptual)

```
                          ┌──────────────┐
                          │  Department  │ ◄── tree (divisions → departments → teams)
                          │              │
                          └──────┬───────┘
                                 │ 1:N
                          ┌──────▼───────┐        ┌──────────────┐
                          │   Employee   │───────►│   Position   │ ◄── tree (hierarchy)
                          │  (central)   │ N:1    │              │
                          └──┬──┬──┬──┬──┘        └──────────────┘
                             │  │  │  │
              ┌──────────────┘  │  │  └──────────────────────┐
              │                 │  │                          │
      ┌───────▼──────┐  ┌──────▼──────┐  ┌──────────────┐  ┌▼──────────────┐
      │ LeaveRequest │  │ Performance │  │    Asset      │  │   Document    │
      │              │  │   Review    │  │  Assignment   │  │               │
      └──────────────┘  └─────────────┘  └───────┬──────┘  └───────────────┘
              │                │                  │
      ┌───────▼──────┐  ┌─────▼───────┐  ┌──────▼───────┐
      │  LeaveType   │  │    Goal     │  │    Asset     │
      │              │  │             │  │              │
      └──────────────┘  └─────────────┘  └──────────────┘
              │
      ┌───────▼──────┐        ┌──────────────┐       ┌──────────────┐
      │ LeaveBalance │        │   Training   │       │  JobPosting  │
      │              │        │   Course     │       │              │
      └──────────────┘        └──────┬───────┘       └──────┬───────┘
                                     │                      │
                              ┌──────▼───────┐       ┌──────▼───────┐
                              │  Enrollment  │       │  Candidate   │
                              │              │       │              │
                              └──────────────┘       └──────┬───────┘
                                                            │
                                                     ┌──────▼───────┐
                                                     │  Interview   │
                                                     │              │
                                                     └──────────────┘

      ┌──────────────┐       ┌──────────────┐
      │    Skill     │◄──────│ EmployeeSkill│  (many-to-many)
      │  (taxonomy)  │       │              │
      └──────────────┘       └──────────────┘

      ┌──────────────┐
      │ ExpenseClaim │  (employee expenses with approval)
      └──────────────┘

      ┌──────────────┐
      │  Announcement│  (company-wide HR announcements)
      └──────────────┘
```

### 2.2 Model Definitions

Below is each model with fields, associations, and notable platform features used.

---

#### Department (tree structure)

```yaml
options:
  tree: true           # org chart hierarchy
  soft_delete: true
  auditing: true
  custom_fields: true
  userstamps: true

fields:
  name:        { type: string, null: false }
  code:        { type: string, null: false }   # e.g. "ENG-BE"
  description: { type: text }
  budget:      { type: decimal, precision: 12, scale: 2 }
  active:      { type: boolean, default: true }
  head_id:     { type: integer }  # FK to Employee (department head)

associations:
  belongs_to: employee (as head, optional)
  has_many: employees
  has_many: job_postings
```

**Features exercised:** tree structure (org chart), soft delete, auditing, custom fields, userstamps, decimal field, boolean default, self-referential (tree parent), cross-model FK (head → Employee).

---

#### Position (tree structure)

```yaml
options:
  tree: true         # VP → Director → Manager → Senior → Junior
  positioning: true  # sort order within siblings
  soft_delete: true

fields:
  title:       { type: string, null: false }
  code:        { type: string, null: false }   # e.g. "SWE-SR"
  level:       { type: integer }               # numeric grade (1-15)
  min_salary:  { type: decimal, precision: 10, scale: 2 }
  max_salary:  { type: decimal, precision: 10, scale: 2 }
  active:      { type: boolean, default: true }

associations:
  has_many: employees
```

**Features exercised:** tree structure, positioning (drag-and-drop sibling ordering), salary range validation (min < max cross-field), soft delete.

---

#### Employee (central entity)

```yaml
options:
  soft_delete: true
  auditing: true
  custom_fields: true
  userstamps: true

fields:
  first_name:      { type: string, null: false, transforms: [strip, titlecase] }
  last_name:       { type: string, null: false, transforms: [strip, titlecase] }
  full_name:       { type: string, computed: "{first_name} {last_name}" }
  personal_email:  { type: email }
  work_email:      { type: email, null: false }
  phone:           { type: phone }
  date_of_birth:   { type: date }
  hire_date:       { type: date, null: false }
  termination_date:{ type: date }
  status:
    type: enum
    values: [active, on_leave, suspended, terminated]
    default: active
  employment_type:
    type: enum
    values: [full_time, part_time, contract, intern]
  gender:
    type: enum
    values: [male, female, other, prefer_not_to_say]
  salary:          { type: decimal, precision: 10, scale: 2 }
  currency:
    type: enum
    values: [CZK, EUR, USD, GBP]
    default: CZK
  photo:
    type: attachment
    options: { accept: "image/*", max_size: "5MB", variants: { thumbnail: { resize_to_fill: [80, 80] }, medium: { resize_to_limit: [300, 300] } } }
  cv:
    type: attachment
    options: { max_size: "10MB", content_types: [application/pdf] }
  address:
    type: json
    # JSON sub-fields: street, city, zip, country
  emergency_contact:
    type: json
    # JSON sub-fields: name, phone, relationship
  notes:           { type: rich_text }

associations:
  belongs_to: department (required)
  belongs_to: position (required)
  belongs_to: employee (as manager, optional)  # direct manager
  has_many: employees (as subordinates, through manager_id)
  has_many: leave_requests
  has_many: leave_balances
  has_many: performance_reviews
  has_many: goals
  has_many: employee_skills
  has_many: skills (through employee_skills)
  has_many: asset_assignments
  has_many: documents
  has_many: training_enrollments
  has_many: expense_claims

scopes:
  active:       { where: { status: active } }
  on_leave:     { where: { status: on_leave } }
  terminated:   { where: { status: terminated } }
  by_department: (dynamic — parameter-based scope for permission filtering)
```

**Features exercised:** computed fields (full_name), custom types (email, phone), transforms (titlecase), enums (multiple), attachments (photo with variants, CV), JSON fields (address, emergency contact) with nested form sub-sections, rich text (notes), soft delete, auditing, custom fields, userstamps, self-referential (manager), multiple associations, multiple scopes, conditional validations (termination_date required when status = terminated).

---

#### LeaveType

```yaml
fields:
  name:             { type: string, null: false }
  code:             { type: string, null: false }
  color:            { type: color }               # calendar color coding
  default_days:     { type: integer, default: 0 }
  requires_approval:{ type: boolean, default: true }
  requires_document:{ type: boolean, default: false }
  active:           { type: boolean, default: true }

options:
  positioning: true   # display order in dropdowns
```

**Features exercised:** color type (calendar/badge coloring), positioning, boolean fields, sensible defaults.

---

#### LeaveRequest

```yaml
options:
  auditing: true
  userstamps: true

fields:
  start_date:    { type: date, null: false }
  end_date:      { type: date, null: false }
  days_count:    { type: decimal, precision: 4, scale: 1 }   # supports half-days
  status:
    type: enum
    values: [draft, pending, approved, rejected, cancelled]
    default: draft
  reason:        { type: text }
  rejection_note:{ type: text }
  approved_by_id:{ type: integer }  # FK to Employee
  approved_at:   { type: datetime }
  attachment:
    type: attachment
    options: { max_size: "10MB", content_types: [application/pdf, image/jpeg, image/png] }

associations:
  belongs_to: employee (required)
  belongs_to: leave_type (required)
  belongs_to: employee (as approved_by, optional)

validations:
  - end_date >= start_date (cross-field)
  - attachment required when leave_type.requires_document (conditional via service)
  - balance check (custom service validator — enough remaining days)
```

**Features exercised:** auditing, userstamps, cross-field validation, conditional validation (attachment required based on leave type), custom service validator (balance check), enum with workflow-like states, record rules (no edit after approved), custom actions (approve, reject, cancel), event handlers (on status change).

---

#### LeaveBalance

```yaml
fields:
  year:         { type: integer, null: false }
  total_days:   { type: decimal, precision: 4, scale: 1, null: false }
  used_days:    { type: decimal, precision: 4, scale: 1, default: 0 }
  remaining:    { type: decimal, precision: 4, scale: 1, computed: { service: "leave_remaining" } }

associations:
  belongs_to: employee (required)
  belongs_to: leave_type (required)

scopes:
  current_year: { where: { year: <dynamic current year> } }
```

**Features exercised:** computed field via service, decimal precision for half-days, unique constraint (employee + leave_type + year).

---

#### PerformanceReview

```yaml
options:
  auditing: true
  userstamps: true

fields:
  review_period:
    type: enum
    values: [q1, q2, q3, q4, annual]
  year:           { type: integer, null: false }
  status:
    type: enum
    values: [draft, self_review, manager_review, completed, acknowledged]
    default: draft
  self_rating:
    type: integer
    # 1-5 scale, rendered as stars/rating
  manager_rating: { type: integer }
  overall_rating: { type: integer }
  self_comments:  { type: text }
  manager_comments:{ type: text }
  goals_summary:  { type: text }
  strengths:      { type: text }
  improvements:   { type: text }
  completed_at:   { type: datetime }

associations:
  belongs_to: employee (required)
  belongs_to: employee (as reviewer, required)  # manager who reviews
  has_many: goals
```

**Features exercised:** auditing, userstamps, multi-step status enum (simulating workflow), conditional rendering (self_rating visible only in self_review+, manager fields visible only in manager_review+), record rules (no edit after completed), custom action (submit for review, complete review, acknowledge).

---

#### Goal

```yaml
options:
  positioning: true   # priority order
  userstamps: true

fields:
  title:       { type: string, null: false }
  description: { type: text }
  status:
    type: enum
    values: [not_started, in_progress, completed, cancelled]
    default: not_started
  priority:
    type: enum
    values: [low, medium, high, critical]
    default: medium
  due_date:    { type: date }
  progress:    { type: integer, default: 0 }   # 0-100
  weight:      { type: integer, default: 1 }   # weight for weighted average

associations:
  belongs_to: employee (required)
  belongs_to: performance_review (optional)
```

**Features exercised:** positioning (drag-and-drop priority), progress renderer, enum fields, conditional rendering (progress visible when not not_started).

---

#### Skill (tree structure)

```yaml
options:
  tree: true   # taxonomy: "Technical" → "Programming" → "Ruby"

fields:
  name:        { type: string, null: false }
  description: { type: text }
  category:
    type: enum
    values: [technical, soft, language, certification]
```

**Features exercised:** tree structure (skill taxonomy), enum categorization.

---

#### EmployeeSkill (many-to-many join)

```yaml
fields:
  proficiency:
    type: enum
    values: [beginner, intermediate, advanced, expert]
  certified:    { type: boolean, default: false }
  certified_at: { type: date }
  expires_at:   { type: date }
  certificate:
    type: attachment
    options: { max_size: "5MB", content_types: [application/pdf, image/jpeg, image/png] }

associations:
  belongs_to: employee (required)
  belongs_to: skill (required)
```

**Features exercised:** many-to-many through join model with extra attributes, enum proficiency, conditional field (certificate visible when certified = true, expires_at visible when certified = true), attachment.

---

#### Asset

```yaml
options:
  soft_delete: true
  auditing: true
  custom_fields: true

fields:
  name:          { type: string, null: false }
  asset_tag:     { type: string, null: false }    # unique identifier like "LAP-2024-0042"
  category:
    type: enum
    values: [laptop, phone, monitor, desk, chair, vehicle, access_card, other]
  brand:         { type: string }
  model_name:    { type: string }
  serial_number: { type: string }
  purchase_date: { type: date }
  purchase_price:{ type: decimal, precision: 10, scale: 2 }
  warranty_until:{ type: date }
  status:
    type: enum
    values: [available, assigned, in_repair, retired]
    default: available
  photo:
    type: attachment
    options: { accept: "image/*", max_size: "5MB" }
  notes:         { type: text }

associations:
  has_many: asset_assignments

scopes:
  available:  { where: { status: available } }
  assigned:   { where: { status: assigned } }
```

**Features exercised:** soft delete, auditing, custom fields, unique asset tag, enum status, attachment (photo), multiple scopes, custom action (assign, return, retire), record rules (can't delete assigned assets).

---

#### AssetAssignment

```yaml
options:
  userstamps: true
  auditing: true

fields:
  assigned_at:  { type: date, null: false }
  returned_at:  { type: date }
  condition_on_assign:
    type: enum
    values: [new, good, fair, poor]
  condition_on_return:
    type: enum
    values: [good, fair, poor, damaged]
  notes:        { type: text }

associations:
  belongs_to: asset (required)
  belongs_to: employee (required)
```

**Features exercised:** userstamps, auditing, conditional field (condition_on_return + returned_at visible only when returning), event handler (update asset status on assign/return).

---

#### Document

```yaml
options:
  userstamps: true

fields:
  title:        { type: string, null: false }
  category:
    type: enum
    values: [contract, amendment, certificate, id_document, tax_form, review, other]
  description:  { type: text }
  file:
    type: attachment
    options: { max_size: "25MB", multiple: true, max_files: 5 }
  confidential: { type: boolean, default: false }
  valid_from:   { type: date }
  valid_until:  { type: date }

associations:
  belongs_to: employee (required)
```

**Features exercised:** userstamps, multiple file attachments, enum category, boolean (confidential), date range, field-level permission (salary-related documents restricted by role).

---

#### TrainingCourse

```yaml
options:
  soft_delete: true

fields:
  title:        { type: string, null: false }
  description:  { type: rich_text }
  category:
    type: enum
    values: [onboarding, technical, compliance, leadership, safety, other]
  format:
    type: enum
    values: [in_person, online, hybrid]
  duration_hours:{ type: decimal, precision: 5, scale: 1 }
  max_participants:{ type: integer }
  instructor:   { type: string }
  location:     { type: string }
  url:          { type: url }
  starts_at:    { type: datetime }
  ends_at:      { type: datetime }
  active:       { type: boolean, default: true }

associations:
  has_many: training_enrollments

scopes:
  upcoming:   { where: "starts_at > now", order: { starts_at: asc } }
  active:     { where: { active: true } }
```

**Features exercised:** rich text (description), url type, datetime fields, soft delete, conditional fields (location visible when format = in_person/hybrid, url visible when format = online/hybrid).

---

#### TrainingEnrollment

```yaml
options:
  userstamps: true

fields:
  status:
    type: enum
    values: [enrolled, completed, cancelled, no_show]
    default: enrolled
  completed_at: { type: datetime }
  score:        { type: integer }       # test score (0-100)
  feedback:     { type: text }
  certificate:
    type: attachment
    options: { max_size: "5MB", content_types: [application/pdf] }

associations:
  belongs_to: employee (required)
  belongs_to: training_course (required)
```

**Features exercised:** userstamps, enum status, conditional fields (score/certificate visible when completed), custom action (mark complete, cancel).

---

#### JobPosting

```yaml
options:
  soft_delete: true
  auditing: true
  userstamps: true

fields:
  title:        { type: string, null: false }
  description:  { type: rich_text }
  status:
    type: enum
    values: [draft, open, on_hold, closed, filled]
    default: draft
  employment_type:
    type: enum
    values: [full_time, part_time, contract, intern]
  location:     { type: string }
  remote_option:
    type: enum
    values: [on_site, hybrid, remote]
  salary_min:   { type: decimal, precision: 10, scale: 2 }
  salary_max:   { type: decimal, precision: 10, scale: 2 }
  currency:
    type: enum
    values: [CZK, EUR, USD, GBP]
    default: CZK
  headcount:    { type: integer, default: 1 }
  published_at: { type: datetime }
  closes_at:    { type: date }

associations:
  belongs_to: department (required)
  belongs_to: position (required)
  belongs_to: employee (as hiring_manager, required)
  has_many: candidates

scopes:
  open:     { where: { status: open } }
  draft:    { where: { status: draft } }
```

**Features exercised:** rich text, soft delete, auditing, userstamps, salary range, conditional rendering (salary fields visible only for certain roles), record rules (closed postings not editable), custom action (publish, close, put on hold), multiple scopes.

---

#### Candidate

```yaml
options:
  auditing: true
  userstamps: true

fields:
  first_name:  { type: string, null: false, transforms: [strip, titlecase] }
  last_name:   { type: string, null: false, transforms: [strip, titlecase] }
  full_name:   { type: string, computed: "{first_name} {last_name}" }
  email:       { type: email, null: false }
  phone:       { type: phone }
  status:
    type: enum
    values: [applied, screening, interviewing, offer, hired, rejected, withdrawn]
    default: applied
  source:
    type: enum
    values: [website, referral, linkedin, agency, job_board, other]
  resume:
    type: attachment
    options: { max_size: "10MB", content_types: [application/pdf] }
  cover_letter: { type: text }
  rating:       { type: integer }    # 1-5, rendered as stars
  notes:        { type: rich_text }
  rejection_reason: { type: text }

associations:
  belongs_to: job_posting (required)
  has_many: interviews
```

**Features exercised:** auditing, userstamps, transforms, computed field, custom types (email, phone), attachment (resume), rich text, enum (status, source), conditional field (rejection_reason visible when rejected), rating renderer, record rules (can't edit hired/rejected candidates), custom actions (advance stage, reject, hire).

---

#### Interview

```yaml
options:
  userstamps: true

fields:
  interview_type:
    type: enum
    values: [phone_screen, technical, behavioral, panel, final]
  scheduled_at:   { type: datetime, null: false }
  duration_minutes:{ type: integer, default: 60 }
  location:       { type: string }
  meeting_url:    { type: url }
  status:
    type: enum
    values: [scheduled, completed, cancelled, no_show]
    default: scheduled
  rating:         { type: integer }    # 1-5
  feedback:       { type: text }
  recommendation:
    type: enum
    values: [strong_yes, yes, neutral, no, strong_no]
  notes:
    type: json
    # Structured scorecard: { communication: 4, technical: 3, culture_fit: 5 }

associations:
  belongs_to: candidate (required)
  belongs_to: employee (as interviewer, required)
```

**Features exercised:** userstamps, multiple enums, url type, datetime, JSON field (structured scorecard with nested sub-section in form), conditional fields (feedback/rating/recommendation visible when completed), custom action (complete interview, cancel).

---

#### ExpenseClaim

```yaml
options:
  auditing: true
  userstamps: true

fields:
  title:        { type: string, null: false }
  description:  { type: text }
  amount:       { type: decimal, precision: 10, scale: 2, null: false }
  currency:
    type: enum
    values: [CZK, EUR, USD, GBP]
    default: CZK
  category:
    type: enum
    values: [travel, meals, accommodation, equipment, education, other]
  status:
    type: enum
    values: [draft, submitted, approved, rejected, reimbursed]
    default: draft
  receipt:
    type: attachment
    options: { multiple: true, max_files: 10, max_size: "10MB" }
  expense_date:  { type: date, null: false }
  approved_by_id:{ type: integer }
  approved_at:   { type: datetime }
  rejection_note:{ type: text }
  items:
    type: json
    # JSON array of line items: [{description, amount, category}]

associations:
  belongs_to: employee (required)
  belongs_to: employee (as approved_by, optional)
```

**Features exercised:** auditing, userstamps, decimal, multiple attachments (receipts), enum (category, status), JSON field with nested_fields section (expense line items), conditional fields (rejection_note when rejected), record rules (no edit after approved), custom actions (submit, approve, reject), event handler (notification on approval).

---

#### Announcement

```yaml
options:
  userstamps: true
  soft_delete: true

fields:
  title:       { type: string, null: false }
  body:        { type: rich_text }
  priority:
    type: enum
    values: [normal, important, urgent]
    default: normal
  published:   { type: boolean, default: false }
  published_at:{ type: datetime }
  expires_at:  { type: date }
  pinned:      { type: boolean, default: false }

associations:
  belongs_to: department (optional)  # nil = company-wide

scopes:
  published: { where: { published: true } }
  active:    combined scope (published + not expired)
```

**Features exercised:** rich text, userstamps, soft delete, enum priority, boolean (published, pinned), conditional rendering (published_at auto-set when published = true).

---

### 2.3 Model Count and Feature Coverage Matrix

| # | Model | Tree | SoftDel | Audit | CustFld | Usrstmp | Position | Attach | JSON | RichTxt | CompFld | Enums |
|---|-------|------|---------|-------|---------|---------|----------|--------|------|---------|---------|-------|
| 1 | Department | X | X | X | X | X | | | | | | 1 |
| 2 | Position | X | X | | | | X | | | | | 1 |
| 3 | Employee | | X | X | X | X | | X(2) | X(2) | X | X | 4 |
| 4 | LeaveType | | | | | | X | | | | | 0 |
| 5 | LeaveRequest | | | X | | X | | X | | | | 1 |
| 6 | LeaveBalance | | | | | | | | | | X | 0 |
| 7 | PerformanceReview | | | X | | X | | | | | | 2 |
| 8 | Goal | | | | | X | X | | | | | 2 |
| 9 | Skill | X | | | | | | | | | | 1 |
| 10 | EmployeeSkill | | | | | | | X | | | | 1 |
| 11 | Asset | | X | X | X | | | X | | | | 2 |
| 12 | AssetAssignment | | | X | | X | | | | | | 2 |
| 13 | Document | | | | | X | | X | | | | 1 |
| 14 | TrainingCourse | | X | | | | | | | X | | 2 |
| 15 | TrainingEnrollment | | | | | X | | X | | | | 1 |
| 16 | JobPosting | | X | X | | X | | | | X | | 4 |
| 17 | Candidate | | | X | | X | | X | | X | X | 2 |
| 18 | Interview | | | | | X | | | X | | | 3 |
| 19 | ExpenseClaim | | | X | | X | | X | X | | | 3 |
| 20 | Announcement | | X | | | X | | | | X | | 1 |
| **Total** | | **3** | **8** | **9** | **3** | **14** | **3** | **8** | **4** | **5** | **3** | **31** |

---

## 3. Platform Feature Coverage

### 3.1 Features demonstrated (with specific model examples)

| Platform Feature | Models/Scenarios | Notes |
|---|---|---|
| **Tree structures** | Department (org chart), Position (hierarchy), Skill (taxonomy) | 3 independent trees with different semantics |
| **Tree index view** | Department, Skill | Expand/collapse, guide lines, reparenting |
| **Tree select** | Employee form (department, position), Goal form | Parent selection in forms |
| **Soft delete** | Employee, Department, Position, Asset, JobPosting, TrainingCourse, Announcement | 7 models with archive/restore |
| **Auditing** | Employee, LeaveRequest, PerformanceReview, Asset, JobPosting, Candidate, ExpenseClaim, AssetAssignment, Department | 9 models with full change tracking |
| **Custom fields** | Employee, Department, Asset | 3 models with runtime field definitions |
| **Userstamps** | 14 models | Nearly all operational models |
| **Positioning** | Position (sibling order), LeaveType (display order), Goal (priority order) | 3 models with drag-and-drop |
| **Attachments** | Employee (photo+CV), Document (multi-file), Candidate (resume), Asset (photo), LeaveRequest, ExpenseClaim (receipts), EmployeeSkill (certificate), TrainingEnrollment (certificate) | 8 models, both single and multi-file, with variants |
| **JSON fields** | Employee (address, emergency contact), Interview (scorecard), ExpenseClaim (line items) | 4 JSON fields with nested sub-sections |
| **Rich text** | Employee (notes), TrainingCourse (description), JobPosting (description), Candidate (notes), Announcement (body) | 5 models |
| **Computed fields** | Employee (full_name template), Candidate (full_name template), LeaveBalance (remaining via service) | Both template and service-based |
| **Custom types** | Employee (email×2, phone), Candidate (email, phone), TrainingCourse (url), Interview (url) | email, phone, url |
| **Color type** | LeaveType (calendar color) | color_swatch renderer |
| **Transforms** | Employee (titlecase names), Candidate (titlecase names) | strip + titlecase |
| **Conditional rendering** | LeaveRequest (attachment conditional on type), PerformanceReview (fields by status), Interview (feedback on complete), EmployeeSkill (cert fields when certified), TrainingCourse (location/url by format), ExpenseClaim (rejection_note when rejected) | visible_when + disable_when on both fields and sections |
| **Service conditions** | LeaveRequest (balance check), Document (confidential check) | Server-side re-evaluation |
| **Record rules** | LeaveRequest (no edit after approved), PerformanceReview (no edit after completed), Asset (no delete when assigned), JobPosting (no edit when closed), Candidate (no edit when hired/rejected), ExpenseClaim (no edit after approved) | 6 models with conditional CRUD denial |
| **Custom actions** | LeaveRequest (approve/reject), PerformanceReview (submit/complete), Asset (assign/return/retire), JobPosting (publish/close), Candidate (advance/reject/hire), Interview (complete/cancel), ExpenseClaim (submit/approve/reject), TrainingEnrollment (complete/cancel) | 8 models with rich custom actions |
| **Event handlers** | LeaveRequest (on approval → update balance), Candidate (on hire → create employee?), Asset (on assign/return → update status), PerformanceReview (on complete) | Cross-model side effects |
| **Custom validators** | LeaveRequest (balance service), Employee (termination date required when terminated), ExpenseClaim (receipt required for amounts > threshold) | Service-based validation |
| **Scopes** | Employee (active/on_leave/terminated), Asset (available/assigned), JobPosting (open/draft), TrainingCourse (upcoming/active), Announcement (published/active), LeaveRequest (pending/approved) | Multiple scopes per model |
| **Advanced search** | Employee (by department, position, status, hire date range, skills), Candidate (by posting, status, rating), Asset (by category, status, warranty) | Complex filter configurations |
| **Multiple presenters** | Employee (full, directory/short, org chart), Deal-like patterns from CRM | Different views of same data |
| **View groups** | Employee (management vs directory), Recruitment (postings + candidates), Leave management | Multi-presenter navigation |
| **Menu with badges** | Pending leave approvals count, open positions count, pending expense claims | Dynamic badge providers |
| **Roles** | admin, hr_manager, manager, employee | 4 roles with very different access |
| **Scoped permissions** | manager sees own team (department scope), employee sees own data (field_match) | Row-level security |
| **Field-level permissions** | Salary visible only to admin/HR, personal data restricted, confidential documents | readable_by, writable_by, masked_for |
| **Dot-path fields** | Employee show: department.name, position.title, manager.full_name | Associated data display |
| **Association lists** | Employee show: leave requests, documents, skills, assets | Related records sections |
| **Nested fields** | ExpenseClaim form (line items), Interview form (scorecard) | Inline editing of JSON arrays |
| **Cross-field validation** | Position (min_salary < max_salary), LeaveRequest (end >= start), JobPosting (salary_min < salary_max) | Comparison validators |
| **Renderer variety** | currency (salary), percentage (progress), relative_date, rating (stars), badge (status), progress_bar, truncate, color_swatch, email_link, phone_link, url_link, heading, boolean | 13+ different renderers used |
| **Tabs in form** | Employee form (Personal, Employment, Contact, Notes), PerformanceReview form (Ratings, Comments, Goals) | Tab-based form layout |
| **Collapsible sections** | Employee show (Emergency Contact), PerformanceReview (Historical Goals) | Collapsed by default sections |
| **Depends-on** | Candidate form: employee_id filtered by department (when showing interviewers) | Cascading association selects |
| **Row styling** | LeaveRequest index (red for rejected, green for approved), Candidate index (color by status) | Conditional row CSS |
| **Custom renderers** | Status timeline renderer (show progression through states), org chart node | Host app custom renderers |
| **Data providers** | pending_leaves_count, open_positions_count, pending_expenses_count | Menu badge data |

### 3.2 Features NOT covered (they don't fit naturally or are not yet implemented)

| Feature | Reason |
|---|---|
| Workflows (state machine) | Platform feature not yet implemented (see design doc). The demo simulates with enum + record rules + custom actions |
| Groups (YAML/DB/host) | Could be added: departments as groups with role mapping. Listed as optional enhancement |
| Permission source: model | Could be added for runtime permission editing. Listed as optional enhancement |
| Role source: model | Could be added. The 4 fixed roles are sufficient for demo |
| has_many :through | EmployeeSkill serves as explicit join model (richer pattern). Could add if a pure through association is needed |
| Impersonation | Could add "View as employee" for HR managers to test permissions |
| Virtual models | No natural fit, but could add a "Dashboard" virtual model for aggregate stats |

---

## 4. Roles & Permissions Design

### 4.1 Roles

| Role | Description | Typical user |
|---|---|---|
| **admin** | Full system access. Can manage all configuration, see all data | System administrator |
| **hr_manager** | Full HR operations — manage employees, postings, approvals, all departments | HR department staff |
| **manager** | Manage own team — approve leaves, write reviews, see team data. Limited to own department | Department head / team lead |
| **employee** | Self-service — own profile, own leave requests, own goals, own expense claims | Regular employee |

### 4.2 Permission Matrix (key highlights)

| Model | admin | hr_manager | manager | employee |
|---|---|---|---|---|
| **Department** | full CRUD | full CRUD | read only | read only (own dept) |
| **Position** | full CRUD | full CRUD | read only | read only |
| **Employee** | full CRUD, all fields | full CRUD, all fields | read team + update limited fields | read self only, update limited fields |
| **LeaveRequest** | full + approve all | full + approve all | approve team requests | CRUD own requests only |
| **PerformanceReview** | full | full | write reviews for team | read own, write self-review section |
| **Goal** | full | full | CRUD team goals | CRUD own goals |
| **Asset** | full CRUD | full CRUD | read team assets | read own assignments |
| **Document** | full | full | read team (non-confidential) | read own (non-confidential) |
| **JobPosting** | full | full | CRUD for own department | read open postings |
| **Candidate** | full | full | read + interview for own dept | no access |
| **ExpenseClaim** | full + approve | full + approve | approve team claims | CRUD own claims |
| **Salary fields** | read + write | read + write | masked | hidden |
| **Confidential docs** | read | read | hidden | hidden |

### 4.3 Scope Rules

```yaml
# Manager — sees own department's employees
manager:
  scope:
    type: association
    field: department_id
    user_field: department_id

# Employee — sees only self
employee:
  scope:
    type: field_match
    field: id
    user_field: employee_id
```

### 4.4 Record Rules

```yaml
# Leave requests — can't modify after approval
- condition: { field: status, operator: in, value: [approved, rejected] }
  effect:
    deny_crud: [update, destroy]
    except_roles: [admin]

# Terminated employees — read-only
- condition: { field: status, operator: eq, value: terminated }
  effect:
    deny_crud: [update]
    except_roles: [admin, hr_manager]
```

---

## 5. Presenter Highlights

### 5.1 Employee — Main Presenter (most complex)

**Index:**
- Columns: photo (thumbnail), full_name (link), department.name, position.title, status (badge), work_email (email_link), phone (phone_link), hire_date (relative_date)
- Quick search on full_name, work_email
- Filters: All, Active, On Leave, Terminated
- Advanced search: by department, position, hire date range, status, employment type
- Row styling by status (terminated = muted, on_leave = yellow highlight)
- Sortable on all key columns

**Show:**
- Tab layout: Overview, Employment, Leave & Time, Performance, Assets & Documents
- Overview: photo (medium variant), full name (heading), status (badge), department.name, position.title, work_email (email_link), phone (phone_link), hire_date, manager.full_name
- Employment: employment_type, salary (currency, restricted), hire_date, termination_date
- Leave & Time: association_list of leave_balances (current year), association_list of recent leave_requests
- Performance: association_list of performance_reviews, association_list of goals
- Assets & Documents: association_list of asset_assignments, association_list of documents
- Audit history section at bottom

**Form:**
- Tab layout: Personal, Employment, Contact, Notes
- Personal: first_name, last_name, date_of_birth, gender, photo, cv
- Employment: department_id (tree_select), position_id (tree_select), manager_id (association_select, depends_on department), status, employment_type, hire_date, termination_date (visible_when status=terminated), salary (restricted by role), currency
- Contact: work_email, personal_email, phone, address (JSON sub-section: street, city, zip, country), emergency_contact (JSON sub-section: name, phone, relationship)
- Notes: notes (rich_text)

### 5.2 Employee — Directory Presenter (lightweight)

**Index:**
- Card-like view: photo, full_name, position.title, department.name, work_email, phone
- Quick search only, no advanced filters
- Read-only (no create/edit/destroy actions)
- Available to all roles including employee

### 5.3 LeaveRequest Presenter

**Form:**
- Section "Request": leave_type_id (association_select), start_date, end_date, days_count (auto-calculated, readonly), reason
- Section "Attachment" (visible_when leave type requires document): attachment upload
- Section "Approval" (visible only in show, not form): status (badge), approved_by, approved_at, rejection_note

**Custom Actions:**
- Submit (draft → pending) — visible when draft
- Approve (pending → approved) — visible for manager/HR when pending
- Reject (pending → rejected) — visible for manager/HR when pending, requires rejection_note
- Cancel — visible for employee when draft/pending

### 5.4 Recruitment Presenters

**JobPosting Index:**
- Columns: title, department.name, status (badge), employment_type, headcount, closes_at, candidates count (associated_count)
- Badge provider: open positions count

**Candidate Index:**
- Columns: full_name (link), job_posting.title, status (badge with color_map), rating (stars), source, created_at (relative_date)
- Filters: All, New, Interviewing, Offered
- Row click to show

---

## 6. Menu Structure

```yaml
menu:
  sidebar_menu:
    - label: "People"
      icon: users
      children:
        - view_group: employees          # main employee management
        - view_group: employee_directory  # public directory
        - separator: true
        - view_group: departments
        - view_group: positions

    - label: "Time & Leave"
      icon: calendar
      badge:
        provider: pending_leaves_count
        renderer: count_badge
      children:
        - view_group: leave_requests
        - view_group: leave_types
        - view_group: leave_balances

    - label: "Performance"
      icon: award
      children:
        - view_group: performance_reviews
        - view_group: goals
        - separator: true
        - view_group: skills

    - label: "Recruitment"
      icon: user-plus
      badge:
        provider: open_positions_count
        renderer: count_badge
      children:
        - view_group: job_postings
        - view_group: candidates

    - label: "Assets"
      icon: box
      children:
        - view_group: assets
        - view_group: asset_assignments

    - label: "Finance"
      icon: credit-card
      badge:
        provider: pending_expenses_count
        renderer: count_badge
      children:
        - view_group: expense_claims

    - label: "Training"
      icon: book-open
      children:
        - view_group: training_courses
        - view_group: training_enrollments

    - label: "Documents"
      icon: file-text
      children:
        - view_group: documents

    - label: "Communication"
      icon: megaphone
      children:
        - view_group: announcements
```

---

## 7. Custom Services

| Service Type | Name | Purpose |
|---|---|---|
| **Computed** | `leave_remaining` | Calculates remaining leave days (total - used) |
| **Computed** | `employee_tenure` | Years/months since hire_date |
| **Default** | `current_year` | Sets year field to current year |
| **Validator** | `leave_balance_check` | Validates enough remaining leave days |
| **Validator** | `expense_receipt_required` | Requires receipt for expenses > 500 |
| **Transform** | `titlecase` | Title-case names (reuse from CRM) |
| **Data Provider** | `pending_leaves_count` | Count of pending leave requests (for menu badge) |
| **Data Provider** | `open_positions_count` | Count of open job postings (for menu badge) |
| **Data Provider** | `pending_expenses_count` | Count of submitted expense claims (for menu badge) |
| **Condition Service** | `is_own_department` | Checks if record belongs to user's department |
| **Condition Service** | `is_own_record` | Checks if record belongs to current user |
| **Event Handler** | `leave_on_approve` | Updates leave balance when request approved |
| **Event Handler** | `asset_on_assign` | Updates asset status on assign/return |
| **Event Handler** | `candidate_on_hire` | Could auto-create employee stub |
| **Custom Action** | `approve_leave` | Approve leave request |
| **Custom Action** | `reject_leave` | Reject leave request with note |
| **Custom Action** | `submit_expense` | Submit expense claim for approval |
| **Custom Action** | `advance_candidate` | Move candidate to next stage |
| **Custom Action** | `complete_interview` | Mark interview as completed |
| **Custom Action** | `assign_asset` | Assign asset to employee |
| **Custom Action** | `return_asset` | Return asset from employee |
| **Custom Renderer** | `status_timeline` | Visual status progression (draft → pending → approved) |

---

## 8. Seed Data Plan

For a compelling demo, seed data should include:

- **3 divisions, 8 departments, 15 teams** (tree structure, 3 levels)
- **25 positions** in a hierarchy (5 levels deep)
- **80–100 employees** across departments with realistic distribution
- **50 skills** organized in a taxonomy tree (3 levels)
- **200+ employee-skill associations** with varying proficiency
- **5 leave types** (Vacation, Sick, Personal, Parental, Unpaid)
- **150+ leave requests** across various statuses
- **Leave balances** for current and previous year
- **30 performance reviews** (some completed, some in progress)
- **100 goals** across employees
- **40 assets** (laptops, phones, monitors, access cards)
- **50 asset assignments** (some current, some returned)
- **100 documents** (contracts, certificates, IDs)
- **8 training courses** with **60 enrollments**
- **5 open job postings** with **25 candidates** and **40 interviews**
- **30 expense claims** across statuses
- **10 announcements** (some published, some draft, some expired)

---

## 9. Decisions

1. **HR system over Issues Tracker** — significantly more complex domain, more natural fit for platform features (trees, approvals, attachments, permissions), no overlap with existing examples, universally understandable.

2. **20 models** — a good balance between comprehensiveness and manageability. Each model exercises multiple features and most features are demonstrated by 3+ models.

3. **4 roles (admin, hr_manager, manager, employee)** — creates a realistic permission hierarchy with meaningful differences in access, including row-level scoping.

4. **Enum-based state management** (not workflow engine) — since the workflow feature is not yet implemented, we simulate approval flows with enums + record rules + custom actions. This can be upgraded to the workflow engine when available.

5. **JSON fields for structured nested data** — address and emergency contact on Employee, scorecard on Interview, line items on ExpenseClaim. Demonstrates json_field sub-sections in forms.

6. **Three tree structures** — Department (org chart), Position (job hierarchy), Skill (taxonomy). Each has different semantics and demonstrates the tree feature in different contexts.

---

## 10. Open Questions

1. **Name of the example app** — `examples/hr`? `examples/hrm`? `examples/people`?

2. **Groups integration** — should departments double as groups (with `group_source: :yaml` derived from department tree) for permission resolution? This would add another platform feature but increases complexity.

3. **Impersonation** — should we include the "view as role X" feature for demoing the permission differences? Very useful for showcasing but needs platform support.

4. **Dashboard / virtual model** — should we add a dashboard with aggregate stats (headcount by department, leave utilization, open positions)? Would demonstrate virtual models if supported.

5. **Localization** — should the demo include a second locale (e.g., Czech) to demonstrate i18n capabilities?

6. **Scope of seed data** — the proposed ~100 employees is enough for realistic demos. Should we go larger (500+) to also demonstrate pagination/performance?
