puts "Seeding showcase data..."

# Create default admin user for built-in auth
if LcpRuby.configuration.authentication == :built_in
  UserModel = LcpRuby::User
  UserModel.find_or_create_by!(email: "admin@example.com") do |u|
    u.name = "Admin User"
    u.password = "password123"
    u.password_confirmation = "password123"
    u.lcp_role = [ "admin" ]
  end
  puts "  Created admin user: admin@example.com / password123"
end

# Phase 1: Field Types
FieldModel = LcpRuby.registry.model_for("showcase_field")

[
  {
    title: "Product Launch Campaign",
    description: "A comprehensive marketing campaign for our new product line featuring advanced targeting and multi-channel distribution.",
    count: 42,
    rating_value: 4.5,
    price: 1299.99,
    is_active: true,
    start_date: Date.today + 7,
    event_time: Time.current + 3.days,
    status: "active",
    priority: "high",
    metadata: { category: "marketing", tags: [ "launch", "q1" ] }.to_json,
    external_id: SecureRandom.uuid,
    email: "campaign@example.com",
    phone: "+1 (555) 123-4567",
    website: "https://example.com/campaigns",
    brand_color: "#3498db"
  },
  {
    title: "Q4 Budget Review",
    description: "Annual budget review for Q4 fiscal year.",
    count: 156,
    rating_value: 3.0,
    price: 50000.00,
    is_active: true,
    start_date: Date.today - 30,
    event_time: Time.current - 2.weeks,
    status: "active",
    priority: "critical",
    metadata: { department: "finance" }.to_json,
    external_id: SecureRandom.uuid,
    email: "finance@example.com",
    phone: "+44 20 7946 0958",
    website: "https://finance.example.com",
    brand_color: "#e74c3c"
  },
  {
    title: "Draft Proposal",
    description: nil,
    count: 0,
    rating_value: nil,
    price: nil,
    is_active: false,
    start_date: nil,
    event_time: nil,
    status: "draft",
    priority: "low",
    metadata: nil,
    external_id: nil,
    email: nil,
    phone: nil,
    website: nil,
    brand_color: nil
  },
  {
    title: "Archived Project Alpha",
    description: "This project was completed and archived last quarter.",
    count: 999,
    rating_value: 5.0,
    price: 100.50,
    is_active: false,
    start_date: Date.today - 90,
    event_time: Time.current - 3.months,
    status: "archived",
    priority: "medium",
    metadata: { archived_by: "admin", reason: "completed" }.to_json,
    external_id: SecureRandom.uuid,
    email: "alpha@example.com",
    phone: "555-0000",
    website: "http://alpha.example.com",
    brand_color: "#2ecc71"
  },
  {
    title: "Deleted Record Example",
    description: "This demonstrates a deleted status record that still appears in lists.",
    count: -1,
    rating_value: 0.5,
    price: 0.01,
    is_active: false,
    start_date: Date.today - 365,
    event_time: Time.current - 1.year,
    status: "deleted",
    priority: "low",
    metadata: { deleted_at: Time.current.iso8601 }.to_json,
    external_id: SecureRandom.uuid,
    email: "deleted@example.com",
    phone: nil,
    website: nil,
    brand_color: "#95a5a6"
  },
  {
    title: "International Event",
    description: "Multi-language conference with speakers from 20 countries. Features include live translation, virtual attendance, and networking sessions.",
    count: 2500,
    rating_value: 4.8,
    price: 75000.00,
    is_active: true,
    start_date: Date.today + 60,
    event_time: Time.current + 2.months,
    status: "active",
    priority: "critical",
    metadata: { countries: 20, languages: [ "en", "de", "fr", "es", "ja" ] }.to_json,
    external_id: SecureRandom.uuid,
    email: "events@globalconf.example.com",
    phone: "+49 30 12345678",
    website: "https://globalconf.example.com",
    brand_color: "#9b59b6"
  },
  {
    title: "Weekly Status Report",
    description: "Standard weekly update.",
    count: 52,
    rating_value: 2.0,
    price: 0.00,
    is_active: true,
    start_date: Date.today,
    event_time: Time.current,
    status: "active",
    priority: "medium",
    metadata: { frequency: "weekly" }.to_json,
    external_id: SecureRandom.uuid,
    email: "reports@example.com",
    phone: "+1-800-555-0199",
    website: "https://reports.example.com/weekly",
    brand_color: "#f39c12"
  },
  {
    title: "High-Priority Security Audit",
    description: "Mandatory security compliance audit required by regulatory framework. All systems must pass penetration testing.",
    count: 7,
    rating_value: 1.0,
    price: 25000.00,
    is_active: true,
    start_date: Date.today + 14,
    event_time: Time.current + 2.weeks,
    status: "draft",
    priority: "critical",
    metadata: { compliance: "SOC2", systems: [ "api", "web", "mobile" ] }.to_json,
    external_id: SecureRandom.uuid,
    email: "security@example.com",
    phone: "+1 555 987 6543",
    website: "https://security.example.com",
    brand_color: "#c0392b"
  },
  {
    title: "Team Building Activity",
    description: "Outdoor team building event for the engineering department.",
    count: 35,
    rating_value: 3.5,
    price: 1500.00,
    is_active: true,
    start_date: Date.today + 21,
    event_time: Time.current + 3.weeks,
    status: "active",
    priority: "low",
    metadata: nil,
    external_id: SecureRandom.uuid,
    email: "hr@example.com",
    phone: "+1 (555) 456-7890",
    website: nil,
    brand_color: "#1abc9c"
  },
  {
    title: "API v2 Migration",
    description: "Migrate all services from API v1 to v2. This involves updating authentication, rate limiting, and response formats.",
    count: 128,
    rating_value: 4.0,
    price: 0.00,
    is_active: true,
    start_date: Date.today - 7,
    event_time: Time.current - 1.week,
    status: "active",
    priority: "high",
    metadata: { version: "2.0", breaking_changes: true, affected_services: 12 }.to_json,
    external_id: SecureRandom.uuid,
    email: "api-team@example.com",
    phone: nil,
    website: "https://api.example.com/v2/docs",
    brand_color: "#2c3e50"
  }
].each do |attrs|
  FieldModel.create!(attrs)
end

puts "  Created #{FieldModel.count} showcase_field records"

# Phase 2: Model Features
ModelModel = LcpRuby.registry.model_for("showcase_model")

[
  { name: "Alpha Project", code: "alpha-001", status: "active", amount: 5000.00, max_value: 100, min_value: 10, email: "alpha@example.com", phone: "+1 555 111 2222", website: "https://alpha.example.com", tags_json: { priority: "high" }.to_json },
  { name: "Beta Release", code: "beta-release", status: "active", amount: 12500.50, max_value: 200, min_value: 50, email: "beta@example.com", tags_json: { version: "2.0" }.to_json },
  { name: "Draft Spec", code: "draft-spec", status: "draft", amount: nil, max_value: 50, min_value: 0, tags_json: nil },
  { name: "Completed Task", code: "done-task", status: "completed", amount: 1000.00, max_value: 10, min_value: 1, email: "done@example.com", website: "https://done.example.com" },
  { name: "Cancelled Order", code: "cancelled-123", status: "cancelled", amount: 750.00, max_value: 500, min_value: 100, phone: "+44 20 1234 5678" },
  { name: "  Whitespace Test  ", code: "  UPPER_case  ", status: "draft", amount: nil, max_value: 999, min_value: 1 },
  { name: "Edge Case Zero", code: "zero-case", status: "active", amount: 0.00, max_value: 0, min_value: -10 },
  { name: "Large Values", code: "large-vals", status: "active", amount: 99999999.99, max_value: 9999, min_value: 1, email: "large@example.com", website: "http://large.example.com" }
].each do |attrs|
  ModelModel.create!(attrs)
end

puts "  Created #{ModelModel.count} showcase_model records"

# Phase 3: Associations & Nested Forms
AuthorModel = LcpRuby.registry.model_for("author")
CategoryModel = LcpRuby.registry.model_for("category")
TagModel = LcpRuby.registry.model_for("tag")
ArticleModel = LcpRuby.registry.model_for("article")
CommentModel = LcpRuby.registry.model_for("comment")
ArticleTagModel = LcpRuby.registry.model_for("article_tag")

# Authors
authors = [
  AuthorModel.create!(name: "Alice Chen", email: "alice@example.com", bio: "Senior technical writer with 10 years of experience."),
  AuthorModel.create!(name: "Bob Martinez", email: "bob@example.com", bio: "Staff engineer and occasional blogger."),
  AuthorModel.create!(name: "Carol Williams", email: "carol@example.com", bio: "Product manager passionate about documentation."),
  AuthorModel.create!(name: "David Kim", email: "david@example.com", bio: "Open source contributor and educator."),
  AuthorModel.create!(name: "Eva Novak", email: "eva@example.com", bio: "DevOps engineer and automation enthusiast.")
]
puts "  Created #{authors.size} authors"

# Categories (3 levels)
tech = CategoryModel.create!(name: "Technology", description: "All technology related articles.")
web = CategoryModel.create!(name: "Web Development", description: "Frontend and backend web technologies.", parent_id: tech.id)
mobile = CategoryModel.create!(name: "Mobile Development", description: "iOS and Android development.", parent_id: tech.id)
frontend = CategoryModel.create!(name: "Frontend", description: "React, Vue, Angular and more.", parent_id: web.id)
backend = CategoryModel.create!(name: "Backend", description: "APIs, databases, and server-side.", parent_id: web.id)

