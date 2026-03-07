puts "Seeding showcase data..."

# Clear existing data so seeds are re-runnable (children before parents)
# Also reset auto-increment counters so IDs start from 1 (demo_path links use hardcoded IDs)
connection = ActiveRecord::Base.connection
%w[
  saved_filter feature pipeline_stage pipeline showcase_item_class showcase_recipe showcase_positioning showcase_userstamps
  showcase_soft_delete_item showcase_soft_delete showcase_aggregate_item showcase_aggregate
  showcase_virtual_field showcase_extensibility permission_config role showcase_permission
  showcase_attachment custom_field_definition employee_skill project showcase_search showcase_array
  employee skill department showcase_form comment article_tag tag article
  author category showcase_model showcase_field
  group_role_mapping group_membership group
  showcase_condition_task showcase_condition_threshold showcase_condition showcase_condition_category
].each do |model_name|
  next unless LcpRuby.registry.registered?(model_name)
  model = LcpRuby.registry.model_for(model_name)
  model.delete_all
  connection.execute("DELETE FROM sqlite_sequence WHERE name='#{model.table_name}'") if connection.adapter_name == "SQLite"
end
puts "  Cleared existing seed data"

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

# Categories (4 levels)
tech = CategoryModel.create!(name: "Technology", description: "All technology related articles.")
web = CategoryModel.create!(name: "Web Development", description: "Frontend and backend web technologies.", parent_id: tech.id)
mobile = CategoryModel.create!(name: "Mobile Development", description: "iOS and Android development.", parent_id: tech.id)
frontend = CategoryModel.create!(name: "Frontend", description: "React, Vue, Angular and more.", parent_id: web.id)
backend = CategoryModel.create!(name: "Backend", description: "APIs, databases, and server-side.", parent_id: web.id)
react_eco = CategoryModel.create!(name: "React Ecosystem", description: "React, Next.js, Remix, and related libraries.", parent_id: frontend.id)
css_styling = CategoryModel.create!(name: "CSS & Styling", description: "CSS frameworks, Tailwind, PostCSS, and design systems.", parent_id: frontend.id)

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
  { title: "DevOps Culture and Practices", body: "Building a DevOps culture in your organization.", status: "archived", category: tech, author: authors[4], tags: [ 7, 8, 9 ], comments: [] },
  { title: "Server Components in Next.js", body: "Understanding React Server Components and their impact on data fetching and rendering strategies.", status: "published", category: react_eco, author: authors[1], tags: [ 2, 4, 11 ], comments: [ [ "Game changer for SSR!", "NextFan" ] ] },
  { title: "State Management with Zustand", body: "A lightweight alternative to Redux for React state management.", status: "published", category: react_eco, author: authors[3], tags: [ 2, 4, 14 ], comments: [] },
  { title: "Tailwind CSS Best Practices", body: "Utility-first CSS patterns, custom themes, and component extraction strategies.", status: "published", category: css_styling, author: authors[2], tags: [ 14 ], comments: [ [ "Finally moved from SCSS to Tailwind", "CSSFan" ] ] }
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

# Phase 5b: Custom Fields
# Create custom field definitions on employees (all types) and projects (practical subset)
CfdModel = LcpRuby.registry.model_for("custom_field_definition")

# -- Employee custom fields: one of every type for showcase --
employee_cfds = [
  # String: nickname with length constraints
  {
    target_model: "employee", field_name: "nickname", custom_type: "string",
    label: "Nickname", section: "Personal Info", position: 0,
    active: true, required: false, placeholder: "e.g., Johnny",
    hint: "Short display name used in casual contexts",
    min_length: 2, max_length: 30,
    show_in_table: true, sortable: true, searchable: true
  },
  # Text: bio with longer content
  {
    target_model: "employee", field_name: "bio", custom_type: "text",
    label: "Biography", section: "Personal Info", position: 1,
    active: true, required: false, placeholder: "Brief biography...",
    max_length: 1000, show_in_table: false, show_in_form: true, show_in_show: true
  },
  # Integer: years of experience with min/max
  {
    target_model: "employee", field_name: "years_experience", custom_type: "integer",
    label: "Years of Experience", section: "Professional", position: 0,
    active: true, required: false, default_value: "0",
    hint: "Total years of professional experience",
    min_value: 0, max_value: 50,
    show_in_table: true, sortable: true
  },
  # Float: performance score
  {
    target_model: "employee", field_name: "performance_score", custom_type: "float",
    label: "Performance Score", section: "Professional", position: 1,
    active: true, required: false,
    min_value: 0.0, max_value: 10.0,
    show_in_table: true, sortable: true
  },
  # Decimal: hourly rate with precision
  {
    target_model: "employee", field_name: "hourly_rate", custom_type: "decimal",
    label: "Hourly Rate (USD)", section: "Compensation", position: 0,
    active: true, required: false,
    hint: "Base hourly rate before taxes and deductions",
    min_value: 0, precision: 2,
    show_in_table: true, sortable: true
  },
  # Boolean: remote worker flag
  {
    target_model: "employee", field_name: "remote_worker", custom_type: "boolean",
    label: "Remote Worker", section: "Work Arrangement", position: 0,
    active: true, required: false, default_value: "false",
    show_in_table: true
  },
  # Date: start date
  {
    target_model: "employee", field_name: "start_date", custom_type: "date",
    label: "Start Date", section: "Employment", position: 0,
    active: true, required: false,
    show_in_table: true, sortable: true
  },
  # Datetime: last review
  {
    target_model: "employee", field_name: "last_review_at", custom_type: "datetime",
    label: "Last Performance Review", section: "Employment", position: 1,
    active: true, required: false,
    show_in_table: false, show_in_show: true
  },
  # Enum: t-shirt size with custom values
  {
    target_model: "employee", field_name: "tshirt_size", custom_type: "enum",
    label: "T-Shirt Size", section: "Personal Info", position: 2,
    active: true, required: false, default_value: "M",
    hint: "For company swag orders",
    enum_values: [
      { "value" => "XS", "label" => "Extra Small" },
      { "value" => "S", "label" => "Small" },
      { "value" => "M", "label" => "Medium" },
      { "value" => "L", "label" => "Large" },
      { "value" => "XL", "label" => "Extra Large" },
      { "value" => "XXL", "label" => "XXL" }
    ],
    show_in_table: true
  },
  # Inactive field: demonstrates that inactive fields are hidden
  {
    target_model: "employee", field_name: "legacy_id", custom_type: "string",
    label: "Legacy System ID", section: "System", position: 99,
    active: false, required: false,
    show_in_table: false, show_in_form: false, show_in_show: false
  }
]

employee_cfds.each { |attrs| CfdModel.create!(attrs) }
puts "  Created #{employee_cfds.size} employee custom field definitions"

# -- Project custom fields: practical business fields --
project_cfds = [
  # Enum: priority
  {
    target_model: "project", field_name: "priority", custom_type: "enum",
    label: "Priority", section: "Project Details", position: 0,
    active: true, required: true,
    hint: "Determines task queue ordering",
    enum_values: %w[low medium high critical],
    default_value: "medium",
    show_in_table: true, sortable: true
  },
  # Decimal: budget
  {
    target_model: "project", field_name: "budget", custom_type: "decimal",
    label: "Budget (USD)", section: "Financials", position: 0,
    active: true, required: false,
    hint: "Approved budget in USD, excluding contingency",
    min_value: 0, precision: 2,
    show_in_table: true, sortable: true
  },
  # Date: deadline
  {
    target_model: "project", field_name: "deadline", custom_type: "date",
    label: "Deadline", section: "Project Details", position: 1,
    active: true, required: false,
    show_in_table: true, sortable: true
  },
  # Integer: team size
  {
    target_model: "project", field_name: "team_size", custom_type: "integer",
    label: "Team Size", section: "Project Details", position: 2,
    active: true, required: false,
    min_value: 1, max_value: 500,
    show_in_table: true
  },
  # Text: notes
  {
    target_model: "project", field_name: "notes", custom_type: "text",
    label: "Project Notes", section: "Documentation", position: 0,
    active: true, required: false, placeholder: "Additional project notes...",
    searchable: true
  },
  # Boolean: is_public
  {
    target_model: "project", field_name: "is_public", custom_type: "boolean",
    label: "Public Project", section: "Visibility", position: 0,
    active: true, required: false, default_value: "false",
    show_in_table: true
  },
  # String: client name with search
  {
    target_model: "project", field_name: "client_name", custom_type: "string",
    label: "Client Name", section: "Financials", position: 1,
    active: true, required: false,
    max_length: 100, searchable: true,
    show_in_table: true
  }
]

project_cfds.each { |attrs| CfdModel.create!(attrs) }
puts "  Created #{project_cfds.size} project custom field definitions"

# Force-refresh custom field accessors after creating definitions
LcpRuby::CustomFields::Registry.reload!
employee_model_class = LcpRuby.registry.model_for("employee")
project_model_class = LcpRuby.registry.model_for("project")
employee_model_class.apply_custom_field_accessors!
project_model_class.apply_custom_field_accessors!

# Fill some employees with custom field data.
# Order matches the `employees` array created in Phase 5 above.
emp_custom_data = [
  # employees[0]: Jane Smith (manager)
  { nickname: "JaneS", bio: "Engineering lead with a passion for clean architecture.", years_experience: 12,
    performance_score: 9.2, hourly_rate: 85.00, remote_worker: false,
    start_date: "2018-03-15", last_review_at: "2025-12-01 10:00:00", tshirt_size: "M" },
  # employees[1]: John Doe (developer)
  { nickname: "JD", years_experience: 5, performance_score: 7.8, hourly_rate: 55.00,
    remote_worker: true, start_date: "2021-06-01", tshirt_size: "L" },
  # employees[2]: Alice Brown
  { nickname: "Ali", years_experience: 8, performance_score: 8.5, hourly_rate: 70.00,
    remote_worker: false, start_date: "2019-09-20", tshirt_size: "S" },
  # employees[3]: Bob Wilson
  { years_experience: 3, performance_score: 6.5, hourly_rate: 45.00,
    remote_worker: true, start_date: "2023-01-10", tshirt_size: "XL" },
  # employees[4]: Carol Davis (designer)
  { nickname: "Cee", years_experience: 6, performance_score: 8.0, hourly_rate: 60.00,
    remote_worker: false, start_date: "2020-04-01", tshirt_size: "XS" },
  # employees[5]: Dan Lee (admin)
  { nickname: "DanTheMan", bio: "Operations and people management.", years_experience: 15,
    performance_score: 8.8, hourly_rate: 95.00, remote_worker: false,
    start_date: "2015-01-01", last_review_at: "2025-11-15 14:30:00", tshirt_size: "L" }
]

employees.first(emp_custom_data.size).each_with_index do |emp, idx|
  emp.assign_attributes(emp_custom_data[idx])
  emp.save!
end
puts "  Filled custom field data for #{emp_custom_data.size} employees"

# Fill projects with custom field data.
# ProjModel defined in Phase 5 above. Order matches creation order.
proj_records = ProjModel.all.to_a
proj_custom_data = [
  # proj_records[0]: Website Redesign
  { priority: "high", budget: 50000.00, deadline: (Date.today + 90).to_s, team_size: 8,
    notes: "Major redesign of the public-facing website.", is_public: true, client_name: "Internal" },
  # proj_records[1]: API v3
  { priority: "critical", budget: 120000.00, deadline: (Date.today + 180).to_s, team_size: 12,
    notes: "Full API rewrite with GraphQL support.", is_public: false },
  # proj_records[2]: Cloud Migration
  { priority: "high", budget: 200000.00, deadline: (Date.today + 365).to_s, team_size: 6,
    is_public: false, client_name: "Ops Team" },
  # proj_records[3]: Brand Refresh
  { priority: "low", budget: 15000.00, team_size: 3, is_public: true, client_name: "Marketing" },
  # proj_records[4]: Internal Tools
  { priority: "medium", budget: 30000.00, deadline: (Date.today + 60).to_s, team_size: 4,
    notes: "Build internal dashboards and admin tools.", is_public: false }
]

proj_records.first(proj_custom_data.size).each_with_index do |proj, idx|
  proj.assign_attributes(proj_custom_data[idx])
  proj.save!
end
puts "  Filled custom field data for #{proj_custom_data.size} projects"

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

# Phase 8b: Permission Configs (DB-backed permissions)
PermConfigModel = LcpRuby.registry.model_for("permission_config")

[
  {
    target_model: "article",
    definition: {
      roles: {
        admin: {
          crud: %w[index show create update destroy],
          fields: { readable: "all", writable: "all" },
          actions: "all",
          scope: "all",
          presenters: "all"
        },
        editor: {
          crud: %w[index show create update],
          fields: { readable: "all", writable: %w[title body category_id author_id published featured] },
          actions: { allowed: [] },
          scope: "all",
          presenters: "all"
        },
        viewer: {
          crud: %w[index show],
          fields: { readable: %w[title body category_id author_id published], writable: [] },
          actions: { allowed: [] },
          scope: "all",
          presenters: "all"
        }
      },
      default_role: "viewer"
    }.to_json,
    active: true,
    notes: "DB-backed permissions for articles. Overrides the YAML _default. Editors can publish but not delete."
  },
  {
    target_model: "department",
    definition: {
      roles: {
        admin: {
          crud: %w[index show create update destroy],
          fields: { readable: "all", writable: "all" },
          actions: "all",
          scope: "all",
          presenters: "all"
        },
        editor: {
          crud: %w[index show update],
          fields: { readable: "all", writable: %w[name description] },
          actions: { allowed: [] },
          scope: "all"
        },
        viewer: {
          crud: %w[index show],
          fields: { readable: "all", writable: [] },
          actions: { allowed: [] },
          scope: "all"
        }
      },
      default_role: "viewer"
    }.to_json,
    active: true,
    notes: "DB-backed permissions for departments. Editors can update but not create or delete."
  },
  {
    target_model: "employee",
    definition: {
      roles: {
        admin: {
          crud: %w[index show create update destroy],
          fields: { readable: "all", writable: "all" },
          actions: "all",
          scope: "all",
          presenters: "all"
        },
        editor: {
          crud: %w[index show create update],
          fields: { readable: "all", writable: %w[name email role status department_id mentor_id nickname bio years_experience] },
          actions: { allowed: [] },
          scope: "all",
          presenters: "all"
        },
        viewer: {
          crud: %w[index show],
          fields: { readable: %w[name email role status department_id nickname bio years_experience tshirt_size], writable: [] },
          actions: { allowed: [] },
          scope: "all",
          presenters: "all"
        }
      },
      default_role: "viewer",
      field_overrides: {
        hourly_rate: { readable_by: %w[admin], writable_by: %w[admin] },
        performance_score: { readable_by: %w[admin editor], writable_by: %w[admin] }
      }
    }.to_json,
    active: true,
    notes: "Per-field custom field permissions demo. Viewers see basic custom fields but not salary/performance. field_overrides restrict hourly_rate to admin only."
  },
  {
    target_model: "inactive_demo",
    definition: {
      roles: {
        admin: {
          crud: %w[index show create update destroy],
          fields: { readable: "all", writable: "all" },
          actions: "all",
          scope: "all"
        }
      },
      default_role: "admin"
    }.to_json,
    active: false,
    notes: "Inactive permission config — ignored by the resolver. Demonstrates that inactive records don't affect authorization."
  }
].each { |attrs| PermConfigModel.create!(attrs) }
puts "  Created #{PermConfigModel.count} permission config records"

# Phase 8c: Groups
GroupModel = LcpRuby.registry.model_for("group")
MembershipModel = LcpRuby.registry.model_for("group_membership")
RoleMappingModel = LcpRuby.registry.model_for("group_role_mapping")

engineering = GroupModel.create!(
  name: "engineering", label: "Engineering Team",
  description: "Software engineers and technical staff responsible for product development.",
  source: "manual", active: true
)
design = GroupModel.create!(
  name: "design", label: "Design Team",
  description: "UX/UI designers and product design professionals.",
  source: "manual", active: true
)
management = GroupModel.create!(
  name: "management", label: "Management",
  description: "Department heads and project managers with administrative access.",
  source: "manual", active: true
)
contractors = GroupModel.create!(
  name: "contractors", label: "External Contractors",
  description: "External contractors with limited read-only access.",
  external_id: "CN=Contractors,OU=External,DC=corp,DC=com",
  source: "api", active: true
)
legacy_team = GroupModel.create!(
  name: "legacy_team", label: "Legacy Team (Inactive)",
  description: "Former team that has been dissolved. Kept for audit purposes.",
  external_id: "CN=LegacyTeam,OU=Archived,DC=corp,DC=com",
  source: "ldap", active: false
)

# Memberships — link employee user IDs to groups
[
  { group: engineering, user_id: 1, source: "manual" },
  { group: engineering, user_id: 2, source: "manual" },
  { group: engineering, user_id: 3, source: "ldap" },
  { group: design, user_id: 4, source: "manual" },
  { group: design, user_id: 5, source: "manual" },
  { group: design, user_id: 2, source: "manual" },
  { group: management, user_id: 6, source: "manual" },
  { group: management, user_id: 7, source: "manual" },
  { group: contractors, user_id: 8, source: "api" },
  { group: contractors, user_id: 9, source: "api" },
  { group: contractors, user_id: 10, source: "api" },
  { group: legacy_team, user_id: 11, source: "ldap" },
  { group: legacy_team, user_id: 12, source: "ldap" },
  { group: engineering, user_id: 6, source: "manual" }
].each do |attrs|
  MembershipModel.create!(attrs)
rescue ActiveRecord::RecordInvalid
  nil
end

# Role mappings — map groups to authorization roles
[
  { group: engineering, role_name: "editor" },
  { group: engineering, role_name: "viewer" },
  { group: design, role_name: "editor" },
  { group: management, role_name: "admin" },
  { group: contractors, role_name: "viewer" }
].each do |attrs|
  RoleMappingModel.create!(attrs)
rescue ActiveRecord::RecordInvalid
  nil
end

puts "  Created #{GroupModel.count} groups, #{MembershipModel.count} memberships, #{RoleMappingModel.count} role mappings"

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

# Phase 10: Virtual Fields
VirtualModel = LcpRuby.registry.model_for("showcase_virtual_field")

[
  {
    name: "Premium Widget",
    properties: { color: "blue", priority: 4, unit_price: 29.99, featured: true,
                  category: "electronics", warehouse: "WEST-07", release_date: "2025-06-15",
                  sku_code: "ELEC-PW-001", city: "San Francisco", country: "USA" }
  },
  {
    name: "Basic Gadget",
    properties: { color: "gray", priority: 2, unit_price: 9.99, featured: false,
                  category: "electronics", warehouse: "MAIN-01", release_date: "2025-01-10",
                  sku_code: "ELEC-BG-042", city: "Berlin", country: "Germany" }
  },
  {
    name: "Limited Edition Box",
    properties: { color: "gold", priority: 5, unit_price: 149.00, featured: true,
                  category: "furniture", warehouse: "EAST-03", release_date: "2025-12-01",
                  sku_code: "FURN-LE-100", city: "Tokyo", country: "Japan" }
  },
  {
    name: "Clearance Item",
    properties: { color: "red", priority: 1, unit_price: 2.50, featured: false,
                  category: "clothing", sku_code: "CLTH-CI-999" }
  },
  {
    name: "New Arrival",
    properties: { color: "green", priority: 3, unit_price: 45.00, featured: true,
                  category: "food", warehouse: "MAIN-01", release_date: "2026-02-01",
                  sku_code: "FOOD-NA-007" }
  },
  {
    name: "Empty Properties Test",
    properties: {}
  }
].each { |attrs| VirtualModel.create!(attrs) }
puts "  Created #{VirtualModel.count} showcase_virtual_field records"

# Phase 11: Positioning
PriorityModel = LcpRuby.registry.model_for("showcase_positioning")

[
  { name: "Design database schema", description: "Create ERD and define table structures", status: "done", priority: "high" },
  { name: "Implement authentication", description: "Add JWT-based auth flow", status: "done", priority: "critical" },
  { name: "Build REST API endpoints", description: "Create CRUD endpoints for all resources", status: "in_progress", priority: "high" },
  { name: "Write integration tests", description: "End-to-end API testing", status: "in_progress", priority: "medium" },
  { name: "Set up CI/CD pipeline", description: "GitHub Actions for automated deploy", status: "todo", priority: "medium" },
  { name: "Add monitoring & alerts", description: "Datadog integration for error tracking", status: "todo", priority: "low" },
  { name: "Performance optimization", description: "Query optimization and caching", status: "todo", priority: "medium" },
  { name: "Write user documentation", description: "API docs and user guide", status: "todo", priority: "low" }
].each { |attrs| PriorityModel.create!(attrs) }
puts "  Created #{PriorityModel.count} showcase_positioning records"

PipelineModel = LcpRuby.registry.model_for("pipeline")
StageModel = LcpRuby.registry.model_for("pipeline_stage")

sales = PipelineModel.create!(name: "Sales Pipeline", description: "Standard B2B sales process")
hiring = PipelineModel.create!(name: "Hiring Pipeline", description: "Recruitment workflow")
support = PipelineModel.create!(name: "Support Pipeline", description: "Customer support ticket flow")

[
  { name: "Lead", color: "#3498db" },
  { name: "Qualified", color: "#2ecc71" },
  { name: "Proposal", color: "#f39c12" },
  { name: "Negotiation", color: "#e67e22" },
  { name: "Closed Won", color: "#27ae60" },
  { name: "Closed Lost", color: "#e74c3c" }
].each { |attrs| StageModel.create!(attrs.merge(pipeline: sales)) }

[
  { name: "Application", color: "#9b59b6" },
  { name: "Phone Screen", color: "#3498db" },
  { name: "Technical Interview", color: "#2ecc71" },
  { name: "Final Interview", color: "#f39c12" },
  { name: "Offer", color: "#27ae60" }
].each { |attrs| StageModel.create!(attrs.merge(pipeline: hiring)) }

