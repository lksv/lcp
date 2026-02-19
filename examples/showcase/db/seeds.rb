puts "Seeding showcase data..."

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
    metadata: { category: "marketing", tags: ["launch", "q1"] }.to_json,
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
    metadata: { countries: 20, languages: ["en", "de", "fr", "es", "ja"] }.to_json,
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
    metadata: { compliance: "SOC2", systems: ["api", "web", "mobile"] }.to_json,
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
  { name: "Large Values", code: "large-vals", status: "active", amount: 99999999.99, max_value: 9999, min_value: 1, email: "large@example.com", website: "http://large.example.com" },
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
  { title: "Getting Started with Ruby on Rails", body: "A comprehensive guide to building your first Rails application.", status: "published", category: frontend, author: authors[0], tags: [0, 1, 13], comments: [["Great article!", "Reader1"], ["Very helpful", "Reader2"]] },
  { title: "Advanced React Patterns", body: "Exploring compound components, render props, and hooks.", status: "published", category: frontend, author: authors[1], tags: [2, 4, 14], comments: [["Love the hooks examples", "DevFan"]] },
  { title: "Building REST APIs with Rails", body: "Best practices for designing RESTful APIs.", status: "published", category: backend, author: authors[0], tags: [0, 1, 14], comments: [["What about GraphQL?", "APIUser"], ["Solid patterns", "BackendDev"], ["More examples please", "Newbie"]] },
  { title: "Docker for Development", body: "Setting up Docker for local development environments.", status: "published", category: backend, author: authors[4], tags: [7, 9], comments: [] },
  { title: "Mobile-First Design Principles", body: "Why mobile-first approach matters for modern applications.", status: "published", category: mobile, author: authors[2], tags: [14], comments: [["Responsive > Mobile-first", "WebDev"]] },
  { title: "TypeScript Migration Guide", body: "Step by step guide to migrating JavaScript to TypeScript.", status: "draft", category: frontend, author: authors[1], tags: [2, 3], comments: [] },
  { title: "AWS Lambda Best Practices", body: "Optimizing serverless functions for production.", status: "published", category: backend, author: authors[4], tags: [8, 9, 11], comments: [["Cold starts are still an issue", "CloudUser"]] },
  { title: "Vue 3 Composition API", body: "Understanding the new composition API in Vue 3.", status: "published", category: frontend, author: authors[3], tags: [2, 5], comments: [["Finally!", "VueFan"], ["Great comparison with Options API", "Dev123"]] },
  { title: "Security Best Practices for Web Apps", body: "OWASP top 10 and how to protect your application.", status: "draft", category: web, author: authors[4], tags: [12, 14], comments: [] },
  { title: "Python for Data Science", body: "Introduction to pandas, numpy, and matplotlib.", status: "published", category: science, author: authors[3], tags: [6, 13], comments: [["Can you cover scikit-learn?", "DataNerd"]] },
  { title: "Startup Metrics That Matter", body: "Key performance indicators for early-stage startups.", status: "published", category: startup, author: authors[2], tags: [14], comments: [] },
  { title: "Enterprise Architecture Patterns", body: "Scaling applications for enterprise use.", status: "draft", category: enterprise, author: authors[0], tags: [14, 11], comments: [] },
  { title: "Testing Rails Applications", body: "RSpec, Capybara, and factory_bot patterns.", status: "published", category: backend, author: authors[0], tags: [0, 1, 10], comments: [["What about minitest?", "Tester"], ["Factory bot is essential", "QAEngineer"]] },
  { title: "Performance Optimization in React", body: "Memoization, code splitting, and lazy loading.", status: "published", category: frontend, author: authors[1], tags: [2, 4, 11], comments: [["useMemo vs useCallback?", "ReactDev"]] },
  { title: "DevOps Culture and Practices", body: "Building a DevOps culture in your organization.", status: "archived", category: tech, author: authors[4], tags: [7, 8, 9], comments: [] },
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
  { name: "Premium Advanced", form_type: "advanced", priority: 90, satisfaction: 5, is_premium: true, reason: "Enterprise tier", advanced_field_1: "Enterprise", config_data: { feature_flags: ["beta", "api_v2"] }.to_json },
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
  { name: "Teamwork", category: "soft" },
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
  EmpModel.create!(name: "Jack Brown", email: "jack@example.com", role: "developer", status: "archived", department_id: devops.id),
]
# Set mentors
employees[1].update!(mentor_id: employees[0].id)
employees[3].update!(mentor_id: employees[1].id)
employees[7].update!(mentor_id: employees[2].id)
puts "  Created #{employees.size} employees"

# Employee skills
[[0, [0, 6, 7, 8, 9]], [1, [1, 3, 12, 9]], [2, [0, 1, 13, 11]], [3, [1, 3, 9]], [4, [12, 6, 14]], [5, [7, 8, 6, 9]], [6, [4, 5, 0]], [7, [0, 13, 11]], [8, [0, 2, 13]], [9, [12, 6]]].each do |emp_idx, skill_idxs|
  skill_idxs.each { |si| EmpSkillModel.create!(employee_id: employees[emp_idx].id, skill_id: skills[si].id) }
end
puts "  Created #{EmpSkillModel.count} employee-skill links"

# Projects
[
  { name: "Website Redesign", status: "active", department_id: fe.id, lead_id: employees[1].id },
  { name: "API v3", status: "active", department_id: be.id, lead_id: employees[2].id },
  { name: "Cloud Migration", status: "active", department_id: devops.id, lead_id: employees[6].id },
  { name: "Brand Refresh", status: "completed", department_id: design.id, lead_id: employees[4].id },
  { name: "Internal Tools", status: "active", department_id: eng.id, lead_id: employees[0].id },
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
  { title: "Confidential Report", status: "open", owner_id: 1, priority: "high", confidential: true, internal_notes: "Top secret information.", public_notes: "Classified." },
].each { |attrs| PermModel.create!(attrs) }
puts "  Created #{PermModel.count} showcase_permission records"

# Phase 8: Extensibility
ExtModel = LcpRuby.registry.model_for("showcase_extensibility")

[
  { name: "US Dollar Account", currency: "USD", amount: 10000.00 },
  { name: "Euro Account", currency: "EUR", amount: 8500.50 },
  { name: "British Pound Reserve", currency: "GBP", amount: 25000.00 },
  { name: "Japanese Yen Fund", currency: "JPY", amount: 1500000.00 },
  { name: "No Currency Set", currency: nil, amount: 500.00 },
].each { |attrs| ExtModel.create!(attrs) }
puts "  Created #{ExtModel.count} showcase_extensibility records"

puts "Seeding complete!"