business = CategoryModel.create!(name: "Business", description: "Business strategy and management.")
startup = CategoryModel.create!(name: "Startups", description: "Startup ecosystem and entrepreneurship.", parent_id: business.id)
enterprise = CategoryModel.create!(name: "Enterprise", description: "Large-scale business solutions.", parent_id: business.id)

science = CategoryModel.create!(name: "Science", description: "Scientific discoveries and research.")
puts "  Created #{CategoryModel.count} categories"

# Tags
tag_names = [
  { name: "Ruby", color: "#cc342d" },
  { name: "Rails", color: "#cc0000" },
  { name: "JavaScript", color: "#f7df1e" },
  { name: "TypeScript", color: "#3178c6" },
  { name: "React", color: "#61dafb" },
  { name: "Vue", color: "#42b883" },
  { name: "Python", color: "#3776ab" },
  { name: "Docker", color: "#2496ed" },
  { name: "AWS", color: "#ff9900" },
  { name: "DevOps", color: "#0db7ed" },
  { name: "Testing", color: "#8bc34a" },
  { name: "Performance", color: "#ff5722" },
  { name: "Security", color: "#f44336" },
  { name: "Tutorial", color: "#9c27b0" },
  { name: "Best Practices", color: "#607d8b" }
]
tags = tag_names.map { |t| TagModel.create!(t) }
puts "  Created #{tags.size} tags"

# Articles with comments and tags
articles_data = [
  { title: "Getting Started with Ruby on Rails", body: "A comprehensive guide to building your first Rails application.", status: "published", category: frontend, author: authors[0], tags: [ 0, 1, 13 ], comments: [ [ "Great article!", "Reader1" ], [ "Very helpful", "Reader2" ] ] },
  { title: "Advanced React Patterns", body: "Exploring compound components, render props, and hooks.", status: "published", category: frontend, author: authors[1], tags: [ 2, 4, 14 ], comments: [ [ "Love the hooks examples", "DevFan" ] ] },
  { title: "Building REST APIs with Rails", body: "Best practices for designing RESTful APIs.", status: "published", category: backend, author: authors[0], tags: [ 0, 1, 14 ], comments: [ [ "What about GraphQL?", "APIUser" ], [ "Solid patterns", "BackendDev" ], [ "More examples please", "Newbie" ] ] },
  { title: "Docker for Development", body: "Setting up Docker for local development environments.", status: "published", category: backend, author: authors[4], tags: [ 7, 9 ], comments: [] },
  { title: "Mobile-First Design Principles", body: "Why mobile-first approach matters for modern applications.", status: "published", category: mobile, author: authors[2], tags: [ 14 ], comments: [ [ "Responsive > Mobile-first", "WebDev" ] ] },
  { title: "TypeScript Migration Guide", body: "Step by step guide to migrating JavaScript to TypeScript.", status: "draft", category: frontend, author: authors[1], tags: [ 2, 3 ], comments: [] },
  { title: "AWS Lambda Best Practices", body: "Optimizing serverless functions for production.", status: "published", category: backend, author: authors[4], tags: [ 8, 9, 11 ], comments: [ [ "Cold starts are still an issue", "CloudUser" ] ] },
  { title: "Vue 3 Composition API", body: "Understanding the new composition API in Vue 3.", status: "published", category: frontend, author: authors[3], tags: [ 2, 5 ], comments: [ [ "Finally!", "VueFan" ], [ "Great comparison with Options API", "Dev123" ] ] },
  { title: "Security Best Practices for Web Apps", body: "OWASP top 10 and how to protect your application.", status: "draft", category: web, author: authors[4], tags: [ 12, 14 ], comments: [] },
  { title: "Python for Data Science", body: "Introduction to pandas, numpy, and matplotlib.", status: "published", category: science, author: authors[3], tags: [ 6, 13 ], comments: [ [ "Can you cover scikit-learn?", "DataNerd" ] ] },
  { title: "Startup Metrics That Matter", body: "Key performance indicators for early-stage startups.", status: "published", category: startup, author: authors[2], tags: [ 14 ], comments: [] },
  { title: "Enterprise Architecture Patterns", body: "Scaling applications for enterprise use.", status: "draft", category: enterprise, author: authors[0], tags: [ 14, 11 ], comments: [] },
  { title: "Testing Rails Applications", body: "RSpec, Capybara, and factory_bot patterns.", status: "published", category: backend, author: authors[0], tags: [ 0, 1, 10 ], comments: [ [ "What about minitest?", "Tester" ], [ "Factory bot is essential", "QAEngineer" ] ] },
  { title: "Performance Optimization in React", body: "Memoization, code splitting, and lazy loading.", status: "published", category: frontend, author: authors[1], tags: [ 2, 4, 11 ], comments: [ [ "useMemo vs useCallback?", "ReactDev" ] ] },
  { title: "DevOps Culture and Practices", body: "Building a DevOps culture in your organization.", status: "archived", category: tech, author: authors[4], tags: [ 7, 8, 9 ], comments: [] }
]

articles_data.each do |data|
  article = ArticleModel.create!(
    title: data[:title],
    body: data[:body],
    status: data[:status],
    word_count: data[:body].split.size,
    category_id: data[:category].id,
    author_id: data[:author].id
  )
  data[:tags].each { |tag_idx| ArticleTagModel.create!(article_id: article.id, tag_id: tags[tag_idx].id) }
  data[:comments].each_with_index do |(body, author_name), idx|
    CommentModel.create!(article_id: article.id, body: body, author_name: author_name, position: idx + 1)
  end
end

puts "  Created #{ArticleModel.count} articles, #{CommentModel.count} comments, #{ArticleTagModel.count} article-tag links"

# Phase 4: Form Features
FormModel = LcpRuby.registry.model_for("showcase_form")

[
  { name: "Simple Form", form_type: "simple", priority: 25, satisfaction: 3, is_premium: false, reason: nil },
  { name: "Advanced Config", form_type: "advanced", priority: 75, satisfaction: 4, is_premium: true, reason: "VIP customer", advanced_field_1: "Custom value", advanced_field_2: "Extra data" },
  { name: "Special Request", form_type: "special", priority: 100, satisfaction: 5, is_premium: true, reason: "Partnership", rejection_reason: "Pending approval" },
  { name: "Basic Entry", form_type: "simple", priority: 50, satisfaction: 2, is_premium: false },
  { name: "Premium Advanced", form_type: "advanced", priority: 90, satisfaction: 5, is_premium: true, reason: "Enterprise tier", advanced_field_1: "Enterprise", config_data: { feature_flags: [ "beta", "api_v2" ] }.to_json }
].each do |attrs|
  FormModel.create!(attrs)
end
puts "  Created #{FormModel.count} showcase_form records"

# Phase 5: Selects
DeptModel = LcpRuby.registry.model_for("department")
SkillModel = LcpRuby.registry.model_for("skill")
EmpModel = LcpRuby.registry.model_for("employee")
EmpSkillModel = LcpRuby.registry.model_for("employee_skill")
ProjModel = LcpRuby.registry.model_for("project")

# Departments (3 levels)
eng = DeptModel.create!(name: "Engineering", code: "eng")
fe = DeptModel.create!(name: "Frontend", code: "eng-fe", parent_id: eng.id)
be = DeptModel.create!(name: "Backend", code: "eng-be", parent_id: eng.id)
devops = DeptModel.create!(name: "DevOps", code: "eng-devops", parent_id: eng.id)
react_team = DeptModel.create!(name: "React Team", code: "eng-fe-react", parent_id: fe.id)
api_team = DeptModel.create!(name: "API Team", code: "eng-be-api", parent_id: be.id)

design = DeptModel.create!(name: "Design", code: "design")
ux = DeptModel.create!(name: "UX Design", code: "design-ux", parent_id: design.id)
ui = DeptModel.create!(name: "UI Design", code: "design-ui", parent_id: design.id)

mgmt = DeptModel.create!(name: "Management", code: "mgmt")
puts "  Created #{DeptModel.count} departments"

# Skills
skills = [
  { name: "Ruby", category: "technical" },
  { name: "JavaScript", category: "technical" },
  { name: "Python", category: "technical" },
  { name: "React", category: "technical" },
  { name: "Docker", category: "technical" },
  { name: "AWS", category: "technical" },
  { name: "Communication", category: "soft" },
  { name: "Leadership", category: "management" },
  { name: "Project Management", category: "management" },
  { name: "English", category: "language" },
  { name: "German", category: "language" },
  { name: "Testing", category: "technical" },
  { name: "CSS", category: "technical" },
  { name: "SQL", category: "technical" },
  { name: "Teamwork", category: "soft" }
].map { |s| SkillModel.create!(s) }
puts "  Created #{skills.size} skills"