[
  { name: "New", color: "#e74c3c" },
  { name: "In Progress", color: "#f39c12" },
  { name: "Waiting on Customer", color: "#95a5a6" },
  { name: "Resolved", color: "#27ae60" }
].each { |attrs| StageModel.create!(attrs.merge(pipeline: support)) }

puts "  Created #{PipelineModel.count} pipelines with #{StageModel.count} stages"

# Phase 12: Recipes (JSON Field Nested Editing)
RecipeModel = LcpRuby.registry.model_for("showcase_recipe")

[
  {
    title: "Spaghetti Carbonara",
    cuisine: "italian",
    servings: 4,
    steps: [
      { instruction: "Bring a large pot of salted water to boil", duration_minutes: 10 },
      { instruction: "Cook spaghetti according to package directions", duration_minutes: 12 },
      { instruction: "Fry guanciale in a large skillet until crispy", duration_minutes: 8 },
      { instruction: "Whisk eggs, pecorino, and black pepper in a bowl", duration_minutes: 2 },
      { instruction: "Toss hot pasta with guanciale, then stir in egg mixture off heat", duration_minutes: 3 }
    ],
    ingredients: [
      { name: "Spaghetti", quantity: "400", unit: "g", notes: nil, optional: false },
      { name: "Guanciale", quantity: "200", unit: "g", notes: "Pancetta works as a substitute", optional: false },
      { name: "Egg yolks", quantity: "6", unit: "pcs", notes: nil, optional: false },
      { name: "Pecorino Romano", quantity: "100", unit: "g", notes: "Freshly grated", optional: false },
      { name: "Black pepper", quantity: "2", unit: "tsp", notes: "Freshly cracked", optional: false },
      { name: "Parmesan", quantity: "50", unit: "g", notes: "For extra richness", optional: true }
    ]
  },
  {
    title: "Chicken Tikka Masala",
    cuisine: "indian",
    servings: 6,
    steps: [
      { instruction: "Marinate chicken in yogurt and spices for at least 1 hour", duration_minutes: 60 },
      { instruction: "Grill or broil chicken until charred", duration_minutes: 15 },
      { instruction: "Saute onions, garlic, and ginger until golden", duration_minutes: 10 },
      { instruction: "Add tomato puree and spices, simmer for 15 minutes", duration_minutes: 15 },
      { instruction: "Add cream and grilled chicken, simmer until heated through", duration_minutes: 10 },
      { instruction: "Garnish with cilantro and serve with naan", duration_minutes: 2 }
    ],
    ingredients: [
      { name: "Chicken thighs", quantity: "800", unit: "g", notes: "Boneless, skinless", optional: false },
      { name: "Yogurt", quantity: "200", unit: "ml", notes: "Plain, full-fat", optional: false },
      { name: "Garam masala", quantity: "2", unit: "tbsp", notes: nil, optional: false },
      { name: "Tomato puree", quantity: "400", unit: "ml", notes: "Canned crushed tomatoes", optional: false },
      { name: "Heavy cream", quantity: "200", unit: "ml", notes: nil, optional: false },
      { name: "Onion", quantity: "2", unit: "pcs", notes: "Finely diced", optional: false },
      { name: "Garlic", quantity: "4", unit: "pcs", notes: "Cloves, minced", optional: false },
      { name: "Fresh cilantro", quantity: "1", unit: "tbsp", notes: "Chopped, for garnish", optional: true }
    ]
  },
  {
    title: "Miso Ramen",
    cuisine: "japanese",
    servings: 2,
    steps: [
      { instruction: "Prepare dashi broth from kombu and bonito flakes", duration_minutes: 20 },
      { instruction: "Dissolve miso paste into the warm broth", duration_minutes: 3 },
      { instruction: "Cook ramen noodles according to package", duration_minutes: 4 },
      { instruction: "Prepare toppings: soft-boil eggs, slice chashu, chop scallions", duration_minutes: 15 },
      { instruction: "Assemble bowls: noodles, broth, then arrange toppings", duration_minutes: 3 }
    ],
    ingredients: [
      { name: "Ramen noodles", quantity: "200", unit: "g", notes: "Fresh preferred", optional: false },
      { name: "White miso paste", quantity: "3", unit: "tbsp", notes: nil, optional: false },
      { name: "Dashi stock", quantity: "800", unit: "ml", notes: nil, optional: false },
      { name: "Chashu pork", quantity: "150", unit: "g", notes: "Sliced", optional: false },
      { name: "Soft-boiled eggs", quantity: "2", unit: "pcs", notes: "Marinated in soy sauce overnight", optional: true },
      { name: "Scallions", quantity: "2", unit: "pcs", notes: "Thinly sliced", optional: false },
      { name: "Nori sheets", quantity: "2", unit: "pcs", notes: nil, optional: true }
    ]
  }
].each { |attrs| RecipeModel.create!(attrs) }

puts "  Created #{RecipeModel.count} showcase_recipe records"

# Phase 14: Advanced Search Showcase
SearchModel = LcpRuby.registry.model_for("showcase_search")

# Grab existing departments, categories, and authors for associations
all_depts = DeptModel.all.to_a
all_cats = CategoryModel.all.to_a
all_authors = AuthorModel.all.to_a

[
  {
    title: "Widget Pro X100",
    description: "High-end widget with advanced features and premium build quality.",
    quantity: 250, rating: 4.7, price: 299.99,
    published: true,
    status: "published", priority: "high",
    release_date: Date.today - 30,
    last_reviewed_at: Time.current - 2.days,
    tracking_id: SecureRandom.uuid,
    contact_email: "sales@widgets.example.com",
    contact_phone: "+1 555 100 2000",
    source_url: "https://widgets.example.com/pro-x100",
    department_id: all_depts.find { |d| d.name == "Engineering" }&.id,
    category_id: all_cats.find { |c| c.name == "Technology" }&.id,
    author_id: all_authors.first&.id
  },
  {
    title: "Budget Gadget Basic",
    description: "Affordable everyday gadget for casual users.",
    quantity: 1200, rating: 3.2, price: 19.99,
    published: true,
    status: "published", priority: "low",
    release_date: Date.today - 90,
    last_reviewed_at: Time.current - 15.days,
    tracking_id: SecureRandom.uuid,
    contact_email: "info@gadgets.example.com",
    source_url: "https://gadgets.example.com/basic",
    department_id: all_depts.find { |d| d.name == "Frontend" }&.id,
    category_id: all_cats.find { |c| c.name == "Web Development" }&.id,
    author_id: all_authors.second&.id
  },
  {
    title: "Enterprise Server Rack",
    description: "42U server rack with integrated cooling and cable management.",
    quantity: 15, rating: 4.9, price: 4500.00,
    published: true,
    status: "approved", priority: "critical",
    release_date: Date.today - 7,
    last_reviewed_at: Time.current - 1.hour,
    tracking_id: SecureRandom.uuid,
    contact_email: "enterprise@racks.example.com",
    contact_phone: "+44 20 7946 0958",
    department_id: all_depts.find { |d| d.name == "Backend" }&.id,
    category_id: all_cats.find { |c| c.name == "Enterprise" }&.id,
    author_id: all_authors.third&.id
  },
  {
    title: "Cloud Monitor Dashboard",
    description: "Real-time monitoring dashboard for cloud infrastructure.",
    quantity: 0, rating: 4.1, price: 0.00,
    published: false,
    status: "draft", priority: "medium",
    release_date: Date.today + 30,
    tracking_id: SecureRandom.uuid,
    contact_email: "dev@cloud.example.com",
    department_id: all_depts.find { |d| d.name == "DevOps" }&.id,
    category_id: all_cats.find { |c| c.name == "Backend" }&.id,
    author_id: all_authors.fourth&.id
  },
  {
    title: "Mobile SDK v3",
    description: "Cross-platform mobile SDK with native performance.",
    quantity: nil, rating: nil, price: 149.00,
    published: false,
    status: "review", priority: "high",
    release_date: Date.today + 14,
    last_reviewed_at: Time.current - 3.days,
    tracking_id: SecureRandom.uuid,
    contact_phone: "+49 30 1234 5678",
    source_url: "https://sdk.example.com/v3",
    department_id: all_depts.find { |d| d.name == "React Team" }&.id,
    category_id: all_cats.find { |c| c.name == "Frontend" }&.id,
    author_id: all_authors.first&.id
  },
  {
    title: "Security Audit Tool",
    description: "Automated security scanning and vulnerability reporting.",
    quantity: 50, rating: 4.5, price: 899.00,
    published: true,
    status: "published", priority: "critical",
    release_date: Date.today - 60,
    last_reviewed_at: Time.current - 5.days,
    tracking_id: SecureRandom.uuid,
    contact_email: "security@tools.example.com",
    department_id: all_depts.find { |d| d.name == "API Team" }&.id,
    category_id: all_cats.find { |c| c.name == "Backend" }&.id,
    author_id: all_authors.last&.id
  },
  {
    title: "Design System Components",
    description: "Reusable UI component library with accessibility built in.",
    quantity: 87, rating: 4.3, price: 0.00,
    published: true,
    status: "published", priority: "medium",
    release_date: Date.today - 120,
    last_reviewed_at: Time.current - 30.days,
    department_id: all_depts.find { |d| d.name == "UX Design" }&.id,
    category_id: all_cats.find { |c| c.name == "CSS & Styling" }&.id,
    author_id: all_authors.second&.id
  },
  {
    title: "Legacy Data Migrator",
    description: nil,
    quantity: 3, rating: 2.1, price: 50.00,
    published: false,
    status: "archived", priority: "low",
    release_date: Date.today - 365,
    tracking_id: SecureRandom.uuid,
    department_id: all_depts.find { |d| d.name == "Management" }&.id,
    category_id: all_cats.find { |c| c.name == "Business" }&.id,
    author_id: all_authors.third&.id
  },
  {
    title: "AI Code Assistant",
    description: "Machine learning powered code completion and review.",
    quantity: 0, rating: nil, price: nil,
    published: false,
    status: "draft", priority: "high",
    release_date: nil,
    tracking_id: nil,
    contact_email: "ai@assistant.example.com",
    department_id: all_depts.find { |d| d.name == "Engineering" }&.id,
    category_id: all_cats.find { |c| c.name == "React Ecosystem" }&.id,
    author_id: all_authors.fourth&.id
  },
  {
    title: "Analytics Pipeline",
    description: "Real-time event processing and reporting pipeline with SQL interface.",
    quantity: 500, rating: 3.8, price: 1200.00,
    published: true,
    status: "approved", priority: "medium",
    release_date: Date.today - 14,
    last_reviewed_at: Time.current,
    tracking_id: SecureRandom.uuid,
    contact_email: "data@pipeline.example.com",
    contact_phone: "+1 555 999 8888",
    source_url: "https://pipeline.example.com",
    department_id: all_depts.find { |d| d.name == "Backend" }&.id,
    category_id: all_cats.find { |c| c.name == "Science" }&.id,
    author_id: all_authors.last&.id
  },
  {
    title: "Notification Service",
    description: "Multi-channel notification delivery: email, SMS, push, and webhooks.",
    quantity: 10000, rating: 4.6, price: 75.00,
    published: true,
    status: "published", priority: "high",
    release_date: Date.today - 45,
    last_reviewed_at: Time.current - 10.days,
    tracking_id: SecureRandom.uuid,
    contact_email: "notify@service.example.com",
    contact_phone: "+1 555 777 6666",
    department_id: all_depts.find { |d| d.name == "Engineering" }&.id,
    category_id: all_cats.find { |c| c.name == "Technology" }&.id,
    author_id: all_authors.first&.id
  },
  {
    title: "Form Builder Pro",
    description: "Drag-and-drop form builder with conditional logic and validation rules.",
    quantity: 42, rating: 3.9, price: 199.00,
    published: false,
    status: "review", priority: "medium",
    release_date: Date.today + 7,
    last_reviewed_at: Time.current - 1.day,
    tracking_id: SecureRandom.uuid,
    source_url: "https://formbuilder.example.com/pro",
    department_id: all_depts.find { |d| d.name == "Frontend" }&.id,
    category_id: all_cats.find { |c| c.name == "Startups" }&.id,
    author_id: all_authors.second&.id
  }
].each do |attrs|
  SearchModel.create!(attrs)
end
puts "  Created #{SearchModel.count} showcase_search records"

# Phase 15: Saved Filters
if LcpRuby.registry.registered?("saved_filter")
  SavedFilterModel = LcpRuby.registry.model_for("saved_filter")

  # --- Saved filters for showcase-search (inline display) ---
  [
    {
      name: "Published & Expensive",
      description: "Items that are published with price >= 100",
      target_presenter: "showcase-search",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "published", operator: "true" },
          { field: "price", operator: "gteq", value: "100" }
        ]
      },
      ql_text: "published is true and price >= 100",
      visibility: "personal",
      pinned: true,
      default_filter: true,
      owner_id: 1,
      position: 1,
      icon: "dollar-sign",
      color: "green"
    },
    {
      name: "Critical Priority",
      description: "Items with high or critical priority",
      target_presenter: "showcase-search",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "priority", operator: "in", value: %w[high critical] }
        ]
      },
      ql_text: "priority in ['high', 'critical']",
      visibility: "personal",
      pinned: true,
      owner_id: 1,
      position: 2,
      icon: "alert-triangle",
      color: "red"
    },
    {
      name: "Recent Drafts",
      description: "Draft items created in the last 30 days",
      target_presenter: "showcase-search",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "status", operator: "eq", value: "draft" },
          { field: "created_at", operator: "last_n_days", value: "30" }
        ]
      },
      ql_text: "status = 'draft' and created_at last_n_days 30",
      visibility: "personal",
      owner_id: 1,
      position: 3,
      icon: "edit",
      color: "gray"
    },
    {
      name: "All Published",
      description: "All published items (visible to everyone)",
      target_presenter: "showcase-search",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "status", operator: "eq", value: "published" }
        ]
      },
      ql_text: "status = 'published'",
      visibility: "global",
      pinned: true,
      owner_id: 1,
      position: 4,
      icon: "globe",
      color: "green"
    },
    {
      name: "Admin: In Review",
      description: "Items currently in review (admin role filter)",
      target_presenter: "showcase-search",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "status", operator: "eq", value: "review" }
        ]
      },
      ql_text: "status = 'review'",
      visibility: "role",
      target_role: "admin",
      owner_id: 1,
      position: 5,
      icon: "shield",
      color: "orange"
    },
    {
      name: "Engineering: High-Value Items",
      description: "Expensive items for engineering team review",
      target_presenter: "showcase-search",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "price", operator: "gteq", value: "200" },
          { field: "status", operator: "not_eq", value: "archived" }
        ]
      },
      ql_text: "price >= 200 and status != 'archived'",
      visibility: "group",
      target_group: "engineering",
      pinned: true,
      owner_id: 1,
      position: 6,
      icon: "cpu",
      color: "purple"
    },
    # --- Saved filters for articles (dropdown display) ---
    {
      name: "Published Articles",
      description: "All articles with published status",
      target_presenter: "articles",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "status", operator: "eq", value: "published" }
        ]
      },
      ql_text: "status = 'published'",
      visibility: "global",
      pinned: true,
      owner_id: 1,
      position: 1,
      icon: "check-circle",
      color: "green"
    },
    {
      name: "My Draft Articles",
      description: "Draft articles (personal filter)",
      target_presenter: "articles",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "status", operator: "eq", value: "draft" }
        ]
      },
      ql_text: "status = 'draft'",
      visibility: "personal",
      owner_id: 1,
      position: 2,
      icon: "file"
    },
    {
      name: "Long Articles",
      description: "Articles with more than 500 words",
      target_presenter: "articles",
      condition_tree: {
        logic: "and",
        conditions: [
          { field: "word_count", operator: "gteq", value: "500" }
        ]
      },
      ql_text: "word_count >= 500",
      visibility: "personal",
      pinned: true,
      owner_id: 1,
      position: 3,
      icon: "book"
    }
  ].each { |attrs| SavedFilterModel.create!(attrs) }

  puts "  Created #{SavedFilterModel.count} saved filters"
end

# Phase: Array Fields Showcase
ArrayModel = LcpRuby.registry.model_for("showcase_array")

[
  {
    title: "Web Framework Comparison",
    description: "Comparing popular web frameworks across multiple dimensions.",
    tags: %w[ruby rails javascript react comparison],
    categories: %w[frontend backend],
    scores: [ 5, 4, 3, 5, 4 ],
    measurements: [ 98.5, 72.3, 88.1 ],
    default_labels: %w[important review],
    record_type: "advanced",
    featured: true
  },
  {
    title: "DevOps Pipeline Setup",
    description: "Setting up CI/CD pipeline with automated testing and deployment.",
    tags: %w[devops ci cd docker kubernetes urgent],
    categories: %w[devops backend],
    scores: [ 5, 5, 4 ],
    measurements: [ 150.0, 200.5 ],
    default_labels: %w[important],
    record_type: "special",
    featured: true
  },
  {
    title: "Quick Start Guide",
    description: "A simple getting started tutorial for beginners.",
    tags: %w[tutorial beginner],
    categories: %w[frontend],
    scores: [ 3, 4 ],
    measurements: [],
    default_labels: %w[important review],
    record_type: "basic",
    featured: false
  },
  {
    title: "Performance Optimization",
    description: "Database query optimization and caching strategies.",
    tags: %w[performance database caching optimization],
    categories: %w[backend devops],
    scores: [ 5, 4, 5, 3, 2 ],
    measurements: [ 12.5, 8.3, 45.7, 3.2 ],
    default_labels: [],
    record_type: "advanced",
    featured: false
  },
  {
    title: "Empty Arrays Demo",
    description: "Record with no array values to demonstrate empty state rendering.",
    tags: [],
    categories: [],
    scores: [],
    measurements: [],
    default_labels: %w[important review],
    record_type: "basic",
    featured: false
  },
  {
    title: "Design System Components",
    description: "Building a component library with design tokens and variants.",
    tags: %w[design components ui ux],
    categories: %w[design frontend],
    scores: [ 4, 4, 5 ],
    measurements: [ 16.0, 24.0, 32.0, 48.0 ],
    default_labels: %w[review],
    record_type: "special",
    featured: true
  }
].each { |attrs| ArrayModel.create!(attrs) }

puts "  Created #{ArrayModel.count} array demo records"