# Employees
employees = [
  EmpModel.create!(name: "Jane Smith", email: "jane@example.com", role: "manager", status: "active", department_id: eng.id),
  EmpModel.create!(name: "John Doe", email: "john@example.com", role: "developer", status: "active", department_id: fe.id),
  EmpModel.create!(name: "Alice Brown", email: "alice.b@example.com", role: "developer", status: "active", department_id: be.id),
  EmpModel.create!(name: "Bob Wilson", email: "bob.w@example.com", role: "developer", status: "active", department_id: react_team.id),
  EmpModel.create!(name: "Carol Davis", email: "carol@example.com", role: "designer", status: "active", department_id: ux.id),
  EmpModel.create!(name: "Dan Lee", email: "dan@example.com", role: "admin", status: "active", department_id: mgmt.id),
  EmpModel.create!(name: "Eva Green", email: "eva.g@example.com", role: "developer", status: "on_leave", department_id: devops.id),
  EmpModel.create!(name: "Frank White", email: "frank@example.com", role: "intern", status: "active", department_id: api_team.id),
  EmpModel.create!(name: "Grace Chen", email: "grace@example.com", role: "developer", status: "active", department_id: be.id),
  EmpModel.create!(name: "Henry Kim", email: "henry@example.com", role: "designer", status: "active", department_id: ui.id),
  EmpModel.create!(name: "Iris Taylor", email: "iris@example.com", role: "developer", status: "terminated", department_id: fe.id),
  EmpModel.create!(name: "Jack Brown", email: "jack@example.com", role: "developer", status: "archived", department_id: devops.id)
]
# Set mentors
employees[1].update!(mentor_id: employees[0].id)
employees[3].update!(mentor_id: employees[1].id)
employees[7].update!(mentor_id: employees[2].id)
puts "  Created #{employees.size} employees"

# Employee skills
[ [ 0, [ 0, 6, 7, 8, 9 ] ], [ 1, [ 1, 3, 12, 9 ] ], [ 2, [ 0, 1, 13, 11 ] ], [ 3, [ 1, 3, 9 ] ], [ 4, [ 12, 6, 14 ] ], [ 5, [ 7, 8, 6, 9 ] ], [ 6, [ 4, 5, 0 ] ], [ 7, [ 0, 13, 11 ] ], [ 8, [ 0, 2, 13 ] ], [ 9, [ 12, 6 ] ] ].each do |emp_idx, skill_idxs|
  skill_idxs.each { |si| EmpSkillModel.create!(employee_id: employees[emp_idx].id, skill_id: skills[si].id) }
end
puts "  Created #{EmpSkillModel.count} employee-skill links"

# Projects
[
  { name: "Website Redesign", status: "active", department_id: fe.id, lead_id: employees[1].id },
  { name: "API v3", status: "active", department_id: be.id, lead_id: employees[2].id },
  { name: "Cloud Migration", status: "active", department_id: devops.id, lead_id: employees[6].id },
  { name: "Brand Refresh", status: "completed", department_id: design.id, lead_id: employees[4].id },
  { name: "Internal Tools", status: "active", department_id: eng.id, lead_id: employees[0].id }
].each { |p| ProjModel.create!(p) }
puts "  Created #{ProjModel.count} projects"

# Phase 6: Attachments (just create empty records — files need manual upload)
AttachModel = LcpRuby.registry.model_for("showcase_attachment")
AttachModel.create!(title: "Sample Record (upload files via edit)")
puts "  Created #{AttachModel.count} showcase_attachment records"

# Phase 7: Permissions
PermModel = LcpRuby.registry.model_for("showcase_permission")

[
  { title: "Open Task", status: "open", owner_id: 1, priority: "medium", confidential: false, public_notes: "Anyone can see this.", internal_notes: "Admin-only notes." },
  { title: "In Progress Item", status: "in_progress", owner_id: 1, assignee_id: 2, priority: "high", confidential: false, public_notes: "Being worked on." },
  { title: "Locked Record", status: "locked", owner_id: 1, priority: "critical", confidential: true, public_notes: "This record is locked.", internal_notes: "Only admin can edit." },
  { title: "Archived Entry", status: "archived", owner_id: 2, priority: "low", confidential: false, public_notes: "Historical record.", internal_notes: "Cannot be destroyed." },
  { title: "Confidential Report", status: "open", owner_id: 1, priority: "high", confidential: true, internal_notes: "Top secret information.", public_notes: "Classified." }
].each { |attrs| PermModel.create!(attrs) }
puts "  Created #{PermModel.count} showcase_permission records"

# Phase 8: Roles
RoleModel = LcpRuby.registry.model_for("role")

[
  { name: "admin", label: "Administrator", description: "Full system access. Can manage all records, roles, and settings.", active: true, position: 0 },
  { name: "editor", label: "Editor", description: "Can create and edit records but cannot delete or manage roles.", active: true, position: 10 },
  { name: "viewer", label: "Viewer", description: "Read-only access to all public data.", active: true, position: 20 },
  { name: "owner", label: "Owner", description: "Full access scoped to own records only.", active: true, position: 30 },
  { name: "deprecated_role", label: "Deprecated Role", description: "This role is no longer active. Kept for audit history.", active: false, position: 99 }
].each { |attrs| RoleModel.create!(attrs) }
puts "  Created #{RoleModel.count} role records"

# Phase 9: Extensibility (was Phase 8)
ExtModel = LcpRuby.registry.model_for("showcase_extensibility")

[
  { name: "US Dollar Account", currency: "USD", amount: 10000.00 },
  { name: "Euro Account", currency: "EUR", amount: 8500.50 },
  { name: "British Pound Reserve", currency: "GBP", amount: 25000.00 },
  { name: "Japanese Yen Fund", currency: "JPY", amount: 1500000.00 },
  { name: "No Currency Set", currency: nil, amount: 500.00 }
].each { |attrs| ExtModel.create!(attrs) }
puts "  Created #{ExtModel.count} showcase_extensibility records"

# Phase 10: Feature Catalog
FeatureModel = LcpRuby.registry.model_for("feature")