# Phase 13: Feature Catalog
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

  # === Array Field Types ===
  {
    name: "Array Field (String)",
    category: "field_types",
    description: "Multi-valued string field stored as native `text[]` on PostgreSQL and `json` on SQLite. Supports `array_length`, `array_uniqueness`, and `array_inclusion` validations.\n\nAuto-generates `with_<field>` (contains ALL) and `with_any_<field>` (contains ANY) query scopes. Participates in quick text search.",
    config_example: "```ruby\nfield :tags, :array, item_type: :string, default: [] do\n  validates :array_length, maximum: 10\n  validates :array_uniqueness\nend\n```",
    demo_path: "/showcase/showcase-arrays",
    demo_hint: "Look at the **Tags** column — string arrays rendered as badge collections. Edit a record to see the chip-style input.",
    status: "stable"
  },
  {
    name: "Array Field (Integer)",
    category: "field_types",
    description: "Multi-valued integer field. Items are cast to integers on save. Supports `array_inclusion` to restrict to allowed values.\n\nStored as `integer[]` on PostgreSQL, `json` on SQLite. Same query scopes and validations as string arrays.",
    config_example: "```ruby\nfield :scores, :array, item_type: :integer, default: [] do\n  validates :array_inclusion, in: [1, 2, 3, 4, 5]\n  validates :array_length, maximum: 5\nend\n```",
    demo_path: "/showcase/showcase-arrays",
    demo_hint: "Look at the **Scores** column — integer arrays displayed as comma-separated values. Edit a record and try adding values outside 1-5.",
    status: "stable"
  },
  {
    name: "Array Field (Float)",
    category: "field_types",
    description: "Multi-valued float field for measurements, coordinates, weights. Items are cast to floats on save.\n\nStored as `float[]` on PostgreSQL, `json` on SQLite.",
    config_example: "```ruby\nfield :measurements, :array, item_type: :float, default: []\n```",
    demo_path: "/showcase/showcase-arrays",
    demo_hint: "Look at the **Measurements** column on the show page — float arrays displayed as comma-separated decimals.",
    status: "stable"
  },

  # === Display Types ===
  {
    name: "Badge Display",
    category: "display_types",
    description: "Renders value as a colored pill/badge. Uses `color_map` to assign colors per value.\n\nAvailable colors: green, red, blue, yellow, orange, purple, gray, teal, cyan, pink.",
    config_example: "```yaml\ntable_columns:\n  - field: status\n    renderer: badge\n    options:\n      color_map:\n        active: green\n        draft: gray\n        archived: orange\n```",
    demo_path: "/showcase/showcase-fields/1#field-status",
    demo_hint: "Look at the **Status** and **Priority** fields — both use badge display with different color maps.",
    status: "stable"
  },
  {
    name: "Rating Display",
    category: "display_types",
    description: "Renders a numeric value as filled/empty stars. Configurable `max` (default 5).",
    config_example: "```yaml\ntable_columns:\n  - field: rating_value\n    renderer: rating\n    options:\n      max: 5\n```",
    demo_path: "/showcase/showcase-fields/1#field-rating_value",
    demo_hint: "Look at the **Rating value** field — shows stars like ★★★★☆.",
    status: "stable"
  },
  {
    name: "Currency Display",
    category: "display_types",
    description: "Formats a numeric value as currency with symbol, thousand separators, and decimal precision.",
    config_example: "```yaml\ntable_columns:\n  - field: price\n    renderer: currency\n    options:\n      currency: EUR\n      precision: 2\n```",
    demo_path: "/showcase/showcase-fields/1#field-price",
    demo_hint: "Look at the **Price** field — displays values like `USD1,299.99`.",
    status: "stable"
  },
  {
    name: "Progress Bar Display",
    category: "display_types",
    description: "Visual progress bar. Value is rendered as percentage of configurable `max` (default 100).",
    config_example: "```yaml\ntable_columns:\n  - field: completion\n    renderer: progress_bar\n    options:\n      max: 100\n```",
    demo_path: "/showcase/showcase-forms",
    demo_hint: "Edit a form record and look at the **Priority** slider — the value drives a progress bar display.",
    status: "stable"
  },
  {
    name: "Truncate Display",
    category: "display_types",
    description: "Truncates long text to a maximum number of characters with `...` suffix. Full text shown in tooltip on hover.",
    config_example: "```yaml\ntable_columns:\n  - field: description\n    renderer: truncate\n    options:\n      max: 80\n```",
    demo_path: "/showcase/showcase-fields/1#field-description",
    demo_hint: "Look at the **Description** field. In the index table, long text is truncated with ellipsis — hover to see full text.",
    status: "stable"
  },
  {
    name: "Boolean Icon Display",
    category: "display_types",
    description: "Shows Yes/No text with green/red coloring. Customizable labels via `true_icon` and `false_icon` options.",
    config_example: "```yaml\ntable_columns:\n  - field: is_active\n    renderer: boolean_icon\n    options:\n      true_icon: Active\n      false_icon: Inactive\n```",
    demo_path: "/showcase/showcase-fields/1#field-is_active",
    demo_hint: "Look at the **Is active** field — green 'Yes' or red 'No'.",
    status: "stable"
  },
  {
    name: "Color Swatch Display",
    category: "display_types",
    description: "Shows a small colored square preview next to the hex value. Validates input against safe CSS color patterns to prevent injection.",
    config_example: "```yaml\ntable_columns:\n  - field: brand_color\n    renderer: color_swatch\n```",
    demo_path: "/showcase/showcase-fields/1#field-brand_color",
    demo_hint: "Look at the **Brand color** field — shows a colored square matching the hex value.",
    status: "stable"
  },
  {
    name: "Relative Date Display",
    category: "display_types",
    description: "Shows dates as human-readable relative time: '3 days ago', 'about 2 months ago', etc.",
    config_example: "```yaml\ntable_columns:\n  - field: event_time\n    renderer: relative_date\n```",
    demo_path: "/showcase/showcase-fields/1#field-event_time",
    demo_hint: "Look at the **Event time** field — shows values like '7 days ago' instead of absolute dates.",
    status: "stable"
  },
  {
    name: "Heading Display",
    category: "display_types",
    description: "Renders text as bold `<strong>` tag. Used for primary identifiers in tables (name, title).",
    config_example: "```yaml\ntable_columns:\n  - field: title\n    renderer: heading\n    link_to: show\n```",
    demo_path: "/showcase/showcase-fields/1#field-title",
    demo_hint: "Look at the **Title** field — rendered as bold `<strong>` text.",
    status: "stable"
  },
  {
    name: "Code Display",
    category: "display_types",
    description: "Renders value in monospace font inside a `<code>` tag. Ideal for UUIDs, JSON, technical identifiers.",
    config_example: "```yaml\nshow:\n  fields:\n    - field: external_id\n      renderer: code\n```",
    demo_path: "/showcase/showcase-fields/1#field-external_id",
    demo_hint: "Open a record's show view — **External id** renders in monospace code style.",
    status: "stable"
  },
  {
    name: "Email / Phone / URL Link Displays",
    category: "display_types",
    description: "Renders values as clickable links:\n- `email_link` → `mailto:` link\n- `phone_link` → `tel:` link\n- `url_link` → external link (opens in new tab)",
    config_example: "```yaml\ntable_columns:\n  - field: email\n    renderer: email_link\n  - field: phone\n    renderer: phone_link\n  - field: website\n    renderer: url_link\n```",
    demo_path: "/showcase/showcase-fields/1#field-email",
    demo_hint: "Look at **Email**, **Phone**, and **Website** fields — each is a clickable link (mailto, tel, external).",
    status: "stable"
  },
  {
    name: "Markdown Display",
    category: "display_types",
    description: "Renders Markdown content as formatted HTML. Supports GFM: tables, task lists, fenced code blocks, strikethrough, autolinks.\n\nPowered by Commonmarker (Rust-based GFM parser).",
    config_example: "```yaml\nshow:\n  fields:\n    - field: description\n      renderer: markdown\n```",
    demo_path: "/showcase/features",
    demo_hint: "You're looking at it now! The **Description** and **Configuration Example** fields on this page use markdown display.",
    status: "stable"
  },
  {
    name: "Internal Link Display",
    category: "display_types",
    description: "Renders a field value as a clickable internal link. Use `label` option to customize link text.",
    config_example: "```yaml\ntable_columns:\n  - field: demo_path\n    renderer: internal_link\n    options:\n      label: \"View Demo\"\n```",
    demo_path: "/showcase/features",
    demo_hint: "Look at the **Demo Link** column in the feature catalog — 'View Demo' links that navigate within the app.",
    status: "stable"
  },
  {
    name: "Collection Display",
    category: "display_types",
    description: "Renders an array of values joined by a separator. Supports `limit` with overflow indicator, and `item_renderer` to apply a renderer to each item.",
    config_example: "```yaml\ntable_columns:\n  - field: tags\n    renderer: collection\n    options:\n      separator: \", \"\n      limit: 3\n      overflow: \"...\"\n      item_renderer: badge\n```",
    demo_path: "/showcase/articles",
    demo_hint: "Look at article records — tags are displayed as a collection of badge items.",
    status: "stable"
  },
  {
    name: "Number / Percentage / File Size Displays",
    category: "display_types",
    description: "Numeric formatting display types:\n- `number` — thousands separator\n- `percentage` — appends % with configurable precision\n- `file_size` — human-readable bytes (KB, MB, GB)",
    config_example: "```yaml\ntable_columns:\n  - field: count\n    renderer: number\n  - field: completion\n    renderer: percentage\n    options: { precision: 1 }\n```",
    demo_path: "/showcase/showcase-fields/1#field-count",
    demo_hint: "Look at the **Count** field — values like `2,500` with thousands separator.",
    status: "stable"
  },
  {
    name: "Attachment Display Types",
    category: "display_types",
    description: "Three display types for Active Storage attachments:\n- `attachment_preview` — image thumbnail or download link\n- `attachment_list` — list of download links with file sizes\n- `attachment_link` — single download link",
    config_example: "```yaml\nshow:\n  fields:\n    - field: avatar\n      renderer: attachment_preview\n      options:\n        variant: thumb\n    - field: documents\n      renderer: attachment_list\n```",
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

  {
    name: "Array Input",
    category: "input_types",
    description: "Tag-style chip input for array fields. Type a value and press Enter to add a chip. Click the x to remove. Supports `suggestions` (autocomplete list), `max` (item limit), and `placeholder`.\n\nDefault input type for all `type: array` fields. Submits as JSON via a hidden field.",
    config_example: "```ruby\nfield :tags, input_type: :array_input, input_options: {\n  placeholder: \"Add a tag...\",\n  max: 10,\n  suggestions: %w[ruby rails javascript python]\n}\n```",
    demo_path: "/showcase/showcase-arrays/1/edit",
    demo_hint: "Edit any array demo record. **Tags** has suggestions and a max of 10. **Scores** has numeric suggestions 1-5.",
    status: "stable"
  },

  # === Model Features ===
  {
    name: "Array Validations",
    category: "model_features",
    description: "Three array-specific validation types:\n\n- `array_length` — min/max number of items\n- `array_inclusion` — every item must be in an allowed list\n- `array_uniqueness` — no duplicate items\n\nApplied like standard validations in the field definition.",
    config_example: "```ruby\nfield :tags, :array, item_type: :string do\n  validates :array_length, maximum: 10\n  validates :array_uniqueness\nend\n\nfield :scores, :array, item_type: :integer do\n  validates :array_inclusion, in: [1, 2, 3, 4, 5]\nend\n```",
    demo_path: "/showcase/showcase-arrays/1/edit",
    demo_hint: "Edit a record — try adding more than 10 tags, duplicate tags, or scores outside 1-5. Validation errors appear on save.",
    status: "stable"
  },
  {
    name: "Array Query Scopes",
    category: "model_features",
    description: "Every array field auto-generates two query scopes:\n\n- `with_<field>(values)` — records containing ALL given values (PG `@>`, SQLite `json_each` COUNT)\n- `with_any_<field>(values)` — records containing ANY given value (PG `&&`, SQLite `json_each` EXISTS)\n\nDB-portable: same YAML works on PostgreSQL and SQLite.",
    config_example: "```ruby\n# All records with BOTH tags\nShowcaseArray.with_tags([\"ruby\", \"rails\"])\n\n# Records with EITHER tag\nShowcaseArray.with_any_tags([\"ruby\", \"python\"])\n```",
    demo_path: "/showcase/showcase-arrays",
    demo_hint: "Array scopes are available in code. Use quick search to find records by tag content.",
    status: "stable"
  },
  {
    name: "Array Condition Operators",
    category: "model_features",
    description: "Array-aware operators for `visible_when` / `disable_when` conditional rendering:\n\n- `contains` — polymorphic: array containment when field is Array, string substring when scalar\n- `not_contains` — inverse of contains\n- `any_of` — any of the given values appear in the array\n- `empty` / `not_empty` — array has zero / one-or-more items\n\nUsed in presenter sections and field conditions.",
    config_example: "```ruby\nsection \"Urgent Details\",\n  visible_when: { field: :tags, operator: :contains, value: \"urgent\" }\n\nsection \"Score Analysis\",\n  visible_when: { field: :scores, operator: :not_empty }\n```",
    demo_path: "/showcase/showcase-arrays/2",
    demo_hint: "Open the 'DevOps Pipeline Setup' record — it has the 'urgent' tag, so the **Urgent Details** section is visible. The **Score Analysis** section appears because scores is not empty.",
    status: "stable"
  },
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
    config_example: "```yaml\ntable_columns:\n  - field: title\n    width: \"20%\"\n    link_to: show\n    sortable: true\n    renderer: heading\n    pinned: left\n  - field: price\n    summary: sum\n```",
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
    config_example: "```ruby\ndefine_presenter :features_table, inherits: :features_card do\n  label \"Feature Catalog (Table)\"\n  slug \"features-table\"\n\n  index do\n    per_page 100\n    column :description, renderer: :truncate\n  end\nend\n```",
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
    description: "Edit associated records inline using `accepts_nested_attributes_for`. Supports add/remove rows with drag-and-drop reordering.\n\nDrag-and-drop supports bottom-drop targeting — dropping below the last row appends the item to the end of the list.",
    config_example: "```yaml\nform:\n  sections:\n    - title: \"Comments\"\n      type: nested\n      association: comments\n      fields: [body, author_name]\n      allow_add: true\n      allow_remove: true\n      sortable: true\n```",
    demo_path: "/showcase/articles/1/edit",
    demo_hint: "Edit an article — the **Comments** section allows adding, removing, and reordering nested comment rows.",
    status: "stable"
  },
  {
    name: "Conditional Visibility (visible_when)",
    category: "form",
    description: "Show/hide fields and sections based on other field values. Evaluated client-side in real-time as users fill the form. Also supported on show page sections (server-side evaluation).",
    config_example: "```yaml\nform:\n  fields:\n    - field: is_premium\n      input_type: toggle\n    - field: reason\n      visible_when:\n        field: is_premium\n        operator: eq\n        value: true\n```",
    demo_path: "/showcase/showcase-forms/2/edit",
    demo_hint: "Toggle **Is premium** — the **Reason** field appears/disappears based on the toggle state.",
    status: "stable"
  },
  {
    name: "Conditional Disable (disable_when)",
    category: "form",
    description: "Disable fields based on other field values. Uses the widget's native disabled API, not CSS overlay. Also supported on show page sections (server-side evaluation).",
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
  {
    name: "JSON Field Inline Editing",
    category: "form",
    description: "Edit arrays of JSON objects inline using `json_field:` on a `nested_fields` section. Field types are defined directly in the presenter — no separate model needed.\n\nSupports add/remove rows, drag-and-drop reordering, and per-field input types. Data is stored as a JSON array in a single column.",
    config_example: "```ruby\ndefine_presenter :recipes do\n  form do\n    nested_fields \"Steps\", json_field: :steps,\n      allow_add: true, allow_remove: true, sortable: true,\n      add_label: \"Add Step\", columns: 2 do\n      field :instruction, type: :string, label: \"Instruction\"\n      field :duration_minutes, type: :integer, label: \"Duration (min)\",\n        input_type: :number\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-recipes",
    demo_hint: "Click any recipe, then **Edit** — the **Steps** section lets you add, remove, and reorder step rows. Each step has instruction text and a duration number.",
    status: "stable"
  },
  {
    name: "JSON Field with Virtual Model",
    category: "form",
    description: "Use `target_model:` to reference a virtual model (`table_name: _virtual`) that defines the item structure and validations for a `json_field:` section.\n\nVirtual models are metadata-only — no database table is created. They provide field types, labels, enum values, and validation rules for JSON array items.",
    config_example: "```ruby\n# Virtual model (metadata only, no DB table)\ndefine_model :ingredient_def do\n  table_name \"_virtual\"\n  field :name, :string do\n    validates :presence\n  end\n  field :quantity, :string\n  field :unit, :enum, values: %w[g kg ml l pcs tbsp tsp]\n  field :optional, :boolean\nend\n\n# Presenter references the virtual model\nnested_fields \"Ingredients\", json_field: :ingredients,\n  target_model: :ingredient_def do\n  # fields resolved from ingredient_def model\nend\n```",
    demo_path: "/showcase/showcase-recipes",
    demo_hint: "Click any recipe, then **Edit** — the **Ingredients** section uses `ingredient_def` virtual model. The **Unit** field is an enum select with values from the model definition.",
    status: "stable"
  },
  {
    name: "JSON Field Sub-Sections",
    category: "form",
    description: "Group fields within a `json_field` nested section into collapsible sub-sections using `sub_sections:`. Each sub-section can have its own column layout, collapsible state, and visibility conditions.\n\nUseful for organizing complex item structures — keep essential fields visible while tucking optional details into collapsible groups.",
    config_example: "```ruby\nnested_fields \"Ingredients\", json_field: :ingredients,\n  target_model: :ingredient_def do\n  section \"Item\", columns: 2 do\n    field :name\n    field :quantity\n    field :unit, input_type: :select\n  end\n  section \"Extra\", columns: 1,\n    collapsible: true, collapsed: true do\n    field :notes, input_type: :textarea\n    field :optional, input_type: :checkbox\n  end\nend\n```",
    demo_path: "/showcase/showcase-recipes",
    demo_hint: "Click any recipe, then **Edit** — each ingredient row has an **Item** sub-section (always visible) and a collapsible **Extra** sub-section for notes and optional flag.",
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

  # === Permission Source ===
  {
    name: "DB-Backed Permission Source",
    category: "permission_source",
    description: "Store permission definitions as JSON documents in a database model instead of YAML files. Enable with `config.permission_source = :model`.\n\nEach record holds a complete permission definition for one model. Changes take effect immediately — no restart needed.\n\nSource priority (first found wins, no merging):\n1. DB record for this model\n2. DB record for `_default`\n3. YAML file for this model\n4. YAML `_default`",
    config_example: "```ruby\n# config/initializers/lcp_ruby.rb\nLcpRuby.configure do |config|\n  config.permission_source = :model\nend\n```\n\nDB record example:\n```json\n{\n  \"roles\": {\n    \"admin\": {\n      \"crud\": [\"index\", \"show\", \"create\", \"update\", \"destroy\"],\n      \"fields\": { \"readable\": \"all\", \"writable\": \"all\" },\n      \"actions\": \"all\",\n      \"scope\": \"all\",\n      \"presenters\": \"all\"\n    },\n    \"viewer\": {\n      \"crud\": [\"index\", \"show\"],\n      \"fields\": { \"readable\": \"all\", \"writable\": [] },\n      \"actions\": { \"allowed\": [] },\n      \"scope\": \"all\"\n    }\n  },\n  \"default_role\": \"viewer\"\n}\n```",
    demo_path: "/showcase/permission-configs",
    demo_hint: "Browse existing permission config records. Each one holds a full JSON permission definition for a specific model.",
    status: "stable"
  },
  {
    name: "Permission Definition Contract",
    category: "permission_source",
    description: "At boot time, the engine validates that your permission config model has the required fields:\n\n| Field | Type | Required |\n|-------|------|----------|\n| `target_model` | string | Yes |\n| `definition` | json | Yes |\n| `active` | boolean | No |\n\nIf the contract fails, the engine raises a clear error message listing missing or mistyped fields.",
    config_example: "```ruby\n# Customize field mapping if your model uses different column names\nLcpRuby.configure do |config|\n  config.permission_model = \"permission_config\"\n  config.permission_model_fields = {\n    target_model: \"target_model\",\n    definition: \"definition\",\n    active: \"active\"\n  }\nend\n```",
    demo_path: "/showcase/permission-configs",
    demo_hint: "The showcase permission_config model follows the default contract — `target_model`, `definition`, `active`, plus an optional `notes` field.",
    status: "stable"
  },
  {
    name: "Permission Registry & Caching",
    category: "permission_source",
    description: "Parsed permission definitions are cached in a thread-safe registry. When a `permission_config` record is saved or destroyed, the `after_commit` callback:\n\n1. Clears the registry cache for that specific `target_model`\n2. Clears the PolicyFactory cache (policies capture permission definitions in closures)\n\nThis ensures authorization decisions always reflect the latest DB state.",
    config_example: "```ruby\n# Programmatic access\nLcpRuby::Permissions::Registry.for_model(\"project\")\n# => PermissionDefinition or nil\n\nLcpRuby::Permissions::Registry.all_definitions\n# => { \"project\" => PermissionDefinition, ... }\n\n# Manual cache clear (rarely needed)\nLcpRuby::Permissions::Registry.reload!(\"project\")\nLcpRuby::Permissions::Registry.reload!  # all\n```",
    demo_path: "/showcase/permission-configs",
    demo_hint: "Edit a permission config record and save — the cache is automatically cleared. No restart required.",
    status: "stable"
  },
  {
    name: "Source Resolution Priority",
    category: "permission_source",
    description: "When `permission_source` is `:model`, the resolver follows a first-found-wins chain:\n\n1. **DB record** for the exact model name → use it entirely\n2. **DB `_default`** record → use it as a catch-all\n3. **YAML file** for the model → fallback when DB has no record\n\nThis is **not merging** — the first source that has a definition wins completely. DB and YAML are never combined for the same model.\n\nWhen `permission_source` is `:yaml` (default), only YAML files are consulted.",
    config_example: "```ruby\n# Resolution logic (simplified)\ndef self.for(model_name, loader)\n  if config.permission_source == :model && Registry.available?\n    return Registry.for_model(model_name) ||\n           Registry.for_model(\"_default\") ||\n           loader.yaml_permission_definition(model_name)\n  end\n  loader.yaml_permission_definition(model_name)\nend\n```",
    demo_path: "/showcase/permission-configs",
    demo_hint: "The showcase has DB permission configs for specific models. Models without a DB record fall back to their YAML permission files.",
    status: "stable"
  },
  {
    name: "Permission Definition Validator",
    category: "permission_source",
    description: "JSON definitions are validated on every save. The validator checks:\n\n- `roles` must be a Hash; each role's `crud` must be a subset of valid actions\n- `fields.readable` / `writable` must be `\"all\"` or an Array\n- `default_role` must be a String\n- `field_overrides` must be a Hash (if present)\n- `record_rules` must be an Array (if present)\n\nInvalid definitions fail with clear error messages.",
    config_example: "```json\n// Valid definition structure\n{\n  \"roles\": {\n    \"admin\": {\n      \"crud\": [\"index\", \"show\", \"create\", \"update\", \"destroy\"],\n      \"fields\": { \"readable\": \"all\", \"writable\": \"all\" },\n      \"actions\": \"all\",\n      \"scope\": \"all\"\n    }\n  },\n  \"default_role\": \"admin\",\n  \"field_overrides\": {\n    \"salary\": { \"readable_by\": [\"admin\"], \"writable_by\": [\"admin\"] }\n  }\n}\n```",
    demo_path: "/showcase/permission-configs",
    demo_hint: "Try creating a permission config with invalid JSON — the validator will reject it with a specific error.",
    status: "stable"
  },
  {
    name: "Permission Source Generator",
    category: "permission_source",
    description: "A Rails generator scaffolds the complete permission source setup: model, presenter, permissions, view group, and initializer config.\n\nSupports `--format dsl` (Ruby DSL, default) and `--format yaml` output.",
    config_example: "```bash\n# Generate permission source files (DSL format)\nrails generate lcp_ruby:permission_source\n\n# Generate in YAML format\nrails generate lcp_ruby:permission_source --format=yaml\n\n# Creates:\n#   config/lcp_ruby/models/permission_config.rb (or .yml)\n#   config/lcp_ruby/presenters/permission_configs.rb (or .yml)\n#   config/lcp_ruby/permissions/permission_config.yml\n#   config/lcp_ruby/views/permission_configs.rb (or .yml)\n# Updates:\n#   config/initializers/lcp_ruby.rb → adds permission_source = :model\n```",
    demo_path: "/showcase/permission-configs",
    demo_hint: "The showcase permission_config model was created manually (using Ruby DSL), but the generator produces equivalent files.",
    status: "stable"
  },

  # === Groups ===
  {
    name: "Groups Overview",
    category: "groups",
    description: "Organizational groups map users to authorization roles via memberships and role mappings. Groups follow the **Configuration Source Principle** — three input sources:\n\n| Source | Config | Description |\n|--------|--------|-------------|\n| YAML | `groups.yml` | Static groups defined in code |\n| DB Model | `group_source: :model` | Runtime-managed via generated UI |\n| Host Adapter | `group_source: :host` | Enterprise integration (LDAP/AD) |\n\nComplexity levels: membership-only (simple), with role mapping (standard), with host adapter (enterprise).",
    config_example: "```ruby\n# config/initializers/lcp_ruby.rb\nLcpRuby.configure do |config|\n  config.group_source = :model          # :none, :yaml, :model, :host\n  config.group_role_mapping_model = \"group_role_mapping\"\n  config.role_resolution_strategy = :merged  # :merged, :groups_only, :direct_only\nend\n```",
    demo_path: "/showcase/groups",
    demo_hint: "Browse the **Groups** section to see 5 groups with different sources (manual, ldap, api). Use the Active/Inactive filters.",
    status: "stable"
  },
  {
    name: "YAML Groups (Static)",
    category: "groups",
    description: "Define groups statically in `config/lcp_ruby/groups.yml`. Groups are loaded at boot and available through the Groups Registry.\n\nIdeal for fixed organizational structures that don't change at runtime.",
    config_example: "```yaml\n# config/lcp_ruby/groups.yml\ngroups:\n  - name: engineering\n    label: \"Engineering Team\"\n    roles: [editor, viewer]\n  - name: management\n    label: \"Management\"\n    roles: [admin]\n```\n\n```ruby\n# config/initializers/lcp_ruby.rb\nconfig.group_source = :yaml\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The showcase uses DB-backed groups (`group_source: :model`), but YAML groups follow the same structure as static definitions.",
    status: "stable"
  },
  {
    name: "DB-Backed Groups (Model)",
    category: "groups",
    description: "Store groups as database records for runtime management. Requires 3 models:\n\n| Model | Purpose |\n|-------|---------|\n| `group` | Group definitions (name, label, active) |\n| `group_membership` | User-to-group links |\n| `group_role_mapping` | Group-to-role mappings (optional) |\n\nUse the generator to scaffold all files, then customize as needed.",
    config_example: "```ruby\n# Generate all group files\nrails generate lcp_ruby:groups\n\n# Creates:\n#   models/group.yml, group_membership.yml, group_role_mapping.yml\n#   presenters/groups.yml\n#   permissions/group.yml\n#   views/groups.yml\n# Updates:\n#   config/initializers/lcp_ruby.rb\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The showcase demonstrates full DB-backed groups with 5 groups, 14 memberships, and 5 role mappings — all managed through the UI.",
    status: "stable"
  },
  {
    name: "Group Memberships",
    category: "groups",
    description: "Group memberships link users to groups. Each membership records `user_id`, `group_id`, and `source` (how the membership was created).\n\nA user can belong to multiple groups. Source tracking supports audit trails — `manual` (admin-assigned), `ldap` (directory sync), `api` (programmatic).",
    config_example: "```ruby\ndefine_model :group_membership do\n  field :user_id, :integer, null: false do\n    validates :presence\n  end\n  field :source, :enum, values: %w[manual ldap api], default: \"manual\"\n  belongs_to :group, model: :group, required: true\n  timestamps true\nend\n```",
    demo_path: "/showcase/group-memberships",
    demo_hint: "Browse memberships — notice users belonging to multiple groups and different source types (manual, ldap, api).",
    status: "stable"
  },
  {
    name: "Group Role Mappings",
    category: "groups",
    description: "Role mappings connect groups to authorization roles. When a user belongs to a group, they automatically inherit all roles mapped to that group.\n\nA group can map to multiple roles (e.g., engineering → editor + viewer). Role mapping is optional — groups can exist without it for membership-only use cases.",
    config_example: "```ruby\ndefine_model :group_role_mapping do\n  field :role_name, :string, limit: 50, null: false do\n    validates :presence\n  end\n  belongs_to :group, model: :group, required: true\n  timestamps true\nend\n```\n\n```ruby\n# Enable role mapping in config\nconfig.group_role_mapping_model = \"group_role_mapping\"\n```",
    demo_path: "/showcase/group-role-mappings",
    demo_hint: "See how engineering maps to editor+viewer, management maps to admin, and contractors map to viewer only.",
    status: "stable"
  },
  {
    name: "Role Resolution: Merged",
    category: "groups",
    description: "The default strategy (`role_resolution_strategy: :merged`) combines direct user roles with group-inherited roles. The union of all roles is used for authorization.\n\nExample: User has direct role `viewer` + group role `editor` → evaluated as `[viewer, editor]`. The most permissive role wins for each CRUD check.",
    config_example: "```ruby\nconfig.role_resolution_strategy = :merged\n\n# User with direct role \"viewer\" in group \"engineering\" (mapped to \"editor\")\n# Resolved roles: [\"viewer\", \"editor\"]\n# Authorization uses the union — gets editor's create + viewer's read access\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The showcase uses `:merged` strategy. Users inherit roles from groups in addition to their direct role assignments.",
    status: "stable"
  },
  {
    name: "Role Resolution: Groups Only",
    category: "groups",
    description: "With `role_resolution_strategy: :groups_only`, direct role assignments on the user are ignored. Only group-inherited roles are used for authorization.\n\nUseful when you want groups to be the single source of truth for role management.",
    config_example: "```ruby\nconfig.role_resolution_strategy = :groups_only\n\n# User has direct role \"admin\" in group \"contractors\" (mapped to \"viewer\")\n# Resolved roles: [\"viewer\"]  — direct \"admin\" is ignored\n```",
    demo_path: "/showcase/groups",
    demo_hint: "Try changing the strategy in the initializer to `:groups_only` and restarting — direct roles will be ignored.",
    status: "stable"
  },
  {
    name: "Role Resolution: Direct Only",
    category: "groups",
    description: "With `role_resolution_strategy: :direct_only`, group memberships are informational only. Roles come exclusively from the user's direct `lcp_role` attribute.\n\nGroups still work for organizational purposes (querying, reporting) but don't affect authorization.",
    config_example: "```ruby\nconfig.role_resolution_strategy = :direct_only\n\n# User has direct role \"viewer\" in group \"management\" (mapped to \"admin\")\n# Resolved roles: [\"viewer\"]  — group roles are ignored\n```",
    demo_path: "/showcase/groups",
    demo_hint: "With `:direct_only`, groups are visible in the UI but don't contribute roles to authorization.",
    status: "stable"
  },
  {
    name: "Host Adapter (AD/LDAP)",
    category: "groups",
    description: "For enterprise environments, use `group_source: :host` and provide an adapter that implements the `Groups::Contract` interface.\n\nThe adapter delegates group lookup to your existing directory service (Active Directory, LDAP, Okta, etc.). The platform never stores group data — it queries on demand.",
    config_example: "```ruby\n# config/initializers/lcp_ruby.rb\nconfig.group_source = :host\nconfig.group_adapter = MyLdapGroupAdapter.new\n\n# Adapter must implement:\nclass MyLdapGroupAdapter\n  def all_group_names\n    # Return all known group name strings\n    [\"engineering\", \"management\"]\n  end\n\n  def groups_for_user(user)\n    # Query LDAP and return group names\n    [\"engineering\", \"management\"]\n  end\n\n  def roles_for_group(group_name)\n    # Map group to authorization roles\n    { \"engineering\" => [\"editor\"], \"management\" => [\"admin\"] }[group_name] || []\n  end\nend\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The showcase uses DB-backed groups, but the host adapter interface is identical — swap the source without changing authorization logic.",
    status: "stable"
  },
  {
    name: "Groups Generator",
    category: "groups",
    description: "A Rails generator scaffolds the complete DB-backed groups setup: 3 models, 1 presenter, 1 permission file, 1 view group, and initializer config.\n\nRun once to bootstrap, then customize the generated files (convert to DSL, add extra presenters, etc.).",
    config_example: "```bash\nrails generate lcp_ruby:groups\n\n# Creates 6 files:\n#   config/lcp_ruby/models/group.yml\n#   config/lcp_ruby/models/group_membership.yml\n#   config/lcp_ruby/models/group_role_mapping.yml\n#   config/lcp_ruby/presenters/groups.yml\n#   config/lcp_ruby/permissions/group.yml\n#   config/lcp_ruby/views/groups.yml\n# Updates:\n#   config/initializers/lcp_ruby.rb → adds group_source + group_role_mapping_model\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The showcase groups were generated then customized: YAML models converted to DSL, extra presenters added for memberships and role mappings.",
    status: "stable"
  },
  {
    name: "Group Cache Invalidation",
    category: "groups",
    description: "Group registry data is cached in a thread-safe singleton. When group, membership, or role mapping records are saved or destroyed, `after_commit` callbacks automatically invalidate the cache.\n\nThis ensures authorization decisions always reflect the latest group state without requiring a restart.",
    config_example: "```ruby\n# Automatic — handled by ChangeHandler\n# When a group/membership/mapping is saved or destroyed:\n#   1. Groups::Registry cache is cleared\n#   2. PolicyFactory cache is cleared (policies capture group state)\n#   3. Next authorization check re-queries from DB\n\n# Manual refresh (rarely needed)\nLcpRuby::Groups::Registry.reload!\n```",
    demo_path: "/showcase/groups",
    demo_hint: "Edit a group or add a membership — changes take effect immediately without restarting the server.",
    status: "stable"
  },
  {
    name: "Groups Registry API",
    category: "groups",
    description: "Access group data programmatically through the `Groups::Registry` singleton. It delegates to the configured loader (YAML, Model, or Host) and caches results.\n\nUseful for building custom logic on top of the group system.",
    config_example: "```ruby\n# Query the registry\nLcpRuby::Groups::Registry.all_group_names\n# => [\"design\", \"engineering\", \"management\"]\n\nLcpRuby::Groups::Registry.groups_for_user(user)\n# => [\"engineering\", \"design\"]\n\nLcpRuby::Groups::Registry.roles_for_user(user)\n# => [\"editor\", \"viewer\"]\n\nLcpRuby::Groups::Registry.available?\n# => true (when group_source != :none)\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The registry powers the authorization integration — PermissionEvaluator calls `roles_for_user` during role resolution.",
    status: "stable"
  },
  {
    name: "Groups with Impersonation",
    category: "groups",
    description: "When impersonating a user (\"View as Role X\"), group-inherited roles are suppressed. The impersonated user only has the explicitly selected role(s).\n\nThis prevents group memberships from leaking additional permissions during permission testing.",
    config_example: "```ruby\n# Normal user: direct role \"viewer\" + group role \"editor\"\n# Resolved roles: [\"viewer\", \"editor\"]\n\n# Impersonating as \"viewer\":\n# Resolved roles: [\"viewer\"]  — group roles suppressed\n# This lets admins test exactly what a viewer-only user sees\n```",
    demo_path: "/showcase/groups",
    demo_hint: "Use the impersonation feature (admin only) to switch to viewer role — group-inherited roles are suppressed during impersonation.",
    status: "stable"
  },
  {
    name: "Group Source Configuration",
    category: "groups",
    description: "Four source types following the Configuration Source Principle:\n\n| Source | Config | Use Case |\n|--------|--------|----------|\n| `:none` | (default) | Groups disabled |\n| `:yaml` | `groups.yml` | Static groups in code |\n| `:model` | DB tables | Runtime management via UI |\n| `:host` | Adapter class | Enterprise directory integration |\n\nAll sources expose the same Registry API — switching sources is a config change, not a code rewrite.",
    config_example: "```ruby\n# Disable groups (default)\nconfig.group_source = :none\n\n# Static YAML groups\nconfig.group_source = :yaml\n\n# DB-backed groups with full UI\nconfig.group_source = :model\nconfig.group_role_mapping_model = \"group_role_mapping\"\n\n# Enterprise adapter\nconfig.group_source = :host\nconfig.group_adapter = MyLdapAdapter.new\n```",
    demo_path: "/showcase/groups",
    demo_hint: "The showcase uses `:model` source. Check the initializer to see the configuration — swap to `:yaml` or `:host` to test other sources.",
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
    description: "Hierarchical breadcrumbs for parent-child models. Configure `breadcrumb.relation` in the view group to automatically build the path.\n\nSelf-referential trees render each ancestor by its record name only — the model label appears once at the root, not at every level.",
    config_example: "```yaml\n# views/categories.yml\nview_group:\n  model: category\n  breadcrumb:\n    relation: parent\n```",
    demo_path: "/showcase/categories",
    demo_hint: "Navigate to a 4th-level category (e.g., React Ecosystem) — the breadcrumb shows: Home > Categories > Technology > Web Development > Frontend > React Ecosystem — no duplicate 'Categories' labels.",
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
  },
  # === Show Page Conditions ===
  {
    name: "Show Section Visibility (visible_when)",
    category: "presenter",
    description: "Hide show page sections based on field values. Evaluated server-side — hidden sections are not rendered in the DOM.",
    config_example: "```ruby\nshow do\n  section \"Advanced\",\n    visible_when: { field: :stage, operator: :not_eq, value: \"draft\" } do\n    field :details\n  end\nend\n```",
    demo_path: "/showcase/showcase-forms/1",
    demo_hint: "View **Simple Form** — 'Advanced Details' and 'Premium Info' sections are hidden. Then view **Advanced Config** — 'Advanced Details' appears.",
    status: "stable"
  },
  {
    name: "Show Section Disable (disable_when)",
    category: "presenter",
    description: "Visually disable show page sections based on field values. The section is rendered but with a disabled appearance.",
    config_example: "```ruby\nshow do\n  section \"Notes\",\n    disable_when: { field: :status, operator: :eq, value: \"archived\" } do\n    field :notes\n  end\nend\n```",
    demo_path: "/showcase/showcase-forms/3",
    demo_hint: "View **Special Request** — 'Standard Notes' section has a disabled appearance because form_type is 'special'.",
    status: "stable"
  },

  # === Custom Fields ===
  {
    name: "Custom Fields Overview",
    category: "custom_fields",
    description: "Custom fields let users define additional fields on models at runtime — no code changes, no migrations, no server restarts.\n\nEnable with `custom_fields: true` on any model. Field definitions are stored in the `custom_field_definitions` table. Values are stored in a `custom_data` JSONB column on each model's table.\n\nSupported types: `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `enum`.",
    config_example: "```ruby\n# Enable custom fields on a model\ndefine_model :employee do\n  custom_fields true\n  field :name, :string\n  field :email, :email\nend\n```\n\n```bash\n# Generate custom field definition metadata\nrails generate lcp_ruby:custom_fields\n```",
    demo_path: "/showcase/employees/custom-fields",
    demo_hint: "Navigate to **Employees → Custom Fields** to see all 10 custom field definitions. Click any field to view its configuration.",
    status: "stable"
  },
  {
    name: "Custom Fields Generator",
    category: "custom_fields",
    description: "A Rails generator scaffolds the full custom field definition setup: model, presenter, permissions, and view group.\n\nSupports both Ruby DSL (`--format=dsl`, default) and YAML (`--format=yaml`) output formats.\n\nThe generated files are fully customizable — modify the presenter to change columns, sections, or actions.",
    config_example: "```bash\n# Generate with Ruby DSL (default)\nrails generate lcp_ruby:custom_fields\n\n# Generate with YAML format\nrails generate lcp_ruby:custom_fields --format=yaml\n\n# Creates:\n#   config/lcp_ruby/models/custom_field_definition.rb\n#   config/lcp_ruby/presenters/custom_fields.rb\n#   config/lcp_ruby/permissions/custom_field_definition.yml\n#   config/lcp_ruby/views/custom_fields.rb\n```",
    demo_path: "/showcase/employees/custom-fields",
    demo_hint: "The showcase app used the DSL generator. Check `config/lcp_ruby/models/custom_field_definition.rb` for the generated model.",
    status: "stable"
  },
  {
    name: "String Custom Fields",
    category: "custom_fields",
    description: "String custom fields support `min_length`, `max_length`, `placeholder`, `default_value`, `searchable`, and `show_in_table`.\n\nIn the showcase, the **Nickname** field on employees demonstrates a searchable, sortable string custom field with length constraints (2–30 chars).",
    config_example: "Create via UI or programmatically:\n```ruby\ncfd = LcpRuby.registry.model_for(\"custom_field_definition\")\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"nickname\",\n  custom_type: \"string\",\n  label: \"Nickname\",\n  section: \"Personal Info\",\n  min_length: 2,\n  max_length: 30,\n  searchable: true,\n  show_in_table: true,\n  sortable: true\n)\n```",
    demo_path: "/showcase/employees",
    demo_hint: "Look at the **Nickname** column in the employees table. Edit an employee to see the string custom field in the form.",
    status: "stable"
  },
  {
    name: "Numeric Custom Fields",
    category: "custom_fields",
    description: "Integer, float, and decimal custom fields support `min_value`, `max_value`, `precision` (decimal only), and `default_value`.\n\nIn the showcase:\n- **Years of Experience** (integer, 0–50)\n- **Performance Score** (float, 0.0–10.0)\n- **Hourly Rate** (decimal, precision 2)",
    config_example: "```ruby\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"hourly_rate\",\n  custom_type: \"decimal\",\n  label: \"Hourly Rate (USD)\",\n  section: \"Compensation\",\n  min_value: 0,\n  precision: 2,\n  show_in_table: true,\n  sortable: true\n)\n```",
    demo_path: "/showcase/employees/1",
    demo_hint: "Open any employee's show view — the **Professional** and **Compensation** sections show numeric custom fields.",
    status: "stable"
  },
  {
    name: "Boolean Custom Fields",
    category: "custom_fields",
    description: "Boolean custom fields support `default_value` (`true`/`false`) and `required`.\n\nIn the showcase, the **Remote Worker** field on employees and **Public Project** on projects demonstrate boolean custom fields with default values.",
    config_example: "```ruby\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"remote_worker\",\n  custom_type: \"boolean\",\n  label: \"Remote Worker\",\n  default_value: \"false\",\n  show_in_table: true\n)\n```",
    demo_path: "/showcase/employees",
    demo_hint: "Look at the **Remote Worker** column — boolean custom fields render as Yes/No badges.",
    status: "stable"
  },
  {
    name: "Date & DateTime Custom Fields",
    category: "custom_fields",
    description: "Date and datetime custom fields support `required` and `default_value`.\n\nIn the showcase:\n- **Start Date** (date, visible in table)\n- **Last Performance Review** (datetime, visible in show view only)",
    config_example: "```ruby\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"start_date\",\n  custom_type: \"date\",\n  label: \"Start Date\",\n  section: \"Employment\",\n  show_in_table: true,\n  sortable: true\n)\n```",
    demo_path: "/showcase/employees/1",
    demo_hint: "Open an employee's show view — the **Employment** section shows start date and last review datetime.",
    status: "stable"
  },
  {
    name: "Enum Custom Fields",
    category: "custom_fields",
    description: "Enum custom fields require `enum_values` — a JSON array of strings or `{value, label}` objects. Support `default_value` and `required`.\n\nIn the showcase:\n- **T-Shirt Size** on employees uses labeled values (`{value: \"XS\", label: \"Extra Small\"}`)\n- **Priority** on projects uses simple string values (`[\"low\", \"medium\", \"high\", \"critical\"]`)",
    config_example: "```ruby\n# Simple enum values\ncfd.create!(\n  target_model: \"project\",\n  field_name: \"priority\",\n  custom_type: \"enum\",\n  label: \"Priority\",\n  enum_values: %w[low medium high critical],\n  default_value: \"medium\",\n  required: true\n)\n\n# Enum with custom labels\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"tshirt_size\",\n  custom_type: \"enum\",\n  label: \"T-Shirt Size\",\n  enum_values: [\n    { value: \"XS\", label: \"Extra Small\" },\n    { value: \"M\", label: \"Medium\" },\n    { value: \"XL\", label: \"Extra Large\" }\n  ]\n)\n```",
    demo_path: "/showcase/employees/1/edit",
    demo_hint: "Edit an employee — the **T-Shirt Size** field shows a dropdown with human-readable labels.",
    status: "stable"
  },
  {
    name: "Custom Field Sections",
    category: "custom_fields",
    description: "Custom fields are grouped into **sections** by their `section` attribute. Each section renders as a separate heading in forms and show views.\n\nUse `position` to control ordering within a section. Lower numbers appear first.\n\nIn the showcase, employee custom fields are grouped into: Personal Info, Professional, Compensation, Work Arrangement, Employment.",
    config_example: "```ruby\n# Fields with the same section appear together\ncfd.create!(target_model: \"employee\", field_name: \"nickname\",\n  section: \"Personal Info\", position: 0, ...)\ncfd.create!(target_model: \"employee\", field_name: \"bio\",\n  section: \"Personal Info\", position: 1, ...)\ncfd.create!(target_model: \"employee\", field_name: \"hourly_rate\",\n  section: \"Compensation\", position: 0, ...)\n```",
    demo_path: "/showcase/employees/1",
    demo_hint: "Open an employee's show view — custom fields are organized under 5 different section headings.",
    status: "stable"
  },
  {
    name: "Custom Field Display Options",
    category: "custom_fields",
    description: "Control visibility with `show_in_table`, `show_in_form`, `show_in_show`. Enable sorting with `sortable: true` and search with `searchable: true`.\n\nThe `column_width` attribute sets CSS width for table columns.\n\nInactive fields (`active: false`) are completely hidden from all views.",
    config_example: "```ruby\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"nickname\",\n  custom_type: \"string\",\n  label: \"Nickname\",\n  show_in_table: true,    # Appears in index table\n  show_in_form: true,     # Appears in create/edit forms\n  show_in_show: true,     # Appears in show view\n  sortable: true,         # Column header is clickable\n  searchable: true,       # Included in text search\n  column_width: \"120px\"   # Fixed column width\n)\n```",
    demo_path: "/showcase/employees",
    demo_hint: "The **Nickname** column is sortable (click header). The **Legacy ID** field has `active: false` — it is completely hidden.",
    status: "stable"
  },
  {
    name: "Custom Field Permissions",
    category: "custom_fields",
    description: "Custom fields support **per-field permission granularity**. Individual custom field names can appear in `fields.readable`, `fields.writable`, and `field_overrides`.\n\nThe aggregate `custom_data` key still works as a catch-all for backward compatibility.\n\n| Config | Result |\n|--------|--------|\n| `readable: all` | All fields including all custom fields |\n| `readable: [title, custom_data]` | title + ALL custom fields (aggregate) |\n| `readable: [title, website]` | title + only the \"website\" custom field |\n| `field_overrides: { website: { readable_by: [admin] } }` | Per-field override |\n\nCustom field definitions have their own separate permissions file (`permissions/custom_field_definition.yml`).",
    config_example: "```yaml\n# permissions/employee.yml — per-field custom field permissions\npermissions:\n  model: employee\n  roles:\n    admin:\n      fields:\n        readable: all           # all fields + all custom fields\n        writable: all\n    editor:\n      fields:\n        readable: [name, email, nickname, bio]  # specific custom fields\n        writable: [name, nickname]               # only some writable\n    viewer:\n      fields:\n        readable: [name, custom_data]  # aggregate: all custom fields\n        writable: []\n  field_overrides:\n    hourly_rate:\n      readable_by: [admin]      # only admin sees hourly_rate\n      writable_by: [admin]\n```",
    demo_path: "/showcase/employees/custom-fields",
    demo_hint: "Custom fields use per-field permissions. Use impersonation to see different custom fields visible for different roles.",
    status: "stable"
  },
  {
    name: "Custom Fields on Multiple Models",
    category: "custom_fields",
    description: "Multiple models can enable `custom_fields: true` independently. Each model's custom fields are scoped by `target_model` — field definitions for 'employee' don't affect 'project'.\n\nManagement URLs are nested under each model's slug: `/employees/custom-fields`, `/projects/custom-fields`.",
    config_example: "```ruby\n# Enable on multiple models\ndefine_model :employee do\n  custom_fields true\n  # ...\nend\n\ndefine_model :project do\n  custom_fields true\n  # ...\nend\n```\n\nManagement routes:\n```\n/employees/custom-fields     → Employee field definitions\n/projects/custom-fields      → Project field definitions\n```",
    demo_path: "/showcase/projects/custom-fields",
    demo_hint: "Navigate to **Projects → Custom Fields** — these are separate from employee custom fields, scoped by `target_model`.",
    status: "stable"
  },
  {
    name: "Programmatic Custom Field Access",
    category: "custom_fields",
    description: "Custom field values can be read and written in Ruby code using dynamic accessors or the low-level API.\n\nAfter creating definitions, `after_commit` callbacks automatically refresh accessor methods on the target model — no restart needed.",
    config_example: "```ruby\nmodel = LcpRuby.registry.model_for(\"employee\")\nrecord = model.find(1)\n\n# Dynamic accessors\nrecord.nickname                  # => \"JaneS\"\nrecord.nickname = \"Jane\"\nrecord.save!\n\n# Low-level API\nrecord.read_custom_field(\"nickname\")\nrecord.write_custom_field(\"nickname\", \"Jane\")\nrecord.save!\n\n# Create definitions programmatically\ncfd = LcpRuby.registry.model_for(\"custom_field_definition\")\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"badge_number\",\n  custom_type: \"integer\",\n  label: \"Badge #\"\n)\n# Accessors available immediately!\n```",
    demo_path: "/showcase/employees/1",
    demo_hint: "View an employee record — custom field values like Nickname, Years of Experience, and T-Shirt Size are set via dynamic accessors in seed data.",
    status: "stable"
  },
  {
    name: "Custom Field Hints",
    category: "custom_fields",
    description: "Custom field definitions support an optional `hint` attribute — a short help text displayed below form inputs to guide users.\n\nHints are propagated through the LayoutBuilder and rendered beneath each field in create/edit forms. Use hints to clarify expected values, units, or business rules without cluttering the label.",
    config_example: "```ruby\ncfd.create!(\n  target_model: \"employee\",\n  field_name: \"nickname\",\n  custom_type: \"string\",\n  label: \"Nickname\",\n  hint: \"Short display name used in casual contexts\",\n  # ...\n)\n```",
    demo_path: "/showcase/employees/custom-fields",
    demo_hint: "Edit a custom field definition — fields like Nickname and Hourly Rate show hint text below the form inputs.",
    status: "stable"
  },
  {
    name: "Conditional Custom Field Form",
    category: "custom_fields",
    description: "The custom field definition form uses `visible_when` on sections to show only the relevant constraint fields for the selected type.\n\n- **Text Constraints** (min_length, max_length) — visible when `custom_type` is `string` or `text`\n- **Numeric Constraints** (min_value, max_value, precision) — visible when `custom_type` is `integer`, `float`, or `decimal`\n- **Enum Values** — visible when `custom_type` is `enum`\n\nThis reduces form clutter and prevents users from setting irrelevant constraints.",
    config_example: "```ruby\n# In the custom fields presenter DSL:\nsection \"Text Constraints\" do\n  visible_when field: :custom_type, operator: :in,\n               value: %w[string text]\n  field :min_length\n  field :max_length\nend\n\nsection \"Numeric Constraints\" do\n  visible_when field: :custom_type, operator: :in,\n               value: %w[integer float decimal]\n  field :min_value\n  field :max_value\n  field :precision\nend\n```",
    demo_path: "/showcase/employees/custom-fields/new",
    demo_hint: "Create a new custom field and change the Type dropdown — constraint sections appear/disappear based on the selected type.",
    status: "stable"
  },
  # === Virtual Fields ===
  {
    name: "Virtual Fields Overview",
    category: "virtual_fields",
    description: "Virtual fields have no database column — their values are stored elsewhere (JSON column, external service, computed). Two source types:\n\n| Source | How it works |\n|--------|-------------|\n| `source: { service: \"json_field\" }` | Reads/writes a key inside a JSON column via built-in accessor |\n| `source: external` | Host app defines getter/setter methods via `on_model_ready` |\n\nVirtual fields support validations, defaults, and enums just like regular fields.",
    config_example: "```ruby\n# JSON-backed virtual field\nfield :color, :string, label: \"Color\",\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"color\" } }\n\n# External (host-defined) virtual field\nfield :full_location, :string, label: \"Full Location\",\n  source: :external\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Browse the list — notice that columns like color, priority, and category are not real DB columns but read from JSON.",
    status: "beta"
  },
  {
    name: "JSON Field Accessor (String)",
    category: "virtual_fields",
    description: "The `json_field` service accessor stores a string value inside a JSON column. Specify `column` (the real JSON column name) and `key` (the JSON key).\n\nThe accessor transparently reads and writes the JSON, marking the column dirty so ActiveRecord persists the change.",
    config_example: "```ruby\nfield :color, :string, label: \"Color\",\n  source: {\n    service: \"json_field\",\n    options: { column: \"properties\", key: \"color\" }\n  }\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Edit a record and change the **Color** field — then check the Raw JSON section to see the properties column updated.",
    status: "beta"
  },
  {
    name: "JSON Field Accessor (Integer with Validation)",
    category: "virtual_fields",
    description: "Virtual fields support standard validations. An integer stored in JSON can have `numericality` constraints just like a column-backed field.\n\nValidation errors appear on the virtual field name, not the JSON column.",
    config_example: "```ruby\nfield :priority, :integer, label: \"Priority\",\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"priority\" } } do\n  validates :numericality, only_integer: true,\n    greater_than_or_equal_to: 1, less_than_or_equal_to: 5,\n    allow_nil: true\nend\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Try entering **priority = 0** or **priority = 6** — validation rejects values outside 1–5.",
    status: "beta"
  },
  {
    name: "JSON Field Accessor (Boolean)",
    category: "virtual_fields",
    description: "Boolean values stored in JSON work seamlessly with checkbox inputs. The accessor reads `true`/`false` from the JSON key.",
    config_example: "```ruby\nfield :featured, :boolean, label: \"Featured\",\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"featured\" } }\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Look at the **Featured** column in the index — it renders as a boolean icon (check/cross).",
    status: "beta"
  },
  {
    name: "Virtual Enum (Inclusion Validation)",
    category: "virtual_fields",
    description: "Virtual enums cannot use the ActiveRecord `enum` macro (no DB column), so LCP automatically adds an `inclusion` validation instead.\n\nThe enum values are used for select inputs and badge rendering.",
    config_example: "```ruby\nfield :category, :enum, label: \"Category\",\n  values: %w[electronics clothing food furniture other],\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"category\" } }\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Look at the **Category** column — rendered as a colored badge. Edit a record to see the select dropdown.",
    status: "beta"
  },
  {
    name: "Virtual Field with Default",
    category: "virtual_fields",
    description: "Virtual fields support static defaults. When a new record is created, the default value is applied if the field is blank.\n\nNote: `current_date` and service defaults also work on virtual fields.",
    config_example: "```ruby\nfield :warehouse, :string, label: \"Warehouse\",\n  default: \"MAIN-01\",\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"warehouse\" } }\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Create a new record without filling the **Warehouse** field — it defaults to MAIN-01.",
    status: "beta"
  },
  {
    name: "Multiple Virtual Fields from One JSON Column",
    category: "virtual_fields",
    description: "Any number of virtual fields can share the same JSON column. Each field targets a different key. This is the primary use case — a single `properties` column backs many typed fields.\n\nThe JSON column itself can also be shown/edited directly.",
    config_example: "```ruby\n# All share the same 'properties' column\nfield :color, :string,\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"color\" } }\nfield :priority, :integer,\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"priority\" } }\nfield :sku_code, :string,\n  source: { service: \"json_field\",\n            options: { column: \"properties\", key: \"sku_code\" } }\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Look at the **Raw JSON** section on the show page — all virtual field values live in one JSON object.",
    status: "beta"
  },
  {
    name: "External Source (Computed Field)",
    category: "virtual_fields",
    description: "Fields with `source: external` require the host app to define getter/setter methods. Use `on_model_ready` in the initializer to inject methods before validation runs.\n\n`full_location` concatenates `city` and `country` (both JSON-backed) into a single read-only string.",
    config_example: "```ruby\n# Model definition\nfield :full_location, :string, label: \"Full Location\",\n  source: :external\n\n# config/initializers/lcp_ruby.rb\nLcpRuby.configure do |config|\n  config.on_model_ready(\"showcase_virtual_field\") do |klass|\n    klass.define_method(:full_location) do\n      parts = [city, country].compact_blank\n      parts.any? ? parts.join(\", \") : nil\n    end\n    klass.define_method(:full_location=) { |_v| }\n  end\nend\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "View a record with city and country set — **Full Location** shows \"San Francisco, USA\". Records without location show blank.",
    status: "beta"
  },
  {
    name: "External Source (Derived Field)",
    category: "virtual_fields",
    description: "External fields can derive values from other virtual fields. `priority_label` maps the integer priority (1–5) to a human label.\n\nThis pattern is useful for display-only fields that depend on other field values.",
    config_example: "```ruby\n# Model definition\nfield :priority_label, :string, label: \"Priority Label\",\n  source: :external\n\n# config/initializers/lcp_ruby.rb\nconfig.on_model_ready(\"showcase_virtual_field\") do |klass|\n  klass.define_method(:priority_label) do\n    { 1 => \"Lowest\", 2 => \"Low\", 3 => \"Medium\",\n      4 => \"High\", 5 => \"Critical\" }[priority]\n  end\n  klass.define_method(:priority_label=) { |_v| }\nend\n```",
    demo_path: "/showcase/showcase-virtual-fields",
    demo_hint: "Look at the **Priority Label** column in the index — it shows \"High\", \"Low\", etc. based on the integer priority value.",
    status: "beta"
  },

  # === Positioning ===
  {
    name: "Basic Positioning",
    category: "positioning",
    description: "Declare `positioning` on a model to enable automatic sequential position assignment. New records are appended at the end. Deleting a record closes the gap (remaining records shift down).\n\nRequires a `position` field of type `integer`.",
    config_example: "```ruby\ndefine_model :priority do\n  field :name, :string\n  field :position, :integer\n\n  positioning  # uses default 'position' field\nend\n```\n\n```yaml\n# Equivalent YAML\npositioning: true\n```",
    demo_path: "/showcase/showcase-positioning",
    demo_hint: "Create a new item — it appears at the bottom with the next position number. Delete a middle item and watch the remaining positions close the gap.",
    status: "stable"
  },
  {
    name: "Scoped Positioning",
    category: "positioning",
    description: "Position records within a parent group using `scope`. Each scope maintains independent position sequences.\n\nExample: pipeline stages are ordered independently per pipeline. Moving a stage to a different pipeline appends it at the end of the new pipeline.",
    config_example: "```ruby\ndefine_model :pipeline_stage do\n  field :name, :string\n  field :position, :integer\n  belongs_to :pipeline, model: :pipeline\n\n  positioning scope: :pipeline_id\nend\n```\n\n```yaml\n# Equivalent YAML\npositioning:\n  scope: pipeline_id\n```",
    demo_path: "/showcase/pipeline-stages",
    demo_hint: "Look at the position column — Sales stages are 1–6, Hiring stages are 1–5, Support stages are 1–4. Each pipeline has independent ordering.",
    status: "stable"
  },
  {
    name: "Reorderable Index",
    category: "positioning",
    description: "Add `reorderable: true` to a presenter's index block to enable drag-and-drop reordering. Drag handles appear as the first column.\n\nThe index automatically sorts by position. The position column is optional — drag-and-drop works regardless of whether the position number is visible.\n\nDropping an item below the last row places it at the end of the list. A bottom indicator is shown during the drag to confirm the target position.",
    config_example: "```ruby\ndefine_presenter :priorities do\n  model :priority\n\n  index do\n    reorderable true  # enables drag-and-drop\n    column :name, link_to: :show\n    column :position  # optional — shows position number\n  end\nend\n```\n\n```yaml\n# Equivalent YAML\nindex:\n  reorderable: true\n```",
    demo_path: "/showcase/showcase-positioning",
    demo_hint: "Drag a row by the handle on the left side to reorder it. The position numbers update automatically after the drop.",
    status: "stable"
  },
  {
    name: "Position Auto-Management",
    category: "positioning",
    description: "The `positioning` gem handles all position bookkeeping automatically:\n\n- **Create:** New records are appended at the end (position = max + 1)\n- **Destroy:** Gap is closed (records after the deleted one shift down)\n- **Scope change:** Record is removed from old scope (gap closed) and appended at end of new scope\n- **Reorder:** Setting position to a new value shifts other records atomically\n\nNo manual position management is needed.",
    config_example: "```ruby\n# All automatic — just add positioning to the model\ndefine_model :task do\n  field :position, :integer\n  positioning\nend\n\n# Create records — positions auto-assigned\nTask.create!(name: \"First\")   # position: 1\nTask.create!(name: \"Second\")  # position: 2\nTask.create!(name: \"Third\")   # position: 3\n\n# Delete second — gap closes\nTask.find_by(name: \"Second\").destroy!\n# First: 1, Third: 2  (shifted down)\n```",
    demo_path: "/showcase/showcase-positioning",
    demo_hint: "Create 3 items, note positions 1–3. Delete the middle item — the last item shifts from position 3 to position 2.",
    status: "stable"
  },
  {
    name: "Permission-Controlled Reordering",
    category: "positioning",
    description: "Drag-and-drop reordering respects two permission levels:\n\n1. **CRUD level:** User must have `update` permission on the model\n2. **Field level:** The `position` field must be in the user's `writable` fields list\n\nThis allows roles that can edit records but cannot reorder them. Drag handles are only rendered when both checks pass.",
    config_example: "```yaml\nroles:\n  manager:\n    crud: [index, show, create, update, destroy]\n    fields:\n      writable: [name, description, position]  # can reorder\n\n  editor:\n    crud: [index, show, update]\n    fields:\n      writable: [name, description]  # can edit but NOT reorder\n\n  viewer:\n    crud: [index, show]\n    # no update permission — no drag handles\n```",
    demo_path: "/showcase/showcase-positioning",
    demo_hint: "Log in as admin — drag handles are visible. Switch to a viewer role — drag handles disappear.",
    status: "stable"
  },
  {
    name: "Concurrent Edit Detection",
    category: "positioning",
    description: "When two users view the same list, the system detects conflicts via a `list_version` hash (SHA-256 of record IDs in position order).\n\n- Each reorder request includes the stored `list_version`\n- Server recomputes and compares — if mismatch, returns `409 Conflict`\n- Frontend reloads the page with a flash message\n- On success, the response includes the updated `list_version` for the next reorder",
    config_example: "```ruby\n# Server response on success (200):\n{ position: 3, list_version: \"a1b2c3...\" }\n\n# Server response on conflict (409):\n{ error: \"list_version_mismatch\", list_version: \"d4e5f6...\" }\n```",
    demo_path: "/showcase/showcase-positioning",
    demo_hint: "Open the same list in two browser tabs. Reorder in tab 1, then try to reorder in tab 2 — it will reload with a conflict message.",
    status: "stable"
  },
  {
    name: "Positioning DSL",
    category: "positioning",
    description: "The Ruby DSL supports `positioning` with optional `field` and `scope` parameters. The presenter DSL supports `reorderable` in the index block.\n\nBoth DSL and YAML are equivalent — use whichever fits your workflow.",
    config_example: "```ruby\n# Model DSL\ndefine_model :stage do\n  field :position, :integer\n  positioning                                    # basic\n  positioning field: :sort_order                  # custom field\n  positioning scope: :pipeline_id                 # scoped\n  positioning scope: [:pipeline_id, :category]    # multi-scope\nend\n\n# Presenter DSL\ndefine_presenter :stages do\n  index do\n    reorderable true\n  end\nend\n```",
    demo_path: "/showcase/showcase-positioning",
    demo_hint: "Both the priority list and pipeline stages use the DSL form. Check the model source files for examples.",
    status: "stable"
  },

  # --- Tier 1: UX Polish Features ---
  {
    name: "Empty Value Display",
    category: "presenter",
    description: "When a field value is `nil` or blank, the platform renders a styled placeholder instead of an empty cell. The placeholder text is configurable at three levels:\n\n1. **Global** — `LcpRuby.configure { |c| c.empty_value = \"---\" }`\n2. **Presenter** — `empty_value \"N/A\"` (overrides global for this presenter)\n3. **i18n** — `lcp_ruby.empty_value` locale key (fallback when neither is set)\n\nThe placeholder is rendered with the CSS class `lcp-empty-value` for consistent styling.",
    config_example: "```ruby\n# Presenter DSL\ndefine_presenter :showcase_fields_table do\n  empty_value \"N/A\"\n  # ...\nend\n\n# YAML equivalent\npresenter:\n  name: showcase_fields_table\n  empty_value: \"N/A\"\n```",
    demo_path: "/showcase/showcase-fields",
    demo_hint: "Open any record that has nil fields (e.g., phone, website). The empty fields display \"N/A\" in muted text instead of blank space.",
    status: "stable"
  },
  {
    name: "Copy URL Button",
    category: "presenter",
    description: "The show page toolbar includes a \"Copy link\" button that copies the current record's URL to the clipboard. This is enabled by default on all presenters.\n\nTo disable it (e.g., for read-only summary views), set `copy_url: false` in the show block.",
    config_example: "```ruby\n# Disable copy URL on a specific presenter\ndefine_presenter :compact_view do\n  show do\n    copy_url false\n    # ...\n  end\nend\n\n# YAML equivalent\nshow:\n  copy_url: false\n```",
    demo_path: "/showcase/showcase-fields-card",
    demo_hint: "Open a record in the Card view — the \"Copy link\" button is hidden. Then open the same record in the Table view (showcase-fields) — the button is visible.",
    status: "stable"
  },
  {
    name: "Copyable Fields",
    category: "presenter",
    description: "Individual fields on the show page can have a copy-to-clipboard icon. When clicked, the field's display value is copied to the clipboard with a brief \"Copied!\" tooltip.\n\nAdd `copyable: true` to any field in the show layout. Works with all field types and renderers.",
    config_example: "```ruby\n# Presenter DSL — show section\nsection \"Article Details\", columns: 2 do\n  field :title, renderer: :heading, copyable: true\n  field \"category.name\", label: \"Category\", copyable: true\nend\n\n# YAML equivalent\nfields:\n  - { field: title, renderer: heading, copyable: true }\n  - { field: category.name, label: Category, copyable: true }\n```",
    demo_path: "/showcase/articles",
    demo_hint: "Open any article — the title and category fields have a small copy icon. Click it to copy the value.",
    status: "stable"
  },
  {
    name: "Sticky Table Header",
    category: "presenter",
    description: "Index page table headers (`<thead>`) stay pinned to the top of the viewport when scrolling long lists. This is a pure CSS feature using `position: sticky` — no configuration needed.\n\nThe sticky behavior automatically adapts to the toolbar height and works in all modern browsers.",
    config_example: "```css\n/* Built-in — no configuration needed */\n/* The engine applies this automatically: */\n.lcp-table thead th {\n  position: sticky;\n  top: 0;\n  z-index: 10;\n}\n```",
    demo_path: "/showcase/features",
    demo_hint: "Scroll down the feature catalog table — the column headers stay pinned at the top of the page.",
    status: "stable"
  },
  {
    name: "404 Error Page",
    category: "presenter",
    description: "When navigating to a non-existent presenter slug or a missing record ID, the platform renders a styled 404 page with a \"Back to home\" link instead of a raw Rails error.\n\nThis is the default behavior — no configuration required. The page uses the `lcp_ruby.errors.not_found` i18n key.",
    config_example: "```ruby\n# No configuration needed — automatic behavior\n# Try navigating to any invalid URL:\n#   /showcase/this-page-does-not-exist\n#   /showcase/articles/999999\n\n# Customize the message via i18n:\n# config/locales/en.yml\nen:\n  lcp_ruby:\n    errors:\n      not_found: \"Page not found\"\n      not_found_message: \"The page you're looking for doesn't exist.\"\n```",
    demo_path: "/showcase/this-page-does-not-exist",
    demo_hint: "Click the demo link — it navigates to a non-existent page and shows a styled 404 error with a link back to the home page.",
    status: "stable"
  },
  {
    name: "Redirect After CRUD",
    category: "presenter",
    description: "Controls where the user is redirected after a successful create or update. By default, both redirect to the show page. Override per presenter to change the flow.\n\nValid targets: `index`, `show`, `edit`, `new`.",
    config_example: "```ruby\n# Presenter DSL\ndefine_presenter :tags do\n  redirect_after create: :index, update: :index\n  # ...\nend\n\n# YAML equivalent\npresenter:\n  name: tags\n  redirect_after:\n    create: index\n    update: index\n```",
    demo_path: "/showcase/tags",
    demo_hint: "Create a new tag — after saving, you're redirected to the tag list (index) instead of the show page. Edit a tag and save — same redirect to index.",
    status: "stable"
  },
  {
    name: "Selectbox Sorting",
    category: "form",
    description: "Enum select dropdowns can be sorted alphabetically by adding `input_options: { sort: \"alphabetical\" }` to the field definition. By default, enum options are displayed in the order defined in the model.",
    config_example: "```ruby\n# Presenter DSL — form section\nfield :role, input_type: :select, input_options: { sort: \"alphabetical\" }\n\n# YAML equivalent\nfields:\n  - field: role\n    input_type: select\n    input_options:\n      sort: alphabetical\n```",
    demo_path: "/showcase/employees/new",
    demo_hint: "Open the Role dropdown — options are sorted alphabetically (Admin, Designer, Developer, Intern, Manager) instead of the model-defined order.",
    status: "stable"
  },
  {
    name: "Auto-Search",
    category: "presenter",
    description: "When `auto_search: true` is set in the search config, the search form auto-submits as the user types, after a configurable debounce delay. This eliminates the need to press Enter or click a Search button.\n\nOptions:\n- `debounce_ms` — delay in ms before auto-submit (default: 300)\n- `min_query_length` — minimum characters before triggering (default: 2; empty input always triggers to clear the search)",
    config_example: "```ruby\n# Presenter DSL\nsearch do\n  auto_search true\n  debounce_ms 300\n  min_query_length 2\nend\n\n# YAML equivalent\nsearch:\n  auto_search: true\n  debounce_ms: 300\n  min_query_length: 2\n```",
    demo_path: "/showcase/features",
    demo_hint: "Start typing in the search box — the table updates automatically after a short delay. No need to press Enter.",
    status: "stable"
  },
  {
    name: "NULL Filter (Predefined Scope)",
    category: "presenter",
    description: "Predefined filters can use model scopes that filter by NULL values. Define a scope with `where: { field: nil }` in the model, then reference it as a predefined filter in the presenter.\n\nThis enables \"missing data\" filters like \"No Mentor\", \"No Category\", etc.",
    config_example: "```ruby\n# Model DSL\ndefine_model :employee do\n  scope :without_mentor, where: { mentor_id: nil }\nend\n\n# Presenter DSL\nsearch do\n  filter :without_mentor, label: \"No Mentor\", scope: :without_mentor\nend\n```",
    demo_path: "/showcase/employees",
    demo_hint: "Click the \"No Mentor\" filter tab — only employees without an assigned mentor are shown.",
    status: "stable"
  },

  # === Row Styling (item_classes) ===
  {
    name: "Row Styling — eq Operator",
    category: "presenter",
    description: "The `eq` operator applies a CSS class when a field exactly matches a value. This is the most common use-case — styling rows by status, category, or any enum/string field.\n\nMultiple classes can be combined in a single rule (space-separated), e.g., `lcp-row-muted lcp-row-strikethrough` for cancelled records.",
    config_example: "```ruby\nindex do\n  # Single class\n  item_class \"lcp-row-success\",\n    when: { field: :status, operator: :eq, value: \"completed\" }\n\n  # Multiple classes in one rule\n  item_class \"lcp-row-muted lcp-row-strikethrough\",\n    when: { field: :status, operator: :eq, value: \"cancelled\" }\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "Look at rows with **Completed** status (green background) and **Cancelled** status (grayed out + strikethrough).",
    status: "stable"
  },
  {
    name: "Row Styling — in / not_in Operators",
    category: "presenter",
    description: "The `in` operator matches when the field value is one of several values. `not_in` is the inverse — matches when the value is NOT in the list.\n\nUseful for grouping multiple statuses (e.g., all \"closed\" states) under a single visual style.",
    config_example: "```ruby\nindex do\n  # Match any closed state\n  item_class \"lcp-row-muted\",\n    when: { field: :status, operator: :in, value: [\"cancelled\", \"on_hold\"] }\n\n  # Match anything except low/medium\n  item_class \"lcp-row-bold\",\n    when: { field: :priority, operator: :not_in, value: [\"low\", \"medium\"] }\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "High and critical priority rows appear bold — they match a `not_in: [low, medium]` condition.",
    status: "stable"
  },
  {
    name: "Row Styling — gt / lt Operators (Numeric)",
    category: "presenter",
    description: "Numeric comparison operators `gt`, `gte`, `lt`, `lte` work on integer, float, decimal, date, and datetime fields.\n\nUse cases: highlight high-value records, flag low scores, mark items above/below thresholds.",
    config_example: "```ruby\nindex do\n  # Score above 90 → blue info highlight\n  item_class \"lcp-row-info\",\n    when: { field: :score, operator: :gt, value: 90 }\n\n  # Score below 20 → custom class\n  item_class \"lcp-item-low-score\",\n    when: { field: :score, operator: :lt, value: 20 }\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "Look at the **Score** column — records with score > 90 have a blue (info) background. Records with score < 20 have a custom class (inspect the DOM).",
    status: "stable"
  },
  {
    name: "Row Styling — present / blank Operators",
    category: "presenter",
    description: "The `present` operator matches when a field has any non-nil, non-empty value. `blank` matches when the field is nil or empty string.\n\nNo `value` parameter needed — these are unary operators. Useful for flagging incomplete records.",
    config_example: "```ruby\nindex do\n  # Flag records missing notes\n  item_class \"lcp-item-missing-notes\",\n    when: { field: :notes, operator: :blank }\n\n  # Highlight records with email\n  item_class \"lcp-row-info\",\n    when: { field: :email, operator: :present }\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "Records without **Notes** have the `lcp-item-missing-notes` custom class applied (inspect the `<tr>` element).",
    status: "stable"
  },
  {
    name: "Row Styling — matches Operator (Regex)",
    category: "presenter",
    description: "The `matches` operator evaluates a regular expression against a string/text field. `not_matches` is the inverse.\n\nOnly compatible with string and text field types. Regex has a 1-second safety timeout to prevent ReDoS.",
    config_example: "```ruby\nindex do\n  # Highlight temporary codes\n  item_class \"lcp-item-temp-code\",\n    when: { field: :code, operator: :matches, value: \"^TEMP\" }\n\n  # Highlight non-standard codes\n  item_class \"lcp-row-warning\",\n    when: { field: :code, operator: :not_matches, value: \"^[A-Z]+-\\\\d+$\" }\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "Records with **Code** starting with \"TEMP\" have the `lcp-item-temp-code` class (inspect the DOM).",
    status: "stable"
  },
  {
    name: "Row Styling — Service Condition",
    category: "presenter",
    description: "For complex logic that cannot be expressed as a simple field comparison, use a service condition. The service class receives the record and returns true/false.\n\nService conditions are always evaluated server-side. They support database lookups, date calculations, multi-field logic, and external API calls.",
    config_example: "```ruby\n# Presenter DSL\nindex do\n  item_class \"lcp-item-overdue\",\n    when: { service: :overdue_check }\nend\n\n# app/condition_services/overdue_check.rb\nmodule LcpRuby\n  module HostConditionServices\n    class OverdueCheck\n      def self.call(record)\n        record.due_date.present? && record.due_date < Date.current\n      end\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "Records with a past **Due Date** have the `lcp-item-overdue` class applied by the `OverdueCheck` service (inspect the DOM).",
    status: "stable"
  },
  {
    name: "Row Styling — Rule Accumulation",
    category: "presenter",
    description: "When a record matches multiple `item_class` rules, **all** matching CSS classes are applied simultaneously. There is no \"first match wins\" logic — classes accumulate.\n\nThis enables layered styling: a record can be both green (completed) and bold (high priority) at the same time. The CSS cascade determines the final visual appearance.",
    config_example: "```ruby\nindex do\n  # Rule 1: completed → green\n  item_class \"lcp-row-success\",\n    when: { field: :status, operator: :eq, value: \"completed\" }\n\n  # Rule 2: high priority → bold\n  item_class \"lcp-row-bold\",\n    when: { field: :priority, operator: :eq, value: \"high\" }\n\n  # A completed, high-priority record gets BOTH classes:\n  # class=\"lcp-row-success lcp-row-bold\"\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "Look at **Award-winning campaign** — it is both completed (green) and has score > 90 (info). Inspect the `<tr>` to see multiple classes. Also check **Abandoned experiment** — cancelled + low score + blank notes = 3 rules.",
    status: "stable"
  },
  {
    name: "Row Styling — Built-in CSS Classes",
    category: "presenter",
    description: "Seven built-in utility classes are provided, all using CSS custom properties for easy theming:\n\n| Class | Effect |\n|-------|--------|\n| `lcp-row-danger` | Red background |\n| `lcp-row-warning` | Yellow/amber background |\n| `lcp-row-success` | Green background |\n| `lcp-row-info` | Blue background |\n| `lcp-row-muted` | Reduced opacity (0.55) |\n| `lcp-row-bold` | Bold text |\n| `lcp-row-strikethrough` | Line-through text decoration |\n\nCustom CSS classes are also supported — use any valid class name.",
    config_example: "```css\n/* Override built-in colors via CSS custom properties */\n:root {\n  --lcp-row-danger-bg: #f8d7da;\n  --lcp-row-warning-bg: #fff3cd;\n  --lcp-row-success-bg: #d1e7dd;\n  --lcp-row-info-bg: #cff4fc;\n  --lcp-row-muted-opacity: 0.55;\n}\n\n/* Add your own custom classes */\n.lcp-item-overdue {\n  border-left: 4px solid #dc3545;\n}\n.lcp-item-temp-code {\n  background: #f0e6ff !important;\n}\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "The demo page shows all 7 built-in classes in action plus 4 custom classes. Look at the variety of row styles.",
    status: "stable"
  },
  {
    name: "Row Styling — Tiles & Tree Support",
    category: "presenter",
    description: "The `item_classes` feature works identically across all three index layouts:\n\n- **Table** — classes applied to `<tr>` elements\n- **Tiles** — classes applied to `.lcp-tile-card` elements\n- **Tree** — classes applied to tree node `<tr>` elements\n\nThe same `item_classes` configuration works on all layouts — no per-layout configuration needed.",
    config_example: "```ruby\n# Same config works for table, tiles, and tree:\nindex do\n  item_class \"lcp-row-success\",\n    when: { field: :status, operator: :eq, value: \"completed\" }\nend\n\n# Tiles inherit the same rules\ntiles do\n  title :name\n  subtitle :status\nend\n```",
    demo_path: "/showcase/showcase-item-classes",
    demo_hint: "The demo uses table layout. The same rules also apply to tiles and tree views if configured on the same presenter.",
    status: "stable"
  },

  # === Advanced Conditions ===
  {
    name: "Compound Conditions (all / any / not)",
    category: "permissions",
    description: "Combine multiple conditions with logical operators. `all` requires every child to be true (AND), `any` requires at least one (OR), `not` negates a single child.\n\nNesting is unlimited — combine `all`, `any`, and `not` to express arbitrarily complex rules.\n\nUsable in: `record_rules.condition`, `visible_when`, `disable_when`, `item_classes.when` — anywhere the platform accepts a condition hash.",
    config_example: "```ruby\n# DSL: all conditions must be true\nvisible_when: -> {\n  all do\n    field(:status).not_eq(\"closed\")\n    field(:due_date).lt({ \"date\" => \"today\" })\n    any do\n      field(:priority).eq(\"high\")\n      field(:priority).eq(\"critical\")\n    end\n  end\n}\n\n# YAML equivalent:\nvisible_when:\n  all:\n    - { field: status, operator: not_eq, value: closed }\n    - { field: due_date, operator: lt, value: { date: today } }\n    - any:\n      - { field: priority, operator: eq, value: high }\n      - { field: priority, operator: eq, value: critical }\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Look at the **item_classes** on the index: overdue active records (all: status != closed AND due_date < today) get a red row. Draft or review records (any: draft OR review) get a blue row. The **Description** form section uses compound visible_when.",
    status: "stable"
  },
  {
    name: "Dynamic Value References (field_ref)",
    category: "permissions",
    description: "Compare a field against another field on the same record instead of a hardcoded value. Use `{ field_ref: other_field }` as the `value` in a condition.\n\nSupports dot-path references too: `{ field_ref: \"company.credit_limit\" }`.",
    config_example: "```ruby\n# Row styling: amount exceeds budget_limit → bold\nitem_class \"lcp-row-bold\",\n  when: { field: :amount, operator: :gt,\n          value: { \"field_ref\" => \"budget_limit\" } }\n\n# YAML permission rule:\nrecord_rules:\n  - name: over_budget\n    condition:\n      field: approved_amount\n      operator: gt\n      value: { field_ref: budget_limit }\n    effect:\n      deny_crud: [update]\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records where **Amount** exceeds **Budget Limit** appear **bold** in the index. Look at \"Over-budget project\" (amount: $25,000, budget: $15,000).",
    status: "stable"
  },
  {
    name: "Dynamic Value References (current_user)",
    category: "permissions",
    description: "Compare a field against an attribute of the current user. Use `{ current_user: attribute }` as the `value` in a condition.\n\nCommon use case: owner-only editing where `author_id` must match the logged-in user's ID.",
    config_example: "```yaml\n# Only the record author can destroy\nrecord_rules:\n  - name: owner_only_destroy\n    condition:\n      not:\n        field: author_id\n        operator: eq\n        value: { current_user: id }\n    effect:\n      deny_crud: [destroy]\n      except_roles: [admin]\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records with **Author ID** different from the current user's ID hide the **Delete** button (record rule: `owner_only_destroy`). Switch to admin role to override.",
    status: "stable"
  },
  {
    name: "Dynamic Value References (date)",
    category: "permissions",
    description: "Compare a field against a dynamic date constant. Use `{ date: today }` or `{ date: now }` as the `value` in a condition.\n\n`today` resolves to `Date.current`, `now` resolves to `Time.current`. No date arithmetic — complex date computations use value services instead.",
    config_example: "```ruby\n# Item class: overdue active items\nitem_class \"lcp-row-danger\", when: -> {\n  all do\n    field(:status).not_eq(\"closed\")\n    field(:due_date).lt({ \"date\" => \"today\" })\n    field(:due_date).present\n  end\n}\n\n# YAML:\nitem_classes:\n  - class: lcp-row-danger\n    when:\n      all:\n        - { field: status, operator: not_eq, value: closed }\n        - { field: due_date, operator: lt, value: { date: today } }\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records with a past **Due Date** and non-closed status get a **red** row highlight. Compare \"Overdue budget review\" (past due) vs \"Upcoming deadline\" (future due).",
    status: "stable"
  },
  {
    name: "Dot-Path Fields in Conditions",
    category: "permissions",
    description: "Reference fields on associated records using dot-path syntax (e.g., `company.country.code`). Each segment must be a `belongs_to` or `has_one` association — `has_many` segments are invalid (use collection conditions instead).\n\nThe referenced associations must be included in the presenter's `includes` configuration to avoid N+1 queries.",
    config_example: "```ruby\n# Item class: unverified category → warning row\nitem_class \"lcp-row-warning\",\n  when: { field: \"showcase_condition_category.verified\",\n          operator: :eq, value: \"false\" }\n\n# Show section: only visible when category is verified\nsection \"Category Info\",\n  visible_when: { field: \"showcase_condition_category.verified\",\n                  operator: :eq, value: \"true\" } do\n  field \"showcase_condition_category.name\"\n  field \"showcase_condition_category.industry\"\nend\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records with an **unverified category** (\"New Vendor\") get a yellow **warning** row. On the show page, the \"Category Info\" section only appears when the category is verified.",
    status: "stable"
  },
  {
    name: "Collection Conditions (has_many Quantifiers)",
    category: "permissions",
    description: "Express conditions over `has_many` associations using quantifier syntax. Three quantifiers are supported:\n\n| Quantifier | Meaning |\n|------------|---|\n| `any` | At least one child matches |\n| `all` | Every child matches |\n| `none` | No child matches |\n\nCollection conditions can be nested inside compound conditions and the inner condition supports all features (dot-paths, operators, value references).",
    config_example: "```ruby\n# DSL: visible when at least one task is approved\nvisible_when: -> {\n  all do\n    field(:status).eq(\"review\")\n    collection(:tasks, quantifier: :any) do\n      field(:status).eq(\"approved\")\n    end\n  end\n}\n\n# YAML equivalent:\nvisible_when:\n  all:\n    - { field: status, operator: eq, value: review }\n    - collection: tasks\n      quantifier: any\n      condition: { field: status, operator: eq, value: approved }\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records with at least one **approved task** get a **green** (success) row. The **Approve** action button is only visible when status is \"review\" AND there is an approved task. Compare \"Pending approval with tasks\" (has approved task) vs \"Architecture review\" (no approved tasks).",
    status: "stable"
  },
  {
    name: "Value Services (Parameterized)",
    category: "extensibility",
    description: "Value services provide a **computed value** for the `value` side of a condition. Unlike condition services (which return a boolean), value services return a comparable value.\n\nThe `params:` hash supports typed value references (`field_ref`, `current_user`, etc.) — the evaluator resolves all references before calling the service.",
    config_example: "```ruby\n# YAML: compare amount against a computed threshold\ncondition:\n  field: amount\n  operator: gt\n  value:\n    service: budget_threshold\n    params:\n      priority: { field_ref: priority }\n\n# app/condition_services/budget_threshold.rb\nmodule LcpRuby\n  module HostConditionServices\n    class BudgetThreshold\n      def self.call(record, **params)\n        case params[:priority].to_s\n        when \"critical\" then 50_000\n        when \"high\" then 25_000\n        else 10_000\n        end\n      end\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "The `budget_threshold` value service is registered and available. It returns a priority-dependent threshold value that can be used in conditions.",
    status: "stable"
  },
  {
    name: "String Operators (starts_with / ends_with / contains)",
    category: "permissions",
    description: "Three new string operators reduce the need for regex patterns:\n\n| Operator | Description |\n|----------|---|\n| `starts_with` | String prefix match |\n| `ends_with` | String suffix match |\n| `contains` | Case-insensitive substring match |\n\nCompatible with string, text, email, phone, url, and color field types.",
    config_example: "```ruby\n# Highlight urgent codes\nitem_class \"lcp-item-urgent-code\",\n  when: { field: :code, operator: :starts_with, value: \"URGENT\" }\n\n# Highlight temp codes (case-insensitive)\nitem_class \"lcp-item-temp-code\",\n  when: { field: :code, operator: :contains, value: \"temp\" }\n\n# Match file extensions\nvisible_when:\n  field: filename\n  operator: ends_with\n  value: \".pdf\"\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records with **Code** starting with \"URGENT\" have a custom CSS class. Records with code containing \"temp\" (case-insensitive) also get highlighted. Inspect the `<tr>` elements to see the classes.",
    status: "stable"
  },
  {
    name: "Condition DSL Builder",
    category: "extensibility",
    description: "Ruby DSL for building conditions in presenter files. The `field(:name)` proxy returns a chainable object with operator methods (`.eq`, `.gt`, `.present`, etc.) that emit condition hashes.\n\nSupports `all`, `any`, `not_condition`, `collection`, and `service` blocks for building complex condition trees.",
    config_example: "```ruby\n# DSL: compound condition with collection\nvisible_when: -> {\n  all do\n    field(:status).eq(\"review\")\n    field(:amount).gt(0)\n    any do\n      field(:priority).eq(\"high\")\n      field(:priority).eq(\"critical\")\n    end\n    collection(:tasks, quantifier: :any) do\n      field(:status).eq(\"approved\")\n    end\n    not_condition do\n      field(:stage).eq(\"cancelled\")\n    end\n  end\n}\n\n# Available operators:\n# .eq .not_eq .gt .gte .lt .lte\n# .in .not_in .present .blank\n# .starts_with .ends_with .contains\n# .matches .not_matches\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "The showcase presenter uses the DSL extensively. Look at the source code to see how compound conditions, collection quantifiers, and value references are expressed in Ruby DSL.",
    status: "stable"
  },
  {
    name: "Lookup Value Reference",
    category: "permissions",
    description: "Compare a field against a value fetched from another model at evaluation time. Use `{ lookup, match, pick }` as the `value` in a condition.\n\n`lookup` names the target model, `match` provides `find_by` criteria (supports dynamic refs like `field_ref`), and `pick` names the field to return from the matched record.\n\nConstraints: target model must be defined in `config/lcp_ruby/models/`, nested lookups are not supported, and a `ConditionError` is raised if no record matches.",
    config_example: "```yaml\n# Item class: amount exceeds threshold from another model\nitem_classes:\n  - class: lcp-row-highlight\n    when:\n      field: amount\n      operator: gt\n      value:\n        lookup: condition_threshold\n        match: { key: high_amount }\n        pick: threshold\n\n# DSL equivalent:\nitem_class \"lcp-row-highlight\",\n  when: { field: :amount, operator: :gt,\n          value: { \"lookup\" => \"condition_threshold\",\n                   \"match\" => { \"key\" => \"high_amount\" },\n                   \"pick\" => \"threshold\" } }\n\n# DSL helper:\nfield(:price).lt(\n  ConditionBuilder.lookup(:tax_limit,\n    match: { key: \"vat_a\" },\n    pick: :threshold))\n\n# Dynamic match values (field_ref, current_user):\nvalue:\n  lookup: tax_limit\n  match:\n    key: { field_ref: tax_key }\n  pick: threshold\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "Records where **Amount** exceeds the `high_amount` threshold (10,000) from the `showcase_condition_threshold` table get a highlighted row. Compare \"Above lookup threshold\" (amount: $15,000 — highlighted) vs \"Below lookup threshold\" (amount: $8,000 — not highlighted).",
    status: "stable"
  },
  {
    name: "Eager Loading Validation for Conditions",
    category: "permissions",
    description: "The `ConfigurationValidator` now warns at boot time when index-context conditions (item_classes, action visible_when/disable_when) reference associations not covered by explicit `includes`.\n\nThe `DependencyCollector` auto-includes these associations at runtime as a safety net, so functionality is not affected. The warnings guide configurators to declare explicit `includes` for clarity and intentionality.\n\nValidation covers: dot-path field first segments, collection condition names, and value `field_ref` dot-paths.",
    config_example: "```yaml\n# Without explicit includes — validator warns:\nindex:\n  table_columns:\n    - { field: title }\n  item_classes:\n    - class: verified-row\n      when: { field: \"company.verified\", operator: eq, value: true }\n\n# Warning: Presenter 'tasks' index: item_classes[0] references\n# 'company' but index.includes does not contain 'company'.\n# Add 'includes: [company]' to the index configuration.\n\n# With explicit includes — no warning:\nindex:\n  includes: [company]\n  table_columns:\n    - { field: title }\n  item_classes:\n    - class: verified-row\n      when: { field: \"company.verified\", operator: eq, value: true }\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "The showcase conditions presenter declares `includes: [:showcase_condition_category, :showcase_condition_tasks]` to cover dot-path and collection conditions. Remove an entry and run `rake lcp_ruby:validate` to see the warning.",
    status: "stable"
  },
  {
    name: "Compound Record Rules",
    category: "permissions",
    description: "Permission `record_rules` support compound conditions — combine multiple criteria to determine when CRUD operations should be denied.\n\nExample: deny update/destroy when status is \"closed\" AND amount exceeds 10,000, except for admin role.",
    config_example: "```yaml\nrecord_rules:\n  - name: high_value_closed_locked\n    condition:\n      all:\n        - { field: status, operator: eq, value: closed }\n        - { field: amount, operator: gt, value: 10000 }\n    effect:\n      deny_crud: [update, destroy]\n      except_roles: [admin]\n\n  - name: owner_only_destroy\n    condition:\n      not:\n        field: author_id\n        operator: eq\n        value: { current_user: id }\n    effect:\n      deny_crud: [destroy]\n      except_roles: [admin]\n```",
    demo_path: "/showcase/showcase-conditions",
    demo_hint: "\"Big closed deal\" (closed + amount $50,000) has **Edit** and **Delete** buttons hidden for non-admin roles. \"Closed procurement\" (closed + amount $3,000) is still editable because it doesn't meet the compound threshold.",
    status: "stable"
  },

  # === Advanced Search ===
  {
    name: "Advanced Filter Builder",
    category: "search",
    description: "Visual filter builder with AND/OR grouping, nested conditions, type-aware operators, and cascading field picker for associations.\n\nSupports all field types: string, text, integer, float, decimal, boolean, date, datetime, enum, uuid, and business types (email, phone, url).",
    config_example: "```ruby\nsearch do\n  advanced_filter do\n    enabled true\n    max_conditions 20\n    max_nesting_depth 3\n    max_association_depth 2\n    allow_or_groups true\n    query_language true\n\n    filterable_fields :title, :price, :status,\n      \"department.name\", \"category.parent.name\"\n\n    field_options :status, operators: %i[eq not_eq in not_in]\n\n    preset :expensive_published,\n      label: \"Expensive & published\",\n      conditions: [\n        { field: \"published\", operator: \"true\" },\n        { field: \"price\", operator: \"gteq\", value: \"100\" }\n      ]\n  end\nend\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Click **Filters** to open the advanced filter. Try the cascading field picker — select an association to drill into its fields.",
    status: "stable"
  },
  {
    name: "Cascading Field Picker",
    category: "search",
    description: "When filtering on associations, the field picker cascades: the first select shows direct fields and association names. Selecting an association reveals a second select with that association's fields and sub-associations, up to `max_association_depth`.\n\nThis replaces the flat field dropdown that becomes overwhelming with many associations.",
    config_example: "```ruby\n# The cascading picker is automatic when association fields are configured:\nadvanced_filter do\n  max_association_depth 2\n  filterable_fields :title,\n    \"department.name\", \"department.code\",\n    \"category.name\",\n    \"category.parent.name\"   # 2-level deep\nend\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Open Filters → click the field picker → select **Department** or **Category** to see the cascade. Category → Parent shows 2-level nesting.",
    status: "stable"
  },
  {
    name: "Query Language (QL)",
    category: "search",
    description: "Text-based query language as an alternative to the visual filter builder. Supports all operators, AND/OR logic, parentheses for grouping, and dot-path fields for associations.\n\nThe QL can be toggled from the visual builder and round-trips both ways: visual → QL → visual.",
    config_example: "```\n# Simple conditions\nstatus = 'published' and price >= 100\n\n# OR groups with parentheses\ntitle ~ 'widget' and (status = 'published' or priority in ['high', 'critical'])\n\n# Association fields (dot-path)\ndepartment.name = 'Engineering' and category.parent.name = 'Technology'\n\n# No-value operators\npublished is true and contact_email is present\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Click **Edit as QL** to switch to query language mode. Type a query and press Apply, or switch back to visual mode to see the parsed result.",
    status: "stable"
  },
  {
    name: "Filter Presets",
    category: "search",
    description: "Pre-configured filter combinations that users can apply with a single click. Defined in the presenter DSL/YAML with a name, label, and list of conditions.\n\nPresets are shown as buttons above the filter builder.",
    config_example: "```ruby\nadvanced_filter do\n  preset :high_value_open,\n    label: \"High-value open deals\",\n    conditions: [\n      { field: \"stage\", operator: \"not_in\",\n        value: %w[closed_won closed_lost] },\n      { field: \"value\", operator: \"gteq\", value: \"10000\" }\n    ]\n\n  preset :closing_soon,\n    label: \"Closing this month\",\n    conditions: [\n      { field: \"expected_close_date\", operator: \"this_month\" }\n    ]\nend\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Open Filters and look for the preset buttons: **Expensive & published**, **Recent drafts**, etc.",
    status: "stable"
  },
  {
    name: "Relative Date Operators",
    category: "search",
    description: "Date and datetime fields support relative operators that resolve dynamically: `last_n_days` (with parameter), `this_week`, `this_month`, `this_quarter`, `this_year`.\n\nThese are in addition to standard comparison operators (eq, gt, lt, between).",
    config_example: "```ruby\n# In query language:\ncreated_at last_n_days 30      # created in last 30 days\nrelease_date this_month         # releasing this month\nlast_reviewed_at this_quarter   # reviewed this quarter\n\n# In visual builder:\n# Select a date field → choose \"Last N days\" operator → enter number\n# Or choose \"This week\", \"This month\", etc. (no value needed)\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Select **Release Date** or **Created at** in the filter, then browse the operator dropdown to see relative date options.",
    status: "stable"
  },

  # === Saved Filters & Parameterized Scopes ===
  {
    name: "Saved Filters",
    category: "search",
    description: "User-persistent named filters with full CRUD API. Filters store condition trees and QL text for a target presenter.\n\nSupports visibility levels (personal, role, group, global), pinning for quick access, and a default filter option that auto-applies when the page loads.\n\nGenerate the saved_filter model with `rails generate lcp_ruby:saved_filters`.",
    config_example: "```ruby\n# Presenter DSL — enable saved filters\nsearch do\n  advanced_filter do\n    saved_filters do\n      enabled true\n      display :inline\n      max_visible_pinned 5\n    end\n  end\nend\n```\n\n```bash\n# Generate the model, presenter, and permissions\nrails generate lcp_ruby:saved_filters\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Look for saved filter buttons above the filter builder. Click one to apply its conditions instantly.",
    status: "stable"
  },
  {
    name: "Parameterized Scopes",
    category: "search",
    description: "Scopes with typed parameters that users can configure at runtime. Parameters support types: integer, float, string, boolean, enum, date, datetime, model_select.\n\nIn the query language, parameterized scopes are invoked with `@scope_name(key: value)` syntax.\n\nParameter values are cast, validated (min/max/required), and clamped before being passed to the scope.",
    config_example: "```yaml\n# Model YAML\nscopes:\n  - name: created_recently\n    type: parameterized\n    parameters:\n      - name: days\n        type: integer\n        default: 30\n        min: 1\n        max: 365\n  - name: by_status_filter\n    type: parameterized\n    parameters:\n      - name: status\n        type: enum\n        values: [draft, published, archived]\n        required: true\n```\n\n```\n# Query language syntax\n@created_recently(days: 7)\n@by_status_filter(status: 'published')\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Try typing `@by_min_price(min_price: 50)` or `@created_recently(days: 7)` in the query language editor.",
    status: "stable"
  },
  {
    name: "Saved Filter Visibility",
    category: "search",
    description: "Saved filters support four visibility levels:\n\n- **personal** — only the owner can see and use the filter\n- **role** — visible to all users with the specified role\n- **group** — visible to members of the specified group\n- **global** — visible to all users\n\nOwnership rules and record_rules enforce who can create, edit, and delete filters at each visibility level.",
    config_example: "```yaml\n# Saved filter record examples:\n- name: \"My Quick Filter\"\n  visibility: personal\n  owner_id: 42\n\n- name: \"Admin Dashboard\"\n  visibility: role\n  target_role: admin\n  owner_id: 1\n\n- name: \"Team Backlog\"\n  visibility: group\n  target_group: engineering\n  owner_id: 5\n\n- name: \"All Open Items\"\n  visibility: global\n  owner_id: 1\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Check the saved filters — some are personal, one is global (All Published), one is role-scoped (Admin: In Review), and one is group-scoped (Engineering: High-Value Items).",
    status: "stable"
  },
  {
    name: "Saved Filter Display Modes",
    category: "search",
    description: "Saved filters support two display modes:\n\n- **inline** — pinned filters appear as buttons alongside predefined filters, remaining filters in a \"Saved...\" overflow dropdown grouped by visibility\n- **dropdown** — single \"Saved Filters\" button with a grouped dropdown menu listing all available filters\n\nChoose inline for quick access to frequently used filters, or dropdown to save toolbar space.",
    config_example: "```ruby\n# Inline display (default) — pinned buttons + overflow dropdown\nsaved_filters do\n  enabled true\n  display :inline\n  max_visible_pinned 5\nend\n\n# Dropdown display — single button with grouped menu\nsaved_filters do\n  enabled true\n  display :dropdown\n  max_visible_pinned 3\nend\n```",
    demo_path: "/showcase/articles",
    demo_hint: "Articles uses **dropdown** display — look for the \"Saved Filters\" button. Compare with Advanced Search which uses **inline** display with pinned filter buttons.",
    status: "stable"
  },
  {
    name: "Saved Filter Default",
    category: "search",
    description: "A saved filter can be marked as the default for its presenter. When a user navigates to the index page without any explicit filter params, the default filter auto-applies.\n\nDefault priority: personal > group > role > global. A visual indicator shows when a default filter is active, and users can clear it with one click.",
    config_example: "```ruby\n# Presenter DSL — enable default filter support\nsaved_filters do\n  enabled true\n  allow_default true   # default: true\nend\n```\n\n```ruby\n# Saved filter record with default_filter: true\nSavedFilter.create!(\n  name: \"My Active Items\",\n  target_presenter: \"deals\",\n  condition_tree: { ... },\n  visibility: \"personal\",\n  default_filter: true,\n  owner_id: current_user.id\n)\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "The \"Published & Expensive\" filter is set as default — notice it auto-applies when you first visit the page with no filters.",
    status: "stable"
  },
  {
    name: "Saved Filter Pinning",
    category: "search",
    description: "Pinned filters get prominent placement in the toolbar for one-click access. In inline mode, pinned filters appear as buttons directly in the filter bar. The `max_visible_pinned` setting controls how many are shown before overflow.\n\nPinning can be disabled per-presenter with `allow_pinning: false`.",
    config_example: "```ruby\nsaved_filters do\n  enabled true\n  display :inline\n  allow_pinning true       # default: true\n  max_visible_pinned 5     # default: 5\nend\n```",
    demo_path: "/showcase/showcase-search",
    demo_hint: "Notice the pinned filter buttons in the toolbar — \"Published & Expensive\", \"Critical Priority\", \"All Published\", and \"Engineering: High-Value Items\" appear as direct buttons.",
    status: "stable"
  },

  # === Tiles View ===
  {
    name: "Tiles Layout",
    category: "tiles",
    description: "Renders index records as a responsive card grid instead of a table. Each card displays a title, optional subtitle, description, and configurable fields.\n\nSet `layout: tiles` in the index block and define a `tile` block with at least `title_field`.",
    config_example: "```ruby\nindex do\n  layout :tiles\n  tile do\n    title_field :name\n    subtitle_field :status, renderer: :badge\n    description_field :description, max_lines: 2\n    columns 3\n    card_link :show\n    actions :dropdown\n    field :price, label: \"Price\", renderer: :currency\n  end\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "Switch to the **Tiles** view via the view switcher. Each card shows title, status badge, description, and 6 fields with different renderers (currency, rating, boolean icon, email link, color swatch, date).",
    status: "stable"
  },
  {
    name: "Tile Title Field",
    category: "tiles",
    description: "The `title_field` is the only required tile attribute. It defines the main heading of each card. When combined with `card_link: :show`, the title becomes a clickable link to the record's show page.",
    config_example: "```ruby\ntile do\n  title_field :name\n  card_link :show   # title becomes a link\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "Each card's title is a clickable link — it navigates to the record's show page.",
    status: "stable"
  },
  {
    name: "Tile Subtitle with Renderer",
    category: "tiles",
    description: "The `subtitle_field` appears below the title. It supports a `renderer` and `options` for formatted display — most commonly used with the `:badge` renderer and a `color_map`.",
    config_example: "```ruby\ntile do\n  subtitle_field :status, renderer: :badge, options: {\n    color_map: { active: \"green\", draft: \"gray\", archived: \"orange\" }\n  }\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "The subtitle below each title shows the **Status** as a colored badge (green for active, gray for draft, etc.).",
    status: "stable"
  },
  {
    name: "Tile Description",
    category: "tiles",
    description: "The `description_field` adds body text to the card, automatically clamped to `max_lines` (default: 3). Uses CSS `-webkit-line-clamp` for truncation.",
    config_example: "```ruby\ntile do\n  description_field :description, max_lines: 2\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "Each card shows a description text truncated to 2 lines. Longer text is cut off with an ellipsis.",
    status: "stable"
  },
  {
    name: "Tile Columns",
    category: "tiles",
    description: "The `columns` attribute controls the number of cards per row. Default is 3. Responsive breakpoints automatically reduce columns on smaller screens (2 columns below 1200px, 1 column below 768px).\n\nCompare different column counts across the showcase: Fields (3), Aggregates (2), Employees (4).",
    config_example: "```ruby\ntile do\n  columns 4  # 4-column grid for compact cards\nend\n```",
    demo_path: "/showcase/employees-tiles",
    demo_hint: "The employees tiles use a **4-column** layout for compact cards. Compare with Fields (3 columns) and Aggregates (2 columns).",
    status: "stable"
  },
  {
    name: "Tile Card Actions",
    category: "tiles",
    description: "The `actions` attribute controls per-card action rendering:\n\n- `dropdown` (default) — shows a ⋯ menu button with action items\n- `inline` — renders action buttons directly on the card\n- `none` — hides all per-card actions",
    config_example: "```ruby\n# Dropdown (default)\ntile do\n  actions :dropdown\nend\n\n# Inline buttons\ntile do\n  actions :inline\nend\n\n# No actions\ntile do\n  actions :none\nend\n```",
    demo_path: "/showcase/showcase-aggregates-tiles",
    demo_hint: "Aggregates tiles use `actions: :inline` — action buttons appear directly on each card. Compare with Fields tiles (`dropdown`) and Employees tiles (`none`).",
    status: "stable"
  },
  {
    name: "Tile Fields with Renderers",
    category: "tiles",
    description: "Each `field` entry in the tile block renders as a label-value pair in the card body. Fields support all display renderers: `:currency`, `:badge`, `:boolean_icon`, `:email_link`, `:phone_link`, `:url_link`, `:color_swatch`, `:number`, `:date`, `:datetime`, `:relative_date`, `:rating`, etc.\n\nDot-path fields (e.g., `\"company.name\"`) are also supported for traversing associations.",
    config_example: "```ruby\ntile do\n  field :price, label: \"Price\", renderer: :currency, options: { currency: \"EUR\" }\n  field :email, label: \"Email\", renderer: :email_link\n  field \"department.name\", label: \"Department\"\n  field :is_active, label: \"Active\", renderer: :boolean_icon\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "Each card shows 6 fields with different renderers: Price (currency), Rating (stars), Active (boolean icon), Email (clickable link), Color (color swatch), Date (formatted).",
    status: "stable"
  },
  {
    name: "Dot-Path Fields in Tiles",
    category: "tiles",
    description: "Tile fields support dot-path notation to display associated record attributes. The engine automatically resolves `belongs_to` associations and applies eager loading to prevent N+1 queries.\n\nExamples: `\"category.name\"`, `\"author.name\"`, `\"department.name\"`.",
    config_example: "```ruby\ntile do\n  title_field :title\n  subtitle_field \"company.name\"   # association traversal\n  field \"category.name\", label: \"Category\"\n  field \"author.name\", label: \"Author\"\nend\n```",
    demo_path: "/showcase/articles-tiles",
    demo_hint: "Each article tile shows **Category** and **Author** as dot-path fields — these resolve through `belongs_to` associations.",
    status: "stable"
  },
  {
    name: "Sort Dropdown",
    category: "tiles",
    description: "The `sort_field` entries create a dropdown for sorting tiles. Each entry specifies a field and an optional label. Users can toggle ascending/descending direction with an arrow button.\n\nSort dropdown appears automatically when any `sort_field` is defined.",
    config_example: "```ruby\nindex do\n  sort_field :name, label: \"Name\"\n  sort_field :price, label: \"Price\"\n  sort_field :created_at, label: \"Newest\"\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "Use the **Sort by** dropdown above the tiles. Select \"Price\" and click the arrow to toggle ascending/descending order.",
    status: "stable"
  },
  {
    name: "Per-Page Selector",
    category: "tiles",
    description: "The `per_page_options` array creates a dropdown for choosing how many records to show per page. The selector appears near the pagination controls.\n\nValues outside the allowed list are ignored. The default `per_page` value should be included in the options list.",
    config_example: "```ruby\nindex do\n  per_page 12\n  per_page_options 6, 12, 24, 48\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "Look for the **Show** dropdown near the pagination. Switch between 6, 12, and 24 records per page.",
    status: "stable"
  },
  {
    name: "Summary Bar",
    category: "tiles",
    description: "The `summary` block displays aggregate values computed on the full filtered dataset (before pagination). Supports 5 SQL functions: `sum`, `avg`, `count`, `min`, `max`.\n\nEach field can have a `renderer` and `options` for formatted display (e.g., currency formatting).",
    config_example: "```ruby\nindex do\n  summary do\n    field :price, function: :sum, label: \"Total\", renderer: :currency\n    field :price, function: :avg, label: \"Average\", renderer: :currency\n    field :title, function: :count, label: \"Count\"\n    field :hours, function: :max, label: \"Max Hours\"\n    field :budget, function: :min, label: \"Min Budget\"\n  end\nend\n```",
    demo_path: "/showcase/showcase-aggregates-tiles",
    demo_hint: "The summary bar below the tiles shows all 5 aggregate functions: **Total Budget** (sum), **Avg Budget** (avg), **Project Count** (count), **Max Budget** (max), **Min Budget** (min).",
    status: "stable"
  },
  {
    name: "Tiles with Inheritance",
    category: "tiles",
    description: "Use `inherits:` to create a tiles view alongside an existing table presenter. The child inherits show, form, search, and actions — only the `index` block needs to be redefined.\n\nThis pattern keeps the tiles and table views in sync for non-index functionality.",
    config_example: "```ruby\ndefine_presenter :products_tiles, inherits: :products do\n  label \"Products (Tiles)\"\n  slug \"products-tiles\"\n\n  index do\n    layout :tiles\n    tile do\n      title_field :name\n      card_link :show\n    end\n  end\nend\n```",
    demo_path: "/showcase/showcase-fields-tiles",
    demo_hint: "The tiles view inherits show/form/actions from the table presenter. Click a tile to see the same show page as the table view.",
    status: "stable"
  },
  {
    name: "Tiles with View Groups",
    category: "tiles",
    description: "Tiles presenters integrate with view groups to provide a view switcher in the toolbar. Add the tiles presenter to the view group YAML alongside table and card views.\n\nThe view switcher lets users toggle between layouts without losing their current search/filter context.",
    config_example: "```yaml\n# config/lcp_ruby/views/products.yml\nview_group:\n  model: product\n  primary: products\n  views:\n    - presenter: products\n      label: \"Table\"\n      icon: grid\n    - presenter: products_tiles\n      label: \"Tiles\"\n      icon: grid-2x2\n```",
    demo_path: "/showcase/showcase-fields",
    demo_hint: "Use the view switcher in the toolbar to toggle between **Table View**, **Card View**, and **Tiles**. Notice how the URL changes to the tiles presenter's slug.",
    status: "stable"
  },
  {
    name: "Tiles with Predefined Filters",
    category: "tiles",
    description: "Predefined filters work the same way in tiles as in table layout. Filter buttons appear in the toolbar and filter the card grid.\n\nFilters are inherited from the parent presenter when using `inherits:`.",
    config_example: "```ruby\nsearch do\n  filter :all, label: \"All\", default: true\n  filter :published, label: \"Published\", scope: :published\n  filter :drafts, label: \"Drafts\", scope: :drafts\nend\n```",
    demo_path: "/showcase/articles-tiles",
    demo_hint: "Click the **Published** and **Drafts** filter buttons above the tiles. The card grid updates to show only matching articles.",
    status: "stable"
  }
]

features.each { |attrs| FeatureModel.create!(attrs) }
puts "  Created #{FeatureModel.count} feature catalog entries"

# Phase: Userstamps Showcase
UserstampsModel = LcpRuby.registry.model_for("showcase_userstamps")

# Simulate different users creating/updating documents
admin_user = if LcpRuby.configuration.authentication == :built_in
  LcpRuby::User.find_by(email: "admin@example.com")
end

LcpRuby::Current.user = admin_user

[
  { title: "Architecture Decision Record: Microservices", content: "After evaluating monolith vs microservices, we decided to adopt a modular monolith.", status: "published", priority: "high" },
  { title: "API Versioning Strategy", content: "Use URL path versioning (v1, v2) for public APIs and header versioning for internal.", status: "published", priority: "normal" },
  { title: "Database Migration Guidelines", content: "All migrations must be reversible. No data migrations in schema migrations.", status: "review", priority: "high" },
  { title: "Frontend Component Library", content: "Evaluate Radix UI, shadcn/ui, and Headless UI for the design system.", status: "draft", priority: "normal" },
  { title: "Deployment Runbook: Production", content: "Step-by-step guide for production deployments including rollback procedures.", status: "published", priority: "high" },
  { title: "Code Review Checklist", content: "Security, performance, testing, documentation, and naming conventions.", status: "review", priority: "normal" },
  { title: "Incident Response Plan", content: "Escalation paths, communication templates, and post-mortem process.", status: "draft", priority: "low" },
  { title: "Technical Debt Register", content: "Tracked items: legacy auth module, N+1 in reports, missing indexes.", status: "archived", priority: "low" }
].each { |attrs| UserstampsModel.create!(attrs) }

LcpRuby::Current.user = nil

puts "  Created #{UserstampsModel.count} tracked documents (userstamps showcase)"

# Phase: Soft Delete Showcase
# Phase: Aggregates
AggProjectModel = LcpRuby.registry.model_for("showcase_aggregate")
AggTaskModel = LcpRuby.registry.model_for("showcase_aggregate_item")

agg_projects = [
  { name: "Platform Redesign", description: "Complete UI/UX overhaul with new design system", status: "active", budget: 150_000 },
  { name: "Mobile App v2", description: "Native mobile app rewrite in Swift/Kotlin", status: "active", budget: 200_000 },
  { name: "Data Pipeline", description: "Real-time data ingestion and processing pipeline", status: "planning", budget: 80_000 },
  { name: "API Gateway", description: "Centralized API gateway with rate limiting and auth", status: "completed", budget: 60_000 },
  { name: "Legacy Migration", description: "Migrate legacy PHP codebase to Rails", status: "archived", budget: 120_000 }
].map { |attrs| AggProjectModel.create!(attrs) }

# Tasks for Platform Redesign (project 0) — 8 tasks, 3 done, 3 assignees
[
  { title: "Design system tokens", status: "done", hours: 40, cost: 4000, priority_score: 9, assignee: "Alice", due_date: "2025-01-15" },
  { title: "Component library", status: "done", hours: 80, cost: 8000, priority_score: 9, assignee: "Alice", due_date: "2025-02-01" },
  { title: "Navigation redesign", status: "done", hours: 24, cost: 2400, priority_score: 7, assignee: "Bob", due_date: "2025-02-15" },
  { title: "Dashboard layout", status: "in_progress", hours: 32, cost: 3200, priority_score: 8, assignee: "Bob", due_date: "2025-03-01" },
  { title: "Form components", status: "in_progress", hours: 48, cost: 4800, priority_score: 6, assignee: "Carol", due_date: "2025-03-15" },
  { title: "Accessibility audit", status: "todo", hours: 16, cost: 1600, priority_score: 5, assignee: "Alice", due_date: "2025-04-01" },
  { title: "Performance testing", status: "todo", hours: 20, cost: 2000, priority_score: 4, assignee: "Bob", due_date: "2025-04-15" },
  { title: "Documentation", status: "todo", hours: 12, cost: 1200, priority_score: 3, assignee: "Carol", due_date: "2025-05-01" }
].each { |attrs| AggTaskModel.create!(attrs.merge(showcase_aggregate_id: agg_projects[0].id)) }

# Tasks for Mobile App v2 (project 1) — 6 tasks, 1 done, 2 assignees
[
  { title: "App architecture", status: "done", hours: 24, cost: 3600, priority_score: 10, assignee: "Dan", due_date: "2025-01-20" },
  { title: "Auth module", status: "in_progress", hours: 40, cost: 6000, priority_score: 8, assignee: "Eve", due_date: "2025-02-10" },
  { title: "Offline sync", status: "in_progress", hours: 60, cost: 9000, priority_score: 7, assignee: "Dan", due_date: "2025-03-01" },
  { title: "Push notifications", status: "todo", hours: 20, cost: 3000, priority_score: 5, assignee: "Eve", due_date: "2025-03-20" },
  { title: "App store submission", status: "todo", hours: 8, cost: 1200, priority_score: 3, assignee: "Dan", due_date: "2025-04-15" },
  { title: "Beta testing", status: "todo", hours: 16, cost: 2400, priority_score: 4, assignee: "Eve", due_date: "2025-04-01" }
].each { |attrs| AggTaskModel.create!(attrs.merge(showcase_aggregate_id: agg_projects[1].id)) }

# Tasks for Data Pipeline (project 2) — 4 tasks, 0 done, 2 assignees
[
  { title: "Schema design", status: "todo", hours: 16, cost: 2400, priority_score: 8, assignee: "Frank", due_date: "2025-03-01" },
  { title: "Kafka setup", status: "todo", hours: 24, cost: 3600, priority_score: 7, assignee: "Grace", due_date: "2025-03-15" },
  { title: "Stream processors", status: "todo", hours: 40, cost: 6000, priority_score: 6, assignee: "Frank", due_date: "2025-04-01" },
  { title: "Monitoring dashboard", status: "todo", hours: 12, cost: 1800, priority_score: 4, assignee: "Grace", due_date: "2025-04-15" }
].each { |attrs| AggTaskModel.create!(attrs.merge(showcase_aggregate_id: agg_projects[2].id)) }

# Tasks for API Gateway (project 3) — 5 tasks, all done, 1 assignee
[
  { title: "Gateway framework", status: "done", hours: 32, cost: 3200, priority_score: 9, assignee: "Hank", due_date: "2024-10-01" },
  { title: "Rate limiter", status: "done", hours: 16, cost: 1600, priority_score: 8, assignee: "Hank", due_date: "2024-10-15" },
  { title: "Auth middleware", status: "done", hours: 24, cost: 2400, priority_score: 8, assignee: "Hank", due_date: "2024-11-01" },
  { title: "Load testing", status: "done", hours: 12, cost: 1200, priority_score: 5, assignee: "Hank", due_date: "2024-11-15" },
  { title: "Production deploy", status: "done", hours: 8, cost: 800, priority_score: 7, assignee: "Hank", due_date: "2024-12-01" }
].each { |attrs| AggTaskModel.create!(attrs.merge(showcase_aggregate_id: agg_projects[3].id)) }

# Tasks for Legacy Migration (project 4) — 3 tasks, 2 done, 2 assignees
[
  { title: "Code audit", status: "done", hours: 40, cost: 4000, priority_score: 7, assignee: "Ivy", due_date: "2024-06-01" },
  { title: "Data migration scripts", status: "done", hours: 60, cost: 6000, priority_score: 8, assignee: "Jack", due_date: "2024-07-15" },
  { title: "Final cutover", status: "cancelled", hours: 16, cost: 1600, priority_score: 9, assignee: "Ivy", due_date: "2024-08-01" }
].each { |attrs| AggTaskModel.create!(attrs.merge(showcase_aggregate_id: agg_projects[4].id)) }

puts "  Created #{AggProjectModel.count} aggregate projects with #{AggTaskModel.count} tasks"

SoftDeleteModel = LcpRuby.registry.model_for("showcase_soft_delete")
SoftDeleteItemModel = LcpRuby.registry.model_for("showcase_soft_delete_item")

LcpRuby::Current.user = admin_user

docs = [
  { title: "Q1 Planning Document", content: "Strategic objectives and OKRs for Q1. Focus areas: platform stability, developer experience, onboarding.", status: "active", priority: "high" },
  { title: "Release Notes v2.4", content: "New features: soft delete, userstamps, cascade discard. Bug fixes: permission cache, scope builder.", status: "active", priority: "normal" },
  { title: "Security Audit Findings", content: "Penetration test results and remediation plan. All critical findings addressed.", status: "active", priority: "high" },
  { title: "Legacy API Migration Plan", content: "Timeline for deprecating v1 endpoints and migrating consumers to v2.", status: "draft", priority: "normal" },
  { title: "Team Retrospective Notes", content: "What went well: deployment automation. What to improve: test coverage for edge cases.", status: "draft", priority: "low" },
  { title: "Outdated Design Spec", content: "Initial wireframes for the dashboard. Superseded by the revised spec.", status: "archived", priority: "low" }
].map { |attrs| SoftDeleteModel.create!(attrs) }

# Add child items to some documents
items_data = {
  0 => [
    { name: "Define OKRs", notes: "Align with company goals" },
    { name: "Assign team leads", notes: "One lead per initiative" },
    { name: "Set milestone dates", notes: "Monthly checkpoints" }
  ],
  1 => [
    { name: "Write changelog", notes: "User-facing summary" },
    { name: "Update docs", notes: "Reference guides and examples" }
  ],
  2 => [
    { name: "Fix XSS in search", notes: "Input sanitization added" },
    { name: "Patch SQL injection", notes: "Parameterized queries" },
    { name: "Enable CSP headers", notes: "Report-only mode first" },
    { name: "Rotate API keys", notes: "All environments" }
  ],
  3 => [
    { name: "Inventory v1 consumers", notes: "Check analytics for active users" },
    { name: "Build compatibility layer", notes: "Translate v1 requests to v2" }
  ]
}

items_data.each do |doc_index, items|
  items.each do |item_attrs|
    SoftDeleteItemModel.create!(item_attrs.merge(showcase_soft_delete_id: docs[doc_index].id))
  end
end

# Discard 2 documents to pre-populate the archive
docs[4].discard!  # Team Retrospective Notes
docs[5].discard!  # Outdated Design Spec

LcpRuby::Current.user = nil

puts "  Created #{SoftDeleteModel.kept.count} active + #{SoftDeleteModel.discarded.count} archived soft delete documents with #{SoftDeleteItemModel.count} items"

# Phase 14: Row Styling (item_classes) Demo
ItemClassModel = LcpRuby.registry.model_for("showcase_item_class")

item_class_records = [
  # USE CASE 1: cancelled + eq → muted + strikethrough
  { name: "Cancelled project", status: "cancelled", priority: "low", score: 30, amount: 500.00, code: "PROJ-001", email: "alice@example.com", notes: "Was deprioritized.", due_date: 2.months.ago.to_date },

  # USE CASE 2: completed + eq → success (green)
  { name: "Completed delivery", status: "completed", priority: "medium", score: 85, amount: 2500.00, code: "DEL-042", email: "bob@example.com", notes: "Shipped on time.", due_date: 1.week.ago.to_date },

  # USE CASE 3: critical priority + eq → danger (red)
  { name: "Server outage fix", status: "active", priority: "critical", score: 95, amount: 0.00, code: "INC-911", email: "ops@example.com", notes: "P1 incident.", due_date: Date.current },

  # USE CASE 4: on_hold + eq → warning (yellow)
  { name: "Pending approval", status: "on_hold", priority: "medium", score: 60, amount: 1200.00, code: "REQ-007", email: nil, notes: "Waiting for budget sign-off.", due_date: 1.month.from_now.to_date },

  # USE CASE 5: high priority + eq → bold
  { name: "Urgent feature request", status: "active", priority: "high", score: 75, amount: 8000.00, code: "FEAT-100", email: "pm@example.com", notes: "Board-level priority.", due_date: 2.weeks.from_now.to_date },

  # USE CASE 6: score > 90 → info (blue) — also critical → danger (accumulation demo)
  { name: "Top performer record", status: "active", priority: "medium", score: 98, amount: 15000.00, code: "PERF-001", email: "star@example.com", notes: "Exceeded all KPIs.", due_date: 3.months.from_now.to_date },

  # USE CASE 7: score < 20 → custom class (lcp-item-low-score)
  { name: "Underperforming task", status: "draft", priority: "low", score: 12, amount: 100.00, code: "TASK-999", email: nil, notes: nil, due_date: nil },

  # USE CASE 8: blank notes → custom class (lcp-item-missing-notes)
  { name: "No documentation yet", status: "active", priority: "medium", score: 50, amount: 300.00, code: "DOC-000", email: "writer@example.com", notes: nil, due_date: 1.month.from_now.to_date },

  # USE CASE 9: code matches ^TEMP → custom class (lcp-item-temp-code)
  { name: "Temporary prototype", status: "draft", priority: "low", score: 40, amount: 0.00, code: "TEMP-alpha", email: nil, notes: "Will be replaced.", due_date: nil },

  # USE CASE 10: overdue (service condition) → custom class (lcp-item-overdue)
  { name: "Overdue report", status: "active", priority: "high", score: 55, amount: 750.00, code: "RPT-003", email: "analyst@example.com", notes: "Deadline was last week.", due_date: 10.days.ago.to_date },

  # ACCUMULATION: cancelled + low score + blank notes → 3 rules match
  { name: "Abandoned experiment", status: "cancelled", priority: "low", score: 5, amount: 0.00, code: "EXP-404", email: nil, notes: nil, due_date: 6.months.ago.to_date },

  # ACCUMULATION: completed + high score → success + info
  { name: "Award-winning campaign", status: "completed", priority: "high", score: 99, amount: 50000.00, code: "MKT-001", email: "cmo@example.com", notes: "Won industry award.", due_date: 1.month.ago.to_date },

  # NO MATCH: plain draft, medium priority, no special conditions
  { name: "Regular draft item", status: "draft", priority: "medium", score: 50, amount: 200.00, code: "DRAFT-001", email: "user@example.com", notes: "Nothing special here.", due_date: 2.months.from_now.to_date },

  # ACCUMULATION: on_hold + TEMP code + blank notes + overdue
  { name: "Stalled temp project", status: "on_hold", priority: "medium", score: 45, amount: 0.00, code: "TEMP-stalled", email: nil, notes: nil, due_date: 3.weeks.ago.to_date }
]

item_class_records.each { |attrs| ItemClassModel.create!(attrs) }
puts "  Created #{ItemClassModel.count} item_classes demo records"

# Phase 15: Advanced Conditions Demo
ConditionCategoryModel = LcpRuby.registry.model_for("showcase_condition_category")
ConditionModel = LcpRuby.registry.model_for("showcase_condition")
ConditionTaskModel = LcpRuby.registry.model_for("showcase_condition_task")
ConditionThresholdModel = LcpRuby.registry.model_for("showcase_condition_threshold")

# Categories (for dot-path condition demos)
cat_finance = ConditionCategoryModel.create!(name: "Finance", industry: "finance", country_code: "CZ", verified: true)
cat_tech = ConditionCategoryModel.create!(name: "Technology", industry: "technology", country_code: "US", verified: true)
cat_unverified = ConditionCategoryModel.create!(name: "New Vendor", industry: "retail", country_code: "DE", verified: false)
cat_healthcare = ConditionCategoryModel.create!(name: "Healthcare", industry: "healthcare", country_code: "UK", verified: true)

# Thresholds (for lookup value reference demos)
ConditionThresholdModel.create!(key: "high_amount", threshold: 10000, label: "High Amount Threshold")
ConditionThresholdModel.create!(key: "critical_amount", threshold: 40000, label: "Critical Amount Threshold")
ConditionThresholdModel.create!(key: "min_budget", threshold: 3000, label: "Minimum Budget")

conditions = [
  # 1. COMPOUND (all): active + overdue → danger row
  { title: "Overdue budget review", status: "active", priority: "high", amount: 5000, budget_limit: 10000,
    author_id: 1, due_date: 2.weeks.ago.to_date, code: "FIN-001", description: "Quarterly review is past due.",
    showcase_condition_category_id: cat_finance.id },

  # 2. COMPOUND (any): draft → info row
  { title: "Draft proposal", status: "draft", priority: "medium", amount: 2000, budget_limit: 10000,
    author_id: 1, due_date: 1.month.from_now.to_date, code: "PROP-001", description: "Initial proposal.",
    showcase_condition_category_id: cat_tech.id },

  # 3. COMPOUND (any): review → info row
  { title: "Architecture review", status: "review", priority: "high", amount: 8000, budget_limit: 15000,
    author_id: 2, due_date: 1.week.from_now.to_date, code: "ARCH-010", description: "Waiting for peer review.",
    showcase_condition_category_id: cat_tech.id },

  # 4. NOT: closed → muted + strikethrough
  { title: "Closed procurement", status: "closed", priority: "low", amount: 3000, budget_limit: 5000,
    author_id: 1, due_date: 3.months.ago.to_date, code: "PROC-099", description: "Completed and archived.",
    showcase_condition_category_id: cat_finance.id },

  # 5. DOT-PATH: unverified category → warning row
  { title: "New vendor onboarding", status: "active", priority: "medium", amount: 1500, budget_limit: 5000,
    author_id: 1, due_date: 2.weeks.from_now.to_date, code: "VEND-003", description: "Vendor not yet verified.",
    showcase_condition_category_id: cat_unverified.id },

  # 6. FIELD_REF: amount > budget_limit → bold row
  { title: "Over-budget project", status: "active", priority: "critical", amount: 25000, budget_limit: 15000,
    author_id: 2, due_date: 1.month.from_now.to_date, code: "PROJ-777", description: "Spending exceeds budget limit.",
    showcase_condition_category_id: cat_tech.id },

  # 7. STARTS_WITH: code starts with URGENT
  { title: "Urgent compliance fix", status: "active", priority: "critical", amount: 12000, budget_limit: 20000,
    author_id: 1, due_date: 3.days.from_now.to_date, code: "URGENT-SEC-01", description: "Security compliance issue.",
    showcase_condition_category_id: cat_healthcare.id },

  # 8. CONTAINS: code contains "temp" (case-insensitive)
  { title: "Temporary workaround", status: "draft", priority: "low", amount: 500, budget_limit: 5000,
    author_id: 1, due_date: nil, code: "fix-temp-patch", description: "Short-term fix, needs permanent solution.",
    showcase_condition_category_id: cat_tech.id },

  # 9. High-value closed: triggers compound record_rule (deny update/destroy)
  { title: "Big closed deal", status: "closed", priority: "high", amount: 50000, budget_limit: 30000,
    author_id: 2, due_date: 2.months.ago.to_date, code: "DEAL-100", description: "High-value closed contract.",
    showcase_condition_category_id: cat_finance.id },

  # 10. Approved record (collection condition demo target)
  { title: "Approved initiative", status: "approved", priority: "medium", amount: 7500, budget_limit: 10000,
    author_id: 1, due_date: 2.months.from_now.to_date, code: "INIT-042", description: "Approved after task reviews.",
    showcase_condition_category_id: cat_healthcare.id },

  # 11. Review with tasks (collection condition: has approved task → success)
  { title: "Pending approval with tasks", status: "review", priority: "high", amount: 9000, budget_limit: 12000,
    author_id: 1, due_date: 3.weeks.from_now.to_date, code: "REV-005", description: "Has tasks for review.",
    showcase_condition_category_id: cat_finance.id },

  # 12. ACCUMULATION: draft + contains "temp" + overdue
  { title: "Stale temp draft", status: "draft", priority: "low", amount: 100, budget_limit: 5000,
    author_id: 1, due_date: 1.month.ago.to_date, code: "TEMP-old-draft", description: "Draft with temp code, past due.",
    showcase_condition_category_id: cat_unverified.id },

  # 13. Plain record — no rules match
  { title: "Normal active project", status: "active", priority: "medium", amount: 4000, budget_limit: 10000,
    author_id: 1, due_date: 3.months.from_now.to_date, code: "PROJ-STD-01", description: "Regular project, no special conditions.",
    showcase_condition_category_id: cat_tech.id },

  # 14. DATE reference demo: future due date, active
  { title: "Upcoming deadline", status: "active", priority: "high", amount: 6000, budget_limit: 10000,
    author_id: 2, due_date: 2.days.from_now.to_date, code: "DEAD-001", description: "Due date is in the future — no overdue highlight.",
    showcase_condition_category_id: cat_finance.id },

  # 15. LOOKUP: amount (15000) exceeds high_amount threshold (10000) → highlighted row
  { title: "Above lookup threshold", status: "active", priority: "medium", amount: 15000, budget_limit: 20000,
    author_id: 1, due_date: 1.month.from_now.to_date, code: "LOOK-001", description: "Amount exceeds the 'high_amount' threshold from showcase_condition_threshold table (lookup value reference).",
    showcase_condition_category_id: cat_finance.id },

  # 16. LOOKUP: amount (8000) below high_amount threshold (10000) → no highlight
  { title: "Below lookup threshold", status: "active", priority: "low", amount: 8000, budget_limit: 20000,
    author_id: 1, due_date: 2.months.from_now.to_date, code: "LOOK-002", description: "Amount is below the lookup threshold — no highlight.",
    showcase_condition_category_id: cat_tech.id }
]

condition_records = conditions.map { |attrs| ConditionModel.create!(attrs) }

# Tasks for collection condition demos
# Record 11 ("Pending approval with tasks") — has approved task → success row
ConditionTaskModel.create!(title: "Technical review", status: "approved", reviewer_name: "Alice", showcase_condition_id: condition_records[10].id)
ConditionTaskModel.create!(title: "Budget review", status: "pending", reviewer_name: "Bob", showcase_condition_id: condition_records[10].id)

# Record 10 ("Approved initiative") — all tasks approved
ConditionTaskModel.create!(title: "Compliance check", status: "approved", reviewer_name: "Carol", showcase_condition_id: condition_records[9].id)
ConditionTaskModel.create!(title: "Legal review", status: "approved", reviewer_name: "Dave", showcase_condition_id: condition_records[9].id)

# Record 3 ("Architecture review") — has tasks but none approved yet
ConditionTaskModel.create!(title: "Code review", status: "pending", reviewer_name: "Eve", showcase_condition_id: condition_records[2].id)
ConditionTaskModel.create!(title: "Security audit", status: "rejected", reviewer_name: "Frank", showcase_condition_id: condition_records[2].id)

# Record 6 ("Over-budget project") — mixed tasks
ConditionTaskModel.create!(title: "Vendor sign-off", status: "approved", reviewer_name: "Grace", showcase_condition_id: condition_records[5].id)
ConditionTaskModel.create!(title: "Finance approval", status: "rejected", reviewer_name: "Hank", showcase_condition_id: condition_records[5].id)

puts "  Created #{ConditionCategoryModel.count} condition categories, #{ConditionThresholdModel.count} condition thresholds, #{ConditionModel.count} condition records, #{ConditionTaskModel.count} condition tasks"

puts "Seeding complete!"