features = [
  # === Field Types ===
  {
    name: "String Field",
    category: "field_types",
    description: "Basic text field with optional `limit` (max characters). Supports `null: false` for required constraint at DB level.\n\nUsed for short text: names, titles, codes.",
    config_example: "```yaml\nfields:\n  - name: title\n    type: string\n    limit: 100\n    null: false\n```",
    demo_path: "/showcase/showcase-fields/1#field-title",
    demo_hint: "Look at the **Title** field — a simple string with heading display.",
    status: "stable"
  },
  {
    name: "Text Field",
    category: "field_types",
    description: "Unlimited-length text field. Ideal for descriptions, notes, and longer content.",
    config_example: "```yaml\nfields:\n  - name: description\n    type: text\n```",
    demo_path: "/showcase/showcase-fields/1#field-description",
    demo_hint: "Look at the **Description** field — rendered with truncate display in the table.",
    status: "stable"
  },
  {
    name: "Integer Field",
    category: "field_types",
    description: "Whole number field. Supports `default` value and range validations via `min`/`max`.",
    config_example: "```yaml\nfields:\n  - name: count\n    type: integer\n    default: 0\n```",
    demo_path: "/showcase/showcase-fields/1#field-count",
    demo_hint: "Look at the **Count** field — formatted with number display (thousands separator).",
    status: "stable"
  },
  {
    name: "Decimal / Float Field",
    category: "field_types",
    description: "Decimal numbers with configurable `precision` and `scale`. Use decimal for money, float for approximate values.",
    config_example: "```yaml\nfields:\n  - name: price\n    type: decimal\n    precision: 10\n    scale: 2\n```",
    demo_path: "/showcase/showcase-fields/1#field-price",
    demo_hint: "Look at the **Price** field — displayed as currency with USD prefix.",
    status: "stable"
  },
  {
    name: "Boolean Field",
    category: "field_types",
    description: "True/false field. Rendered as toggle switch in forms, Yes/No icon in display.",
    config_example: "```yaml\nfields:\n  - name: is_active\n    type: boolean\n    default: true\n```",
    demo_path: "/showcase/showcase-fields/1#field-is_active",
    demo_hint: "Look at the **Is active** field — shows Yes/No with color-coded text.",
    status: "stable"
  },
  {
    name: "Enum Field",
    category: "field_types",
    description: "Enumeration field with predefined values. Stored as string in DB, validated against the value list. Ideal for statuses, priorities, categories.",
    config_example: "```yaml\nfields:\n  - name: status\n    type: enum\n    values: [draft, active, archived, deleted]\n    default: draft\n```",
    demo_path: "/showcase/showcase-fields/1#field-status",
    demo_hint: "Look at **Status** and **Priority** fields — enums rendered as colored badges.",
    status: "stable"
  },
  {
    name: "Date / DateTime Field",
    category: "field_types",
    description: "Date and datetime fields with configurable display format via `strftime` patterns.",
    config_example: "```yaml\nfields:\n  - name: start_date\n    type: date\n  - name: event_time\n    type: datetime\n```",
    demo_path: "/showcase/showcase-fields/1#field-start_date",
    demo_hint: "Look at **Start date** (formatted date) and **Event time** (relative: '3 days ago').",
    status: "stable"
  },
  {
    name: "JSON Field",
    category: "field_types",
    description: "Stores arbitrary JSON data. Rendered with `code` display type. Edited as a textarea where user enters raw JSON.",
    config_example: "```yaml\nfields:\n  - name: metadata\n    type: json\n```",
    demo_path: "/showcase/showcase-fields/1#field-metadata",
    demo_hint: "Open the show view and look at the **Metadata** field in the Numeric section — displayed as code block.",
    status: "stable"
  },
  {
    name: "UUID Field",
    category: "field_types",
    description: "Universally unique identifier. Stored as string, displayed with `code` formatting.",
    config_example: "```yaml\nfields:\n  - name: external_id\n    type: uuid\n```",
    demo_path: "/showcase/showcase-fields/1#field-external_id",
    demo_hint: "Open the show view and look at **External id** — a UUID displayed in monospace code.",
    status: "stable"
  },
  {
    name: "Email Type",
    category: "field_types",
    description: "Built-in business type that auto-validates email format and applies `downcase` + `strip` transforms on save.",
    config_example: "```yaml\nfields:\n  - name: email\n    type: email\n```",
    demo_path: "/showcase/showcase-fields/1#field-email",
    demo_hint: "Look at the **Email** field — rendered as a clickable `mailto:` link.",
    status: "stable"
  },
  {
    name: "Phone Type",
    category: "field_types",
    description: "Built-in business type with phone format validation and `normalize_phone` transform (strips spaces, dashes, parens).",
    config_example: "```yaml\nfields:\n  - name: phone\n    type: phone\n```",
    demo_path: "/showcase/showcase-fields/1#field-phone",
    demo_hint: "Open the show view — **Phone** renders as a clickable `tel:` link.",
    status: "stable"
  },
  {
    name: "URL Type",
    category: "field_types",
    description: "Built-in business type that validates URL format and applies `normalize_url` transform (adds `https://` if missing).",
    config_example: "```yaml\nfields:\n  - name: website\n    type: url\n```",
    demo_path: "/showcase/showcase-fields/1#field-website",
    demo_hint: "Look at the **Website** field — rendered as a clickable link opening in new tab.",
    status: "stable"
  },
  {
    name: "Color Type",
    category: "field_types",
    description: "Built-in business type for hex color values. Validates `#rrggbb` format. Rendered with a color swatch preview.",
    config_example: "```yaml\nfields:\n  - name: brand_color\n    type: color\n```",
    demo_path: "/showcase/showcase-fields/1#field-brand_color",
    demo_hint: "Look at the **Brand color** field — shows a colored square swatch next to the hex value.",
    status: "stable"
  },
  {
    name: "Rich Text Field",
    category: "field_types",
    description: "HTML content field using Action Text (Trix editor). Rendered as sanitized HTML on display.",
    config_example: "```yaml\nfields:\n  - name: notes\n    type: rich_text\n```",
    demo_path: "/showcase/showcase-fields/1#field-notes",
    demo_hint: "Open the show view, look at **Notes** in the Text Displays section — renders formatted HTML.",
    status: "stable"
  },
  {
    name: "Attachment Field",
    category: "field_types",
    description: "File upload via Active Storage. Supports single (`has_one_attached`) and multiple (`has_many_attached`) with size/content_type/max_files validations and image variants.",
    config_example: "```yaml\nfields:\n  - name: avatar\n    type: attachment\n    attachment:\n      mode: single\n      max_size: 5MB\n      content_types: [image/png, image/jpeg]\n      variants:\n        thumb: { resize_to_limit: [100, 100] }\n```",
    demo_path: "/showcase/showcase-attachments",
    demo_hint: "The attachment showcase has fields for single file, multiple files, and image-only uploads.",
    status: "stable"
  },

  # === Display Types ===
  {
    name: "Badge Display",
    category: "display_types",
    description: "Renders value as a colored pill/badge. Uses `color_map` to assign colors per value.\n\nAvailable colors: green, red, blue, yellow, orange, purple, gray, teal, cyan, pink.",
    config_example: "```yaml\ntable_columns:\n  - field: status\n    display: badge\n    display_options:\n      color_map:\n        active: green\n        draft: gray\n        archived: orange\n```",
    demo_path: "/showcase/showcase-fields/1#field-status",
    demo_hint: "Look at the **Status** and **Priority** fields — both use badge display with different color maps.",
    status: "stable"
  },
  {
    name: "Rating Display",
    category: "display_types",
    description: "Renders a numeric value as filled/empty stars. Configurable `max` (default 5).",
    config_example: "```yaml\ntable_columns:\n  - field: rating_value\n    display: rating\n    display_options:\n      max: 5\n```",
    demo_path: "/showcase/showcase-fields/1#field-rating_value",
    demo_hint: "Look at the **Rating value** field — shows stars like ★★★★☆.",
    status: "stable"
  },
  {
    name: "Currency Display",
    category: "display_types",
    description: "Formats a numeric value as currency with symbol, thousand separators, and decimal precision.",
    config_example: "```yaml\ntable_columns:\n  - field: price\n    display: currency\n    display_options:\n      currency: EUR\n      precision: 2\n```",
    demo_path: "/showcase/showcase-fields/1#field-price",
    demo_hint: "Look at the **Price** field — displays values like `USD1,299.99`.",
    status: "stable"
  },
  {
    name: "Progress Bar Display",
    category: "display_types",
    description: "Visual progress bar. Value is rendered as percentage of configurable `max` (default 100).",
    config_example: "```yaml\ntable_columns:\n  - field: completion\n    display: progress_bar\n    display_options:\n      max: 100\n```",
    demo_path: "/showcase/showcase-forms",
    demo_hint: "Edit a form record and look at the **Priority** slider — the value drives a progress bar display.",
    status: "stable"
  },
  {
    name: "Truncate Display",
    category: "display_types",
    description: "Truncates long text to a maximum number of characters with `...` suffix. Full text shown in tooltip on hover.",
    config_example: "```yaml\ntable_columns:\n  - field: description\n    display: truncate\n    display_options:\n      max: 80\n```",
    demo_path: "/showcase/showcase-fields/1#field-description",
    demo_hint: "Look at the **Description** field. In the index table, long text is truncated with ellipsis — hover to see full text.",
    status: "stable"
  },
  {
    name: "Boolean Icon Display",
    category: "display_types",
    description: "Shows Yes/No text with green/red coloring. Customizable labels via `true_icon` and `false_icon` options.",
    config_example: "```yaml\ntable_columns:\n  - field: is_active\n    display: boolean_icon\n    display_options:\n      true_icon: Active\n      false_icon: Inactive\n```",
    demo_path: "/showcase/showcase-fields/1#field-is_active",
    demo_hint: "Look at the **Is active** field — green 'Yes' or red 'No'.",
    status: "stable"
  },
  {
    name: "Color Swatch Display",
    category: "display_types",
    description: "Shows a small colored square preview next to the hex value. Validates input against safe CSS color patterns to prevent injection.",
    config_example: "```yaml\ntable_columns:\n  - field: brand_color\n    display: color_swatch\n```",
    demo_path: "/showcase/showcase-fields/1#field-brand_color",
    demo_hint: "Look at the **Brand color** field — shows a colored square matching the hex value.",
    status: "stable"
  },
  {
    name: "Relative Date Display",
    category: "display_types",
    description: "Shows dates as human-readable relative time: '3 days ago', 'about 2 months ago', etc.",
    config_example: "```yaml\ntable_columns:\n  - field: event_time\n    display: relative_date\n```",
    demo_path: "/showcase/showcase-fields/1#field-event_time",
    demo_hint: "Look at the **Event time** field — shows values like '7 days ago' instead of absolute dates.",
    status: "stable"
  },
  {
    name: "Heading Display",
    category: "display_types",
    description: "Renders text as bold `<strong>` tag. Used for primary identifiers in tables (name, title).",
    config_example: "```yaml\ntable_columns:\n  - field: title\n    display: heading\n    link_to: show\n```",
    demo_path: "/showcase/showcase-fields/1#field-title",
    demo_hint: "Look at the **Title** field — rendered as bold `<strong>` text.",
    status: "stable"
  },
  {
    name: "Code Display",
    category: "display_types",
    description: "Renders value in monospace font inside a `<code>` tag. Ideal for UUIDs, JSON, technical identifiers.",
    config_example: "```yaml\nshow:\n  fields:\n    - field: external_id\n      display: code\n```",
    demo_path: "/showcase/showcase-fields/1#field-external_id",
    demo_hint: "Open a record's show view — **External id** renders in monospace code style.",
    status: "stable"
  },
  {
    name: "Email / Phone / URL Link Displays",
    category: "display_types",
    description: "Renders values as clickable links:\n- `email_link` → `mailto:` link\n- `phone_link` → `tel:` link\n- `url_link` → external link (opens in new tab)",
    config_example: "```yaml\ntable_columns:\n  - field: email\n    display: email_link\n  - field: phone\n    display: phone_link\n  - field: website\n    display: url_link\n```",
    demo_path: "/showcase/showcase-fields/1#field-email",
    demo_hint: "Look at **Email**, **Phone**, and **Website** fields — each is a clickable link (mailto, tel, external).",
    status: "stable"
  },
  {
    name: "Markdown Display",
    category: "display_types",
    description: "Renders Markdown content as formatted HTML. Supports GFM: tables, task lists, fenced code blocks, strikethrough, autolinks.\n\nPowered by Commonmarker (Rust-based GFM parser).",
    config_example: "```yaml\nshow:\n  fields:\n    - field: description\n      display: markdown\n```",
    demo_path: "/showcase/features",
    demo_hint: "You're looking at it now! The **Description** and **Configuration Example** fields on this page use markdown display.",
    status: "stable"
  },
  {
    name: "Internal Link Display",
    category: "display_types",
    description: "Renders a field value as a clickable internal link. Use `label` option to customize link text.",
    config_example: "```yaml\ntable_columns:\n  - field: demo_path\n    display: internal_link\n    display_options:\n      label: \"View Demo\"\n```",
    demo_path: "/showcase/features",
    demo_hint: "Look at the **Demo Link** column in the feature catalog — 'View Demo' links that navigate within the app.",
    status: "stable"
  },
  {
    name: "Collection Display",
    category: "display_types",
    description: "Renders an array of values joined by a separator. Supports `limit` with overflow indicator, and `item_display` to apply a display type to each item.",
    config_example: "```yaml\ntable_columns:\n  - field: tags\n    display: collection\n    display_options:\n      separator: \", \"\n      limit: 3\n      overflow: \"...\"\n      item_display: badge\n```",
    demo_path: "/showcase/articles",
    demo_hint: "Look at article records — tags are displayed as a collection of badge items.",
    status: "stable"
  },
  {
    name: "Number / Percentage / File Size Displays",
    category: "display_types",
    description: "Numeric formatting display types:\n- `number` — thousands separator\n- `percentage` — appends % with configurable precision\n- `file_size` — human-readable bytes (KB, MB, GB)",
    config_example: "```yaml\ntable_columns:\n  - field: count\n    display: number\n  - field: completion\n    display: percentage\n    display_options: { precision: 1 }\n```",
    demo_path: "/showcase/showcase-fields/1#field-count",
    demo_hint: "Look at the **Count** field — values like `2,500` with thousands separator.",
    status: "stable"
  },
  {
    name: "Attachment Display Types",
    category: "display_types",
    description: "Three display types for Active Storage attachments:\n- `attachment_preview` — image thumbnail or download link\n- `attachment_list` — list of download links with file sizes\n- `attachment_link` — single download link",
    config_example: "```yaml\nshow:\n  fields:\n    - field: avatar\n      display: attachment_preview\n      display_options:\n        variant: thumb\n    - field: documents\n      display: attachment_list\n```",
    demo_path: "/showcase/showcase-attachments",
    demo_hint: "Upload files to see preview, list, and link display types in action.",
    status: "stable"
  },

  # === Input Types ===
  {
    name: "Select Input",
    category: "input_types",
    description: "Standard HTML `<select>` dropdown. Auto-populated for enum fields. For associations, use `association_select`.",
    config_example: "```yaml\nform:\n  fields:\n    - field: status\n      input_type: select\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "Edit a record — **Status** and **Priority** use select dropdowns.",
    status: "stable"
  },
  {
    name: "Toggle Input",
    category: "input_types",
    description: "iOS-style toggle switch for boolean fields. Visual alternative to a checkbox.",
    config_example: "```yaml\nform:\n  fields:\n    - field: is_active\n      input_type: toggle\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "Edit a record — **Is active** is a toggle switch instead of a checkbox.",
    status: "stable"
  },
  {
    name: "Slider Input",
    category: "input_types",
    description: "Range slider for numeric values. Shows current value next to the slider. Configure `min`, `max`, `step` via `input_options`.",
    config_example: "```yaml\nform:\n  fields:\n    - field: priority\n      input_type: slider\n      input_options:\n        min: 0\n        max: 100\n        step: 5\n```",
    demo_path: "/showcase/showcase-forms/2/edit",
    demo_hint: "Edit a form record — **Priority** uses a slider from 0 to 100.",
    status: "stable"
  },
  {
    name: "Radio Group Input",
    category: "input_types",
    description: "Horizontal radio buttons for enum fields. Better UX than select when there are 2–5 options.",
    config_example: "```yaml\nform:\n  fields:\n    - field: form_type\n      input_type: radio_group\n```",
    demo_path: "/showcase/showcase-forms/2/edit",
    demo_hint: "Edit a form record — **Form type** uses radio buttons (simple / advanced / special).",
    status: "stable"
  },
  {
    name: "Tom Select (Enhanced Select)",
    category: "input_types",
    description: "Enhanced dropdown powered by Tom Select library. Supports search, tagging, remote search, and inline create. Used for `association_select` and `multi_select`.",
    config_example: "```yaml\nform:\n  fields:\n    - field: author_id\n      input_type: association_select\n      input_options:\n        search: true\n        allow_create: true\n```",
    demo_path: "/showcase/articles/1/edit",
    demo_hint: "Edit an article — **Author** and **Category** use Tom Select with search. **Tags** uses multi-select.",
    status: "stable"
  },
  {
    name: "Tree Select Input",
    category: "input_types",
    description: "Hierarchical dropdown for parent-child associations. Shows indented tree structure with expand/collapse.",
    config_example: "```yaml\nform:\n  fields:\n    - field: department_id\n      input_type: tree_select\n```",
    demo_path: "/showcase/employees/1/edit",
    demo_hint: "Edit an employee — **Department** uses a tree select showing the department hierarchy.",
    status: "stable"
  },
  {
    name: "Rich Text Editor Input",
    category: "input_types",
    description: "WYSIWYG editor (Trix via Action Text) for rich content fields. Supports bold, italic, lists, links, and attachments.",
    config_example: "```yaml\nform:\n  fields:\n    - field: notes\n      input_type: rich_text_editor\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "Edit a record — **Notes** uses the Trix rich text editor.",
    status: "stable"
  },
  {
    name: "Textarea Input",
    category: "input_types",
    description: "Multi-line text input. Configure `rows` for initial height. Can include `hint` text and `char_counter`.",
    config_example: "```yaml\nform:\n  fields:\n    - field: description\n      input_type: textarea\n      input_options:\n        rows: 4\n      hint: \"Brief description\"\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "Edit a record — **Description** uses a textarea with 3 rows.",
    status: "stable"
  },
  {
    name: "Number Input with Prefix/Suffix",
    category: "input_types",
    description: "Number input with optional visual prefix (`$`, `€`) or suffix (`kg`, `%`) using input groups.",
    config_example: "```yaml\nform:\n  fields:\n    - field: price\n      input_type: number\n      prefix: \"$\"\n    - field: weight\n      input_type: number\n      suffix: \"kg\"\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "Edit a record — **Price** has a `$` prefix displayed inline.",
    status: "stable"
  },

  # === Model Features ===
  {
    name: "Validations",
    category: "model_features",
    description: "Declarative validations in YAML: `presence`, `uniqueness`, `format`, `length`, `numericality`, `inclusion`. Applied as standard ActiveRecord validations.",
    config_example: "```yaml\nfields:\n  - name: name\n    type: string\n    validations:\n      - type: presence\n      - type: length\n        options: { maximum: 100 }\n      - type: uniqueness\n```",
    demo_path: "/showcase/showcase-models/1/edit",
    demo_hint: "Try submitting with empty **Name** or duplicate **Code** — validation errors appear.",
    status: "stable"
  },
  {
    name: "Transforms",
    category: "model_features",
    description: "Automatic value transformations on save: `strip`, `downcase`, `upcase`, `parameterize`, `normalize_url`, `normalize_phone`. Applied via `before_validation` callbacks.",
    config_example: "```yaml\nfields:\n  - name: code\n    type: string\n    transforms: [strip, downcase, parameterize]\n  - name: email\n    type: email  # auto-applies strip + downcase\n```",
    demo_path: "/showcase/showcase-models",
    demo_hint: "Look at the **Whitespace Test** record — the name and code were auto-stripped and parameterized.",
    status: "stable"
  },
  {
    name: "Default Values",
    category: "model_features",
    description: "Field defaults via `default` key. Supports static values and service-based defaults (Ruby class for computed defaults).",
    config_example: "```yaml\nfields:\n  - name: status\n    type: enum\n    default: draft\n  - name: deadline\n    type: date\n    default:\n      service: Computed::OneWeekFromNow\n```",
    demo_path: "/showcase/showcase-models/new",
    demo_hint: "Create a new record — **Status** defaults to 'draft' and **Deadline** defaults to one week from today.",
    status: "stable"
  },
  {
    name: "Computed Fields",
    category: "model_features",
    description: "Read-only fields whose value is computed by a Ruby service class. Recalculated on every save via `before_save`.",
    config_example: "```yaml\nfields:\n  - name: total\n    type: decimal\n    computed:\n      service: Computed::ShowcaseTotal\n```",
    demo_path: "/showcase/showcase-models",
    demo_hint: "Look at **Total** and **Score** columns — both are computed from other fields and updated automatically.",
    status: "stable"
  },
  {
    name: "Scopes",
    category: "model_features",
    description: "Named scopes defined in YAML using `where`, `where_not`, `order`, and `limit`. Used for predefined filters and permission scoping.",
    config_example: "```yaml\nscopes:\n  - name: active\n    where: { status: active }\n  - name: recent\n    order: { created_at: desc }\n    limit: 10\n  - name: not_deleted\n    where_not: { status: deleted }\n```",
    demo_path: "/showcase/showcase-models",
    demo_hint: "Click the **Active**, **Draft**, **Completed** filter buttons — each applies a predefined scope.",
    status: "stable"
  },
  {
    name: "Associations",
    category: "model_features",
    description: "Standard ActiveRecord associations: `belongs_to`, `has_many`, `has_many :through`. Defined in model YAML/DSL. Supports `dependent`, `foreign_key`, `class_name`.",
    config_example: "```yaml\nassociations:\n  - type: belongs_to\n    name: category\n    model: category\n  - type: has_many\n    name: comments\n    model: comment\n    dependent: destroy\n```",
    demo_path: "/showcase/articles/1",
    demo_hint: "Look at an article's show view — it shows the associated **Category**, **Author**, **Comments**, and **Tags**.",
    status: "stable"
  },
  {
    name: "Custom Types",
    category: "model_features",
    description: "Define your own reusable field types in `config/lcp_ruby/types/`. Each type specifies a base DB type plus custom validations and transforms.",
    config_example: "```yaml\n# config/lcp_ruby/types/currency_code.yml\ntype:\n  name: currency_code\n  base_type: string\n  validations:\n    - type: inclusion\n      options:\n        in: [USD, EUR, GBP, JPY]\n  transforms: [strip, upcase]\n```",
    demo_path: "/showcase/showcase-extensibility",
    demo_hint: "The **Currency** field uses a custom type with inclusion validation.",
    status: "stable"
  },
  {
    name: "Timestamps",
    category: "model_features",
    description: "Auto-managed `created_at` and `updated_at` columns. Enable with `timestamps: true` in model definition.",
    config_example: "```ruby\ndefine_model :task do\n  timestamps true\nend\n```",
    demo_path: "/showcase/showcase-fields/1#field-created_at",
    demo_hint: "Open a record's show view — **Created at** shows relative date like '3 days ago'.",
    status: "stable"
  },

  # === Presenter Features ===
  {
    name: "View Descriptions",
    category: "presenter",
    description: "Add descriptive text to index, show, and form views via the `description` key. Rendered as gray subtitle text below the page heading.",
    config_example: "```yaml\nindex:\n  description: \"Browse and manage all records.\"\nshow:\n  description: \"View record details.\"\nform:\n  description: \"Fill in the fields below.\"\n```",
    demo_path: "/showcase/showcase-fields",
    demo_hint: "Look below the page title — 'Every column uses a different display type...' is the index description.",
    status: "stable"
  },
  {
    name: "Section Descriptions",
    category: "presenter",
    description: "Add descriptive text to individual sections in show and form views. Rendered below the section heading.",
    config_example: "```yaml\nshow:\n  sections:\n    - title: \"Text Displays\"\n      description: \"Heading, truncate, code, and rich text.\"\n      fields: [...]\n```",
    demo_path: "/showcase/showcase-fields/1",
    demo_hint: "Open a record's show view — each section has a gray description below its heading.",
    status: "stable"
  },
  {
    name: "Info Blocks",
    category: "presenter",
    description: "In-form informational callouts using `type: info`. Renders a blue-bordered info box between fields.",
    config_example: "```yaml\nform:\n  sections:\n    - title: \"Pricing\"\n      fields:\n        - type: info\n          text: \"Prices are in USD.\"\n        - field: price\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "Edit a record — the **Business Type Fields** section has an info block about automatic validation.",
    status: "stable"
  },
  {
    name: "Column Configuration",
    category: "presenter",
    description: "Fine-grained table column control: `width`, `sortable`, `link_to: show`, `hidden_on: [mobile]`, `pinned: left`, `summary: sum|avg|count`.",
    config_example: "```yaml\ntable_columns:\n  - field: title\n    width: \"20%\"\n    link_to: show\n    sortable: true\n    display: heading\n    pinned: left\n  - field: price\n    summary: sum\n```",
    demo_path: "/showcase/showcase-fields",
    demo_hint: "The table has sortable columns (click headers), a price **sum** in the footer, and linked titles.",
    status: "stable"
  },
  {
    name: "View Switcher",
    category: "presenter",
    description: "Multiple view presentations for the same data. Define a view group with multiple presenters and users can switch between them (e.g., Table/Card).",
    config_example: "```yaml\n# views/showcase_fields.yml\nview_group:\n  model: showcase_field\n  primary: showcase_fields_table\n  views:\n    - presenter: showcase_fields_table\n      label: \"Table View\"\n    - presenter: showcase_fields_card\n      label: \"Card View\"\n```",
    demo_path: "/showcase/showcase-fields",
    demo_hint: "Look at the **Table View / Card View** toggle buttons in the top-right toolbar.",
    status: "stable"
  },
  {
    name: "Row Click",
    category: "presenter",
    description: "Makes entire table rows clickable. Clicking any cell navigates to the show page.",
    config_example: "```yaml\nindex:\n  row_click: show\n```",
    demo_path: "/showcase/showcase-fields",
    demo_hint: "Click anywhere on a table row (not just the title link) — the whole row is clickable.",
    status: "stable"
  },
  {
    name: "Presenter Inheritance (DSL)",
    category: "presenter",
    description: "A presenter can inherit from another with `inherits:`. Child overrides specific sections while keeping the rest.",
    config_example: "```ruby\ndefine_presenter :features_table, inherits: :features_card do\n  label \"Feature Catalog (Table)\"\n  slug \"features-table\"\n\n  index do\n    per_page 100\n    column :description, display: :truncate\n  end\nend\n```",
    demo_path: "/showcase/features",
    demo_hint: "Switch between Card/Table views — the table view inherits from card but overrides the index columns.",
    status: "stable"
  },
  {
    name: "Predefined Filters",
    category: "presenter",
    description: "Scope-based filter buttons displayed above the table. Each filter applies a named scope from the model.",
    config_example: "```yaml\nsearch:\n  predefined_filters:\n    - name: active\n      label: \"Active\"\n      scope: active\n    - name: archived\n      label: \"Archived\"\n      scope: archived\n```",
    demo_path: "/showcase/features",
    demo_hint: "Click the category filter buttons (Field Types, Display, Input...) above the feature list.",
    status: "stable"
  },

  # === Form Features ===
  {
    name: "Nested Forms",
    category: "form",
    description: "Edit associated records inline using `accepts_nested_attributes_for`. Supports add/remove rows with drag-and-drop reordering.",
    config_example: "```yaml\nform:\n  sections:\n    - title: \"Comments\"\n      type: nested\n      association: comments\n      fields: [body, author_name]\n      allow_add: true\n      allow_remove: true\n      sortable: true\n```",
    demo_path: "/showcase/articles/1/edit",
    demo_hint: "Edit an article — the **Comments** section allows adding, removing, and reordering nested comment rows.",
    status: "stable"
  },
  {
    name: "Conditional Visibility (visible_when)",
    category: "form",
    description: "Show/hide fields and sections based on other field values. Evaluated client-side in real-time as users fill the form.",
    config_example: "```yaml\nform:\n  fields:\n    - field: is_premium\n      input_type: toggle\n    - field: reason\n      visible_when:\n        field: is_premium\n        operator: eq\n        value: true\n```",
    demo_path: "/showcase/showcase-forms/2/edit",
    demo_hint: "Toggle **Is premium** — the **Reason** field appears/disappears based on the toggle state.",
    status: "stable"
  },
  {
    name: "Conditional Disable (disable_when)",
    category: "form",
    description: "Disable fields based on other field values. Uses the widget's native disabled API, not CSS overlay.",
    config_example: "```yaml\nform:\n  fields:\n    - field: rejection_reason\n      disable_when:\n        field: status\n        operator: not_eq\n        value: rejected\n```",
    demo_path: "/showcase/showcase-forms/3/edit",
    demo_hint: "Look at fields that become grayed out based on the form type or status selection.",
    status: "stable"
  },
  {
    name: "Multi-Column Form Layout",
    category: "form",
    description: "Form sections support `columns: N` with responsive breakpoints. Fields can span multiple columns with `col_span`.",
    config_example: "```yaml\nform:\n  sections:\n    - title: \"Details\"\n      columns: 3\n      responsive:\n        mobile: { columns: 1 }\n        tablet: { columns: 2 }\n      fields:\n        - field: notes\n          col_span: 2\n```",
    demo_path: "/showcase/showcase-fields/1/edit",
    demo_hint: "The form has 2-column and 3-column sections. **Notes** spans full width with `col_span: 2`.",
    status: "stable"
  },
  {
    name: "Cascading Selects",
    category: "form",
    description: "Dependent dropdowns where child select options filter based on parent selection (e.g., Country → Region → City).",
    config_example: "```yaml\nform:\n  fields:\n    - field: department_id\n      input_type: association_select\n    - field: employee_id\n      input_type: association_select\n      depends_on: department_id\n```",
    demo_path: "/showcase/projects/1/edit",
    demo_hint: "Change the **Department** — the **Lead** dropdown reloads to show only employees from that department.",
    status: "stable"
  },

  # === Permissions ===
  {
    name: "Role-Based CRUD",
    category: "permissions",
    description: "Define which CRUD operations each role can perform. Roles are checked via `PermissionEvaluator.can?` on every controller action.",
    config_example: "```yaml\npermissions:\n  model: task\n  roles:\n    admin:\n      crud: [index, show, create, update, destroy]\n    viewer:\n      crud: [index, show]\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "Use the **View as** dropdown to impersonate different roles. Viewers can't see edit/delete buttons.",
    status: "stable"
  },
  {
    name: "Field-Level Permissions",
    category: "permissions",
    description: "Control which fields each role can read or write. Hidden fields don't appear in the UI at all.",
    config_example: "```yaml\nroles:\n  editor:\n    fields:\n      readable: all\n      writable: [title, description, status]\n  viewer:\n    fields:\n      readable: [title, status, public_notes]\n      writable: []\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "Impersonate **viewer** — you'll see fewer fields. Impersonate **editor** — some fields are read-only.",
    status: "stable"
  },
  {
    name: "Record-Level Rules",
    category: "permissions",
    description: "Deny specific CRUD operations based on field conditions. E.g., deny `destroy` when `status == locked`.",
    config_example: "```yaml\nrecord_rules:\n  - deny: [update, destroy]\n    when:\n      field: status\n      operator: eq\n      value: locked\n    except_roles: [admin]\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "Look at the **Locked Record** — non-admin roles can't edit or delete it.",
    status: "stable"
  },
  {
    name: "Permission Scopes",
    category: "permissions",
    description: "Limit which records a role can see via `scope`. Use `all` for everything, a named scope, or field-based conditions.",
    config_example: "```yaml\nroles:\n  owner:\n    scope:\n      field: owner_id\n      operator: eq\n      value: :current_user_id\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "Impersonate **owner** — you'll only see records where owner_id matches your user.",
    status: "stable"
  },
  {
    name: "Impersonation",
    category: "permissions",
    description: "Test permissions without switching accounts. Admin users can 'View as' any role via a dropdown banner.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.impersonation_roles = %w[admin]\nend\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "The yellow **View as** dropdown at the top — select a role to see the app from that role's perspective.",
    status: "stable"
  },

  # === Role Source ===
  {
    name: "DB-Backed Role Source",
    category: "role_source",
    description: "Switch from implicit string-based roles to a DB-backed role model. Roles become database records with a management UI, validation, and automatic cache invalidation.\n\nConfigure with `config.role_source = :model`. The engine validates the role model contract at boot and filters unknown role names during authorization.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.role_source = :model      # :implicit (default) or :model\n  config.role_model = \"role\"        # model name\n  config.role_model_fields = {      # field mapping\n    name: \"name\",\n    active: \"active\"\n  }\nend\n```",
    demo_path: "/showcase/roles",
    demo_hint: "Navigate to **Roles** under the Features dropdown. You can create, edit, and deactivate roles. Active roles are used for authorization validation.",
    status: "stable"
  },
  {
    name: "Role Model Contract",
    category: "role_source",
    description: "The role model must satisfy a contract:\n- **Required:** `name` field of type `string`\n- **Optional:** `active` field of type `boolean` (if present, only active roles are used)\n- **Recommended:** uniqueness validation on `name`\n\nContract is validated at boot. Violations raise `MetadataError` and prevent startup.",
    config_example: "```yaml\n# config/lcp_ruby/models/role.yml\nmodel:\n  name: role\n  fields:\n    - name: name\n      type: string\n      validations:\n        - type: presence\n        - type: uniqueness\n    - name: active\n      type: boolean\n      default: true\n  options:\n    timestamps: true\n```",
    demo_path: "/showcase/roles",
    demo_hint: "The role model here has name, label, description, active, and position fields — exceeding the minimal contract requirements.",
    status: "stable"
  },
  {
    name: "Role Registry & Caching",
    category: "role_source",
    description: "Active role names are cached in a thread-safe singleton (`Roles::Registry`). Cache is automatically invalidated via `after_commit` when roles are created, updated, or destroyed.\n\nAccess programmatically via `LcpRuby::Roles::Registry.all_role_names` and `valid_role?(name)`.",
    config_example: "```ruby\n# Check the role registry\nLcpRuby::Roles::Registry.all_role_names\n# => [\"admin\", \"editor\", \"owner\", \"viewer\"]\n\nLcpRuby::Roles::Registry.valid_role?(\"admin\")\n# => true\n\nLcpRuby::Roles::Registry.valid_role?(\"ghost\")\n# => false\n\n# Force cache refresh\nLcpRuby::Roles::Registry.reload!\n```",
    demo_path: "/showcase/roles",
    demo_hint: "Create or deactivate a role — the cache updates automatically. Deactivated roles are excluded from `all_role_names`.",
    status: "stable"
  },
  {
    name: "Role Validation in Authorization",
    category: "role_source",
    description: "When `role_source` is `:model`, `PermissionEvaluator.resolve_roles` adds an extra filtering step: user role names are checked against `Roles::Registry`. Unknown roles are silently removed and logged as warnings.\n\nThis prevents stale role assignments from granting permissions after roles are renamed or deactivated.",
    config_example: "Authorization flow with role_source :model:\n```\nuser.lcp_role → [\"admin\", \"ghost_role\"]\n  ↓\nRegistry.valid_role?(\"admin\")      → true  (kept)\nRegistry.valid_role?(\"ghost_role\") → false (removed, warning logged)\n  ↓\nPermission evaluation with [\"admin\"]\n```\n\nLog output:\n```\n[LcpRuby::Roles] User #42 has unknown roles: ghost_role\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "Use impersonation to test. Roles not in the DB are filtered — the user falls back to `default_role`.",
    status: "stable"
  },
  {
    name: "Role Model Generator",
    category: "role_source",
    description: "A Rails generator scaffolds the full role model setup: model YAML, presenter, permissions, view group, and initializer config.\n\nRun once to get started, then customize the generated files as needed.",
    config_example: "```bash\n# Generate role model files\nrails generate lcp_ruby:role_model\n\n# Creates:\n#   config/lcp_ruby/models/role.yml\n#   config/lcp_ruby/presenters/roles.yml\n#   config/lcp_ruby/permissions/role.yml\n#   config/lcp_ruby/views/roles.yml\n# Updates:\n#   config/initializers/lcp_ruby.rb → adds role_source = :model\n```",
    demo_path: "/showcase/roles",
    demo_hint: "The showcase role model was created manually (using Ruby DSL), but the generator produces equivalent YAML files.",
    status: "stable"
  },
  {
    name: "Active/Inactive Roles",
    category: "role_source",
    description: "Roles with `active: false` are excluded from the registry. This lets you deactivate a role without deleting it — useful for preserving audit history.\n\nUsers assigned to a deactivated role will fall back to `default_role` during authorization.",
    config_example: "```ruby\nrole_model = LcpRuby.registry.model_for(\"role\")\n\n# Deactivate a role\nrole = role_model.find_by(name: \"deprecated\")\nrole.update!(active: false)\n# → Registry cache invalidated, role excluded from authorization\n\n# Check active roles\nLcpRuby::Roles::Registry.all_role_names\n# => [\"admin\", \"editor\", \"viewer\"]  (\"deprecated\" excluded)\n```",
    demo_path: "/showcase/roles",
    demo_hint: "The **Deprecated Role** record has `active: false` — use the Active/Inactive filters to see it. It won't appear in `all_role_names`.",
    status: "stable"
  },

  # === Extensibility ===
  {
    name: "Custom Actions",
    category: "extensibility",
    description: "Register custom action classes in `app/actions/`. Actions appear as buttons on records and execute server-side logic.",
    config_example: "```ruby\n# app/actions/showcase_permission/lock.rb\nmodule LcpRuby::HostActions\n  module ShowcasePermission\n    class Lock < LcpRuby::Actions::BaseAction\n      def execute(record, params, current_user)\n        record.update!(status: \"locked\")\n        { success: true, message: \"Record locked\" }\n      end\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-permissions",
    demo_hint: "Look for the **Lock** action button on open permission records.",
    status: "stable"
  },
  {
    name: "Event Handlers",
    category: "extensibility",
    description: "Register event handler classes in `app/event_handlers/`. Handlers fire on lifecycle events (after_create, after_update, etc.).",
    config_example: "```ruby\n# app/event_handlers/showcase_model/on_status_change.rb\nmodule LcpRuby::HostHandlers\n  module ShowcaseModel\n    class OnStatusChange < LcpRuby::Events::BaseHandler\n      def handle(event)\n        record = event.record\n        Rails.logger.info \"Status changed to \#{record.status}\"\n      end\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-extensibility",
    demo_hint: "Edit a record and change its value — event handlers log the change (check server console).",
    status: "stable"
  },
  {
    name: "Condition Services",
    category: "extensibility",
    description: "Custom condition evaluators for `visible_when` and `disable_when`. Define complex business logic beyond simple field comparisons.",
    config_example: "```ruby\n# app/condition_services/high_value_check.rb\nclass HighValueCheck\n  def self.evaluate(record, params = {})\n    record.amount.to_f > 10_000\n  end\nend\n```",
    demo_path: "/showcase/showcase-extensibility",
    demo_hint: "Look at fields that show/hide based on computed conditions, not just field values.",
    status: "stable"
  },
  {
    name: "Custom Display Renderers",
    category: "extensibility",
    description: "Extend display types by placing renderer classes in `app/renderers/`. Auto-discovered and available as display types in presenters.",
    config_example: "```ruby\n# app/renderers/conditional_badge.rb\nmodule LcpRuby::HostRenderers\n  class ConditionalBadge < LcpRuby::Display::BaseRenderer\n    def render(value, options = {}, record: nil, view_context: nil)\n      color = record&.amount.to_f > 1000 ? \"green\" : \"gray\"\n      view_context.content_tag(:span, value, class: \"badge\",\n        style: \"background: \#{color}; color: #fff;\")\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-extensibility",
    demo_hint: "Look at how currency values are displayed with context-aware badge colors.",
    status: "stable"
  },

  # === Navigation ===
  {
    name: "Breadcrumb Navigation",
    category: "navigation",
    description: "Hierarchical breadcrumbs for parent-child models. Configure `breadcrumb.relation` in the view group to automatically build the path.",
    config_example: "```yaml\n# views/categories.yml\nview_group:\n  model: category\n  breadcrumb:\n    relation: parent\n```",
    demo_path: "/showcase/categories",
    demo_hint: "Navigate to a subcategory (e.g., Frontend) — the breadcrumb shows: Home / Technology / Web Development / Frontend.",
    status: "stable"
  },
  {
    name: "Dropdown Menu",
    category: "navigation",
    description: "Top navigation with dropdown groups. Define in `menu.yml` with nested `children` arrays.",
    config_example: "```yaml\nmenu:\n  top_menu:\n    - label: \"Features\"\n      icon: star\n      children:\n        - view_group: showcase_fields\n        - view_group: showcase_models\n        - separator: true\n        - view_group: showcase_attachments\n```",
    demo_path: "/showcase/features",
    demo_hint: "Hover over **Features**, **Blog**, **Organization** in the top nav — each is a dropdown group.",
    status: "stable"
  },
  {
    name: "Sidebar Navigation",
    category: "navigation",
    description: "Sidebar menu with collapsible groups. Define `sidebar_menu` in `menu.yml`. Supports `position: bottom` for pinned items.",
    config_example: "```yaml\nmenu:\n  sidebar_menu:\n    - label: \"CRM\"\n      icon: briefcase\n      children:\n        - view_group: companies\n        - view_group: contacts\n    - view_group: settings\n      position: bottom\n```",
    demo_path: nil,
    demo_hint: "The CRM example app uses sidebar navigation. See `examples/crm/config/lcp_ruby/menu.yml`.",
    status: "stable"
  },
  {
    name: "Field Anchors",
    category: "navigation",
    description: "Each field on the show view gets an HTML `id` attribute (`id=\"field-{name}\"`), enabling deep links to specific fields via URL hash.",
    config_example: "Link to a specific field:\n```\n/showcase/showcase-fields/1#field-status\n```\n\nThe browser will scroll directly to the status field on the show page.",
    demo_path: "/showcase/showcase-fields/1#field-brand_color",
    demo_hint: "Click this demo link — the page scrolls to the **Brand color** field.",
    status: "stable"
  },

  # === Attachments ===
  {
    name: "Single File Upload",
    category: "attachments",
    description: "Upload one file via `has_one_attached`. Supports drag & drop zone, file preview, and content type restrictions.",
    config_example: "```yaml\nfields:\n  - name: document\n    type: attachment\n    attachment:\n      mode: single\n      max_size: 10MB\n```",
    demo_path: "/showcase/showcase-attachments/1/edit",
    demo_hint: "Edit the attachment record — the single file upload shows a drop zone.",
    status: "stable"
  },
  {
    name: "Multiple File Upload",
    category: "attachments",
    description: "Upload multiple files via `has_many_attached`. Supports `max_files` limit, individual file size limits, and content type restrictions.",
    config_example: "```yaml\nfields:\n  - name: gallery\n    type: attachment\n    attachment:\n      mode: multiple\n      max_files: 10\n      max_size: 5MB\n      content_types: [image/png, image/jpeg]\n```",
    demo_path: "/showcase/showcase-attachments/1/edit",
    demo_hint: "Edit the attachment record — the gallery field allows multiple image uploads.",
    status: "stable"
  },
  {
    name: "Image Variants",
    category: "attachments",
    description: "Define image processing variants (thumbnails, resizes) per attachment field. Uses Active Storage variants with ImageProcessing.",
    config_example: "```yaml\nfields:\n  - name: photo\n    type: attachment\n    attachment:\n      mode: single\n      content_types: [image/png, image/jpeg]\n      variants:\n        thumb: { resize_to_limit: [100, 100] }\n        medium: { resize_to_limit: [400, 400] }\n```",
    demo_path: "/showcase/showcase-attachments/1",
    demo_hint: "Upload an image and view the record — the show view uses the thumbnail variant.",
    status: "stable"
  },
  {
    name: "Upload Validations",
    category: "attachments",
    description: "Validate uploaded files: `max_size` (file size limit), `content_types` (MIME whitelist), `max_files` (count limit for multiple). Errors shown inline.",
    config_example: "```yaml\nattachment:\n  mode: multiple\n  max_size: 2MB\n  max_files: 5\n  content_types:\n    - image/png\n    - image/jpeg\n    - application/pdf\n```",
    demo_path: "/showcase/showcase-attachments/1/edit",
    demo_hint: "Try uploading an oversized file or wrong type — validation error messages appear.",
    status: "stable"
  },

  # === Authentication ===
  {
    name: "Tri-Mode Authentication",
    category: "authentication",
    description: "The engine supports three authentication modes via `config.authentication`:\n- `:external` — host app provides `current_user` (default)\n- `:built_in` — Devise-based login/register/reset\n- `:none` — no auth, admin OpenStruct for development",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  # Option 1: Host app handles auth (default)\n  config.authentication = :external\n\n  # Option 2: Built-in Devise auth\n  config.authentication = :built_in\n\n  # Option 3: No auth (dev mode)\n  config.authentication = :none\nend\n```",
    demo_path: "/showcase/auth/login",
    demo_hint: "This showcase app uses `:built_in` mode. The login page is generated by the engine.",
    status: "stable"
  },
  {
    name: "Login Page",
    category: "authentication",
    description: "Built-in email/password login with \"Remember me\" checkbox. Uses Devise session management with Warden middleware.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.authentication = :built_in\n  config.auth_after_login_path = \"/showcase/showcase-fields\"\nend\n```",
    demo_path: "/showcase/auth/login",
    demo_hint: "Log out and visit the login page. Enter `admin@example.com` / `password123` to log in.",
    status: "stable"
  },
  {
    name: "User Registration",
    category: "authentication",
    description: "Optional self-registration. Controlled by `config.auth_allow_registration`. Collects name, email, password. New users get default `[\"viewer\"]` role.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.auth_allow_registration = true\nend\n```",
    demo_path: "/showcase/auth/register",
    demo_hint: "Click **Sign up** on the login page — the registration form collects name, email, and password.",
    status: "stable"
  },
  {
    name: "Password Reset",
    category: "authentication",
    description: "\"Forgot password\" flow via email token. Uses Devise Recoverable module. Configurable mailer sender address.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.auth_mailer_sender = \"noreply@example.com\"\nend\n```",
    demo_path: "/showcase/auth/password/new",
    demo_hint: "Click **Forgot your password?** on the login page — enter an email to receive a reset link.",
    status: "stable"
  },
  {
    name: "Session Timeout",
    category: "authentication",
    description: "Auto-logout after inactivity period. Uses Devise Timeoutable module. Set to `nil` to disable.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.auth_session_timeout = 30.minutes\nend\n```",
    demo_path: "/showcase/auth/login",
    demo_hint: "After 30 minutes of inactivity, the session expires and you are redirected to the login page.",
    status: "stable"
  },
  {
    name: "Account Locking",
    category: "authentication",
    description: "Lock account after N failed login attempts. Uses Devise Lockable module. Set to 0 to disable.",
    config_example: "```ruby\nLcpRuby.configure do |config|\n  config.auth_lock_after_attempts = 5\n  config.auth_lock_duration = 30.minutes\nend\n```",
    demo_path: "/showcase/auth/login",
    demo_hint: "Enter a wrong password 5 times — the account gets locked and a message is displayed.",
    status: "stable"
  },
  {
    name: "Audit Logging",
    category: "authentication",
    description: "Authentication events emitted via `ActiveSupport::Notifications` — login success/failure, logout, password reset, registration, account locked. Subscribe with standard Rails instrumentation.",
    config_example: "```ruby\nActiveSupport::Notifications.subscribe(\"authentication.lcp_ruby\") do |name, start, finish, id, payload|\n  Rails.logger.info \"Auth event: \#{payload[:event]} for \#{payload[:email]}\"\nend\n```",
    demo_path: nil,
    demo_hint: "Server-side feature — check the Rails server log after login/logout to see authentication events.",
    status: "stable"
  },
  {
    name: "Install Generator",
    category: "authentication",
    description: "`rails generate lcp_ruby:install_auth` sets up the users migration, Devise initializer, and LCP Ruby config. `rake lcp_ruby:create_admin` creates the first admin user.",
    config_example: "```bash\n# Set up authentication\nrails generate lcp_ruby:install_auth\nrails db:migrate\n\n# Create first admin user\nrake lcp_ruby:create_admin\n```",
    demo_path: nil,
    demo_hint: "CLI tool — run the generator in a new Rails app to set up built-in authentication from scratch.",
    status: "stable"
  }
]

features.each { |attrs| FeatureModel.create!(attrs) }
puts "  Created #{FeatureModel.count} feature catalog entries"

puts "Seeding complete!"
