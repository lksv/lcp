# HR Management System — Seed Data
# Generates ~500 employees with all related data using Faker
#
# Run: bundle exec rails db:seed

require "faker"

Faker::Config.locale = "en"

# Load metadata and create tables
LcpRuby::Engine.load_metadata!

# Resolve model classes from registry
OrganizationUnit = LcpRuby.registry.model_for("organization_unit")
Position         = LcpRuby.registry.model_for("position")
Employee         = LcpRuby.registry.model_for("employee")
LeaveType        = LcpRuby.registry.model_for("leave_type")
LeaveRequest     = LcpRuby.registry.model_for("leave_request")
LeaveBalance     = LcpRuby.registry.model_for("leave_balance")
PerformanceReview = LcpRuby.registry.model_for("performance_review")
Goal             = LcpRuby.registry.model_for("goal")
Skill            = LcpRuby.registry.model_for("skill")
EmployeeSkill    = LcpRuby.registry.model_for("employee_skill")
Asset            = LcpRuby.registry.model_for("asset")
AssetAssignment  = LcpRuby.registry.model_for("asset_assignment")
Document         = LcpRuby.registry.model_for("document")
TrainingCourse   = LcpRuby.registry.model_for("training_course")
TrainingEnrollment = LcpRuby.registry.model_for("training_enrollment")
JobPosting       = LcpRuby.registry.model_for("job_posting")
Candidate        = LcpRuby.registry.model_for("candidate")
Interview        = LcpRuby.registry.model_for("interview")
ExpenseClaim     = LcpRuby.registry.model_for("expense_claim")
Announcement     = LcpRuby.registry.model_for("announcement")
Group            = LcpRuby.registry.model_for("group")
GroupMembership  = LcpRuby.registry.model_for("group_membership")

puts "Seeding HR Management System..."

# ============================================================================
# 1. ORGANIZATION UNITS (39 total: 4 BUs + 10 Divisions + 25 Teams)
# ============================================================================

puts "  Creating organization units..."

org_units = {}

# Business Units (depth 1)
bus = {
  "TECH" => { name: "Technology", code: "TECH", budget: 5_000_000 },
  "COMM" => { name: "Commercial", code: "COMM", budget: 3_000_000 },
  "OPS"  => { name: "Operations", code: "OPS", budget: 2_000_000 },
  "EXEC" => { name: "Executive Office", code: "EXEC", budget: 1_000_000 }
}

bus.each do |key, data|
  org_units[key] = OrganizationUnit.create!(data.merge(active: true))
end

# Divisions (depth 2)
divisions = {
  "ENG"    => { name: "Engineering", code: "ENG", parent: "TECH", budget: 2_500_000 },
  "PROD"   => { name: "Product", code: "PROD", parent: "TECH", budget: 1_200_000 },
  "ITOPS"  => { name: "IT Operations", code: "ITOPS", parent: "TECH", budget: 800_000 },
  "SALES"  => { name: "Sales", code: "SALES", parent: "COMM", budget: 1_500_000 },
  "MKT"    => { name: "Marketing", code: "MKT", parent: "COMM", budget: 800_000 },
  "CS"     => { name: "Customer Success", code: "CS", parent: "COMM", budget: 500_000 },
  "FIN"    => { name: "Finance", code: "FIN", parent: "OPS", budget: 600_000 },
  "HR"     => { name: "Human Resources", code: "HR", parent: "OPS", budget: 500_000 },
  "LEGAL"  => { name: "Legal & Compliance", code: "LEGAL", parent: "OPS", budget: 400_000 },
  "LEAD"   => { name: "Leadership", code: "LEAD", parent: "EXEC", budget: 500_000 }
}

divisions.each do |key, data|
  parent = org_units[data[:parent]]
  org_units[key] = OrganizationUnit.create!(
    name: data[:name], code: data[:code], budget: data[:budget],
    active: true, parent_id: parent.id
  )
end

# Teams (depth 3)
teams = {
  "BE"      => { name: "Backend Team", code: "ENG-BE", parent: "ENG", budget: 600_000 },
  "FE"      => { name: "Frontend Team", code: "ENG-FE", parent: "ENG", budget: 500_000 },
  "MOB"     => { name: "Mobile Team", code: "ENG-MOB", parent: "ENG", budget: 400_000 },
  "PLAT"    => { name: "Platform Team", code: "ENG-PLAT", parent: "ENG", budget: 500_000 },
  "QA"      => { name: "QA Team", code: "ENG-QA", parent: "ENG", budget: 300_000 },
  "DESIGN"  => { name: "Product Design Team", code: "PROD-DES", parent: "PROD", budget: 400_000 },
  "PM"      => { name: "Product Management Team", code: "PROD-PM", parent: "PROD", budget: 350_000 },
  "INFRA"   => { name: "Infrastructure Team", code: "ITOPS-INF", parent: "ITOPS", budget: 400_000 },
  "SEC"     => { name: "Security Team", code: "ITOPS-SEC", parent: "ITOPS", budget: 300_000 },
  "ENT"     => { name: "Enterprise Sales Team", code: "SALES-ENT", parent: "SALES", budget: 500_000 },
  "SMB"     => { name: "SMB Sales Team", code: "SALES-SMB", parent: "SALES", budget: 400_000 },
  "SOPS"    => { name: "Sales Operations Team", code: "SALES-OPS", parent: "SALES", budget: 200_000 },
  "BRAND"   => { name: "Brand Team", code: "MKT-BRD", parent: "MKT", budget: 250_000 },
  "GROWTH"  => { name: "Growth Team", code: "MKT-GRW", parent: "MKT", budget: 300_000 },
  "CONTENT" => { name: "Content Team", code: "MKT-CNT", parent: "MKT", budget: 200_000 },
  "ONBOARD" => { name: "Onboarding Team", code: "CS-ONB", parent: "CS", budget: 200_000 },
  "SUPPORT" => { name: "Support Team", code: "CS-SUP", parent: "CS", budget: 250_000 },
  "ACCT"    => { name: "Accounting Team", code: "FIN-ACCT", parent: "FIN", budget: 250_000 },
  "FPA"     => { name: "FP&A Team", code: "FIN-FPA", parent: "FIN", budget: 200_000 },
  "TA"      => { name: "Talent Acquisition Team", code: "HR-TA", parent: "HR", budget: 200_000 },
  "PEOPOPS" => { name: "People Operations Team", code: "HR-POP", parent: "HR", budget: 150_000 },
  "LD"      => { name: "Learning & Development Team", code: "HR-LD", parent: "HR", budget: 150_000 },
  "LEGALTEAM" => { name: "Legal Team", code: "LEGAL-T", parent: "LEGAL", budget: 300_000 },
  "CSUITE"  => { name: "C-Suite Team", code: "EXEC-CS", parent: "LEAD", budget: 400_000 },
  "DATAENG" => { name: "Data Engineering Team", code: "ENG-DATA", parent: "ENG", budget: 450_000 }
}

teams.each do |key, data|
  parent = org_units[data[:parent]]
  org_units[key] = OrganizationUnit.create!(
    name: data[:name], code: data[:code], budget: data[:budget],
    active: true, parent_id: parent.id
  )
end

puts "    Created #{OrganizationUnit.count} organization units"

# ============================================================================
# 2. POSITIONS (30 in a hierarchy)
# ============================================================================

puts "  Creating positions..."

positions = {}

# Level 1: C-Suite
positions["CEO"]  = Position.create!(title: "Chief Executive Officer", code: "C-CEO", level: 1, min_salary: 300_000, max_salary: 500_000, active: true)
positions["CTO"]  = Position.create!(title: "Chief Technology Officer", code: "C-CTO", level: 1, min_salary: 250_000, max_salary: 450_000, active: true, parent_id: positions["CEO"].id)
positions["CFO"]  = Position.create!(title: "Chief Financial Officer", code: "C-CFO", level: 1, min_salary: 250_000, max_salary: 400_000, active: true, parent_id: positions["CEO"].id)
positions["CHRO"] = Position.create!(title: "Chief Human Resources Officer", code: "C-CHRO", level: 1, min_salary: 200_000, max_salary: 350_000, active: true, parent_id: positions["CEO"].id)
positions["CCO"]  = Position.create!(title: "Chief Commercial Officer", code: "C-CCO", level: 1, min_salary: 230_000, max_salary: 400_000, active: true, parent_id: positions["CEO"].id)

# Level 2: VPs
positions["VP_ENG"]   = Position.create!(title: "VP of Engineering", code: "VP-ENG", level: 2, min_salary: 180_000, max_salary: 300_000, active: true, parent_id: positions["CTO"].id)
positions["VP_PROD"]  = Position.create!(title: "VP of Product", code: "VP-PROD", level: 2, min_salary: 170_000, max_salary: 280_000, active: true, parent_id: positions["CTO"].id)
positions["VP_SALES"] = Position.create!(title: "VP of Sales", code: "VP-SALES", level: 2, min_salary: 160_000, max_salary: 280_000, active: true, parent_id: positions["CCO"].id)
positions["VP_MKT"]   = Position.create!(title: "VP of Marketing", code: "VP-MKT", level: 2, min_salary: 150_000, max_salary: 260_000, active: true, parent_id: positions["CCO"].id)

# Level 3: Directors
positions["DIR_ENG"]  = Position.create!(title: "Engineering Director", code: "DIR-ENG", level: 3, min_salary: 140_000, max_salary: 220_000, active: true, parent_id: positions["VP_ENG"].id)
positions["DIR_QA"]   = Position.create!(title: "QA Director", code: "DIR-QA", level: 3, min_salary: 120_000, max_salary: 190_000, active: true, parent_id: positions["VP_ENG"].id)
positions["DIR_PROD"] = Position.create!(title: "Product Director", code: "DIR-PROD", level: 3, min_salary: 130_000, max_salary: 200_000, active: true, parent_id: positions["VP_PROD"].id)
positions["DIR_SALES"] = Position.create!(title: "Sales Director", code: "DIR-SALES", level: 3, min_salary: 130_000, max_salary: 210_000, active: true, parent_id: positions["VP_SALES"].id)

# Level 4: Managers
positions["MGR_BE"]    = Position.create!(title: "Backend Engineering Manager", code: "MGR-BE", level: 4, min_salary: 100_000, max_salary: 160_000, active: true, parent_id: positions["DIR_ENG"].id)
positions["MGR_FE"]    = Position.create!(title: "Frontend Engineering Manager", code: "MGR-FE", level: 4, min_salary: 100_000, max_salary: 155_000, active: true, parent_id: positions["DIR_ENG"].id)
positions["MGR_MOB"]   = Position.create!(title: "Mobile Engineering Manager", code: "MGR-MOB", level: 4, min_salary: 100_000, max_salary: 155_000, active: true, parent_id: positions["DIR_ENG"].id)
positions["MGR_QA"]    = Position.create!(title: "QA Manager", code: "MGR-QA", level: 4, min_salary: 90_000, max_salary: 140_000, active: true, parent_id: positions["DIR_QA"].id)
positions["MGR_PM"]    = Position.create!(title: "Product Manager", code: "MGR-PM", level: 4, min_salary: 95_000, max_salary: 150_000, active: true, parent_id: positions["DIR_PROD"].id)
positions["MGR_SALES"] = Position.create!(title: "Sales Manager", code: "MGR-SALES", level: 4, min_salary: 90_000, max_salary: 150_000, active: true, parent_id: positions["DIR_SALES"].id)

# Level 5: Senior ICs
positions["SR_BE"]   = Position.create!(title: "Senior Backend Engineer", code: "SWE-SR-BE", level: 5, min_salary: 80_000, max_salary: 130_000, active: true, parent_id: positions["MGR_BE"].id)
positions["SR_FE"]   = Position.create!(title: "Senior Frontend Engineer", code: "SWE-SR-FE", level: 5, min_salary: 80_000, max_salary: 125_000, active: true, parent_id: positions["MGR_FE"].id)
positions["SR_MOB"]  = Position.create!(title: "Senior Mobile Engineer", code: "SWE-SR-MOB", level: 5, min_salary: 78_000, max_salary: 125_000, active: true, parent_id: positions["MGR_MOB"].id)
positions["SR_QA"]   = Position.create!(title: "Senior QA Engineer", code: "SWE-SR-QA", level: 5, min_salary: 70_000, max_salary: 110_000, active: true, parent_id: positions["MGR_QA"].id)

# Level 6: Mid/Junior ICs
positions["MID_BE"]  = Position.create!(title: "Backend Engineer", code: "SWE-BE", level: 6, min_salary: 55_000, max_salary: 90_000, active: true, parent_id: positions["SR_BE"].id)
positions["MID_FE"]  = Position.create!(title: "Frontend Engineer", code: "SWE-FE", level: 6, min_salary: 55_000, max_salary: 85_000, active: true, parent_id: positions["SR_FE"].id)
positions["JR_BE"]   = Position.create!(title: "Junior Backend Engineer", code: "SWE-JR-BE", level: 7, min_salary: 35_000, max_salary: 55_000, active: true, parent_id: positions["MID_BE"].id)
positions["JR_FE"]   = Position.create!(title: "Junior Frontend Engineer", code: "SWE-JR-FE", level: 7, min_salary: 35_000, max_salary: 55_000, active: true, parent_id: positions["MID_FE"].id)

# Non-engineering roles
positions["ACCTANT"] = Position.create!(title: "Accountant", code: "FIN-ACCT-P", level: 6, min_salary: 45_000, max_salary: 75_000, active: true)
positions["RECRUITER"] = Position.create!(title: "Recruiter", code: "HR-REC", level: 6, min_salary: 45_000, max_salary: 70_000, active: true)
positions["SALES_REP"] = Position.create!(title: "Sales Representative", code: "SALES-REP", level: 6, min_salary: 50_000, max_salary: 90_000, active: true, parent_id: positions["MGR_SALES"].id)

puts "    Created #{Position.count} positions"

# ============================================================================
# 3. SKILLS (60 in 3-level taxonomy)
# ============================================================================

puts "  Creating skills..."

skills = {}

# Root categories
%w[technical soft language certification].each do |cat|
  skills[cat] = Skill.create!(name: cat.titleize, category: cat)
end

# Technical sub-skills
tech_subs = {
  "programming" => [ "Ruby", "Python", "JavaScript", "TypeScript", "Go", "Java", "C#", "Rust" ],
  "devops" => [ "Docker", "Kubernetes", "AWS", "Azure", "CI/CD", "Terraform" ],
  "databases" => [ "PostgreSQL", "MySQL", "Redis", "MongoDB", "Elasticsearch" ],
  "frontend" => [ "React", "Vue.js", "Angular", "CSS/SCSS", "HTML5" ]
}

tech_subs.each do |sub_name, leaves|
  sub = Skill.create!(name: sub_name.titleize, category: "technical", parent_id: skills["technical"].id)
  skills[sub_name] = sub
  leaves.each do |leaf|
    skills[leaf.downcase.gsub(/[^a-z0-9]/, "_")] = Skill.create!(
      name: leaf, category: "technical", parent_id: sub.id
    )
  end
end

# Soft skills
%w[Leadership Communication Teamwork Problem\ Solving Time\ Management Presentation Negotiation Mentoring].each do |name|
  skills[name.downcase.gsub(" ", "_")] = Skill.create!(name: name, category: "soft", parent_id: skills["soft"].id)
end

# Languages
%w[English Czech Slovak German French Spanish Mandarin Japanese].each do |name|
  skills[name.downcase] = Skill.create!(name: name, category: "language", parent_id: skills["language"].id)
end

# Certifications
[ "AWS Solutions Architect", "PMP", "Scrum Master", "CISSP", "CPA", "ISO 27001 Auditor" ].each do |name|
  skills[name.downcase.gsub(/[^a-z0-9]/, "_")] = Skill.create!(
    name: name, category: "certification", parent_id: skills["certification"].id
  )
end

puts "    Created #{Skill.count} skills"

# ============================================================================
# 4. LEAVE TYPES (6)
# ============================================================================

puts "  Creating leave types..."

leave_types = {}
lt_data = [
  { name: "Vacation", code: "VAC", color: "#4CAF50", default_days: 25, requires_approval: true, requires_document: false },
  { name: "Sick Leave", code: "SICK", color: "#F44336", default_days: 10, requires_approval: false, requires_document: true },
  { name: "Personal Day", code: "PER", color: "#2196F3", default_days: 3, requires_approval: true, requires_document: false },
  { name: "Parental Leave", code: "PAR", color: "#9C27B0", default_days: 60, requires_approval: true, requires_document: true },
  { name: "Unpaid Leave", code: "UNP", color: "#FF9800", default_days: 0, requires_approval: true, requires_document: false },
  { name: "Work From Home", code: "WFH", color: "#607D8B", default_days: 50, requires_approval: false, requires_document: false }
]

lt_data.each do |data|
  leave_types[data[:code]] = LeaveType.create!(data.merge(active: true))
end

puts "    Created #{LeaveType.count} leave types"

# ============================================================================
# 5. TRAINING COURSES (15)
# ============================================================================

puts "  Creating training courses..."

courses = []
course_data = [
  { title: "New Employee Onboarding", category: "onboarding", format: "in_person", duration_hours: 16, max_participants: 30, instructor: "HR Team", location: "Main Office - Room 101", starts_at: 2.weeks.from_now },
  { title: "Git & Version Control", category: "technical", format: "online", duration_hours: 4, max_participants: 50, instructor: "DevOps Team", url: "https://training.example.com/git", starts_at: 1.week.from_now },
  { title: "Data Privacy & GDPR", category: "compliance", format: "online", duration_hours: 2, max_participants: 200, instructor: "Legal Department", url: "https://training.example.com/gdpr", starts_at: 3.days.from_now },
  { title: "Leadership Essentials", category: "leadership", format: "hybrid", duration_hours: 24, max_participants: 20, instructor: "Dr. Jane Miller", location: "Training Center", url: "https://training.example.com/leadership", starts_at: 1.month.from_now },
  { title: "Workplace Safety", category: "safety", format: "in_person", duration_hours: 3, max_participants: 100, instructor: "Safety Officer", location: "Main Office - Auditorium", starts_at: 2.months.from_now },
  { title: "React Advanced Patterns", category: "technical", format: "online", duration_hours: 8, max_participants: 40, instructor: "Frontend Lead", url: "https://training.example.com/react", starts_at: 3.weeks.from_now },
  { title: "SQL Performance Tuning", category: "technical", format: "online", duration_hours: 6, max_participants: 30, instructor: "DBA Team", url: "https://training.example.com/sql", starts_at: 5.weeks.from_now },
  { title: "Effective Communication", category: "leadership", format: "in_person", duration_hours: 8, max_participants: 25, instructor: "Coach Smith", location: "Training Center", starts_at: 6.weeks.from_now },
  { title: "Cloud Architecture on AWS", category: "technical", format: "hybrid", duration_hours: 16, max_participants: 25, instructor: "AWS Certified Trainer", location: "Tech Lab", url: "https://training.example.com/aws", starts_at: 2.months.from_now },
  { title: "Anti-Harassment Training", category: "compliance", format: "online", duration_hours: 1.5, max_participants: 500, instructor: "HR Department", url: "https://training.example.com/harassment", starts_at: 1.month.from_now },
  { title: "Agile & Scrum Methodology", category: "leadership", format: "in_person", duration_hours: 12, max_participants: 30, instructor: "Scrum Master", location: "Room 205", starts_at: 4.weeks.from_now },
  { title: "Docker & Containers", category: "technical", format: "online", duration_hours: 6, max_participants: 40, instructor: "Platform Team", url: "https://training.example.com/docker", starts_at: 7.weeks.from_now },
  { title: "Financial Literacy for Managers", category: "leadership", format: "hybrid", duration_hours: 4, max_participants: 30, instructor: "CFO Office", location: "Meeting Room A", url: "https://training.example.com/finance", starts_at: 8.weeks.from_now },
  { title: "Ruby on Rails Best Practices", category: "technical", format: "in_person", duration_hours: 8, max_participants: 20, instructor: "Principal Engineer", location: "Dev Lab", starts_at: 3.months.from_now },
  { title: "First Aid & CPR", category: "safety", format: "in_person", duration_hours: 8, max_participants: 20, instructor: "Red Cross Instructor", location: "Main Office - Room 102", starts_at: 10.weeks.from_now }
]

course_data.each do |data|
  data[:ends_at] = data[:starts_at] + data[:duration_hours].hours
  courses << TrainingCourse.create!(data.merge(active: true))
end

puts "    Created #{TrainingCourse.count} training courses"

# ============================================================================
# 6. EMPLOYEES (500)
# ============================================================================

puts "  Creating 500 employees..."

# Team weights for distribution
team_weights = {
  "BE" => 40, "FE" => 35, "MOB" => 20, "PLAT" => 25, "QA" => 20, "DATAENG" => 20,
  "DESIGN" => 15, "PM" => 12, "INFRA" => 15, "SEC" => 10,
  "ENT" => 25, "SMB" => 25, "SOPS" => 10,
  "BRAND" => 10, "GROWTH" => 12, "CONTENT" => 10,
  "ONBOARD" => 10, "SUPPORT" => 20,
  "ACCT" => 10, "FPA" => 8,
  "TA" => 12, "PEOPOPS" => 10, "LD" => 8,
  "LEGALTEAM" => 8, "CSUITE" => 5
}

# Position assignments per team type
team_position_map = {
  "BE" => %w[SR_BE MID_BE JR_BE MGR_BE],
  "FE" => %w[SR_FE MID_FE JR_FE MGR_FE],
  "MOB" => %w[SR_MOB MGR_MOB],
  "PLAT" => %w[SR_BE MID_BE],
  "QA" => %w[SR_QA MGR_QA],
  "DATAENG" => %w[SR_BE MID_BE],
  "DESIGN" => %w[DIR_PROD MGR_PM],
  "PM" => %w[MGR_PM DIR_PROD],
  "INFRA" => %w[SR_BE MID_BE],
  "SEC" => %w[SR_BE MID_BE],
  "ENT" => %w[SALES_REP MGR_SALES DIR_SALES],
  "SMB" => %w[SALES_REP MGR_SALES],
  "SOPS" => %w[SALES_REP],
  "BRAND" => %w[RECRUITER],
  "GROWTH" => %w[RECRUITER],
  "CONTENT" => %w[RECRUITER],
  "ONBOARD" => %w[RECRUITER],
  "SUPPORT" => %w[RECRUITER],
  "ACCT" => %w[ACCTANT],
  "FPA" => %w[ACCTANT],
  "TA" => %w[RECRUITER],
  "PEOPOPS" => %w[RECRUITER],
  "LD" => %w[RECRUITER],
  "LEGALTEAM" => %w[ACCTANT],
  "CSUITE" => %w[CEO CTO CFO CHRO CCO]
}

weighted_teams = team_weights.flat_map { |k, w| [ k ] * w }
employees = []
all_statuses = %w[active active active active active active active active on_leave terminated]
employment_types = %w[full_time full_time full_time full_time part_time contract intern]
genders = %w[male female other prefer_not_to_say]
currencies = %w[CZK CZK CZK CZK EUR USD]

500.times do |i|
  team_key = weighted_teams.sample
  team = org_units[team_key]
  pos_options = team_position_map[team_key] || [ "RECRUITER" ]
  pos_key = pos_options.sample
  position = positions[pos_key]

  status = all_statuses.sample
  hire_date = Faker::Date.between(from: 10.years.ago, to: 3.months.ago)
  termination_date = status == "terminated" ? Faker::Date.between(from: hire_date + 6.months, to: Date.current) : nil
  gender = genders.sample
  first_name = gender == "female" ? Faker::Name.female_first_name : Faker::Name.male_first_name
  last_name = Faker::Name.last_name

  salary_range = (position.min_salary.to_f..position.max_salary.to_f)
  salary = rand(salary_range).round(-2)

  emp = Employee.create!(
    first_name: first_name,
    last_name: last_name,
    personal_email: Faker::Internet.email(name: "#{first_name} #{last_name}"),
    work_email: "#{first_name.downcase}.#{last_name.downcase.gsub(/[^a-z]/, "")}#{i}@acme.com",
    phone: Faker::PhoneNumber.phone_number_with_country_code,
    date_of_birth: Faker::Date.birthday(min_age: 22, max_age: 62),
    hire_date: hire_date,
    termination_date: termination_date,
    status: status,
    employment_type: employment_types.sample,
    gender: gender,
    salary: salary,
    currency: currencies.sample,
    organization_unit_id: team.id,
    position_id: position.id,
    address: {
      street: Faker::Address.street_address,
      city: Faker::Address.city,
      zip: Faker::Address.zip_code,
      country: Faker::Address.country
    },
    emergency_contact: {
      name: Faker::Name.name,
      phone: Faker::PhoneNumber.phone_number,
      relationship: %w[Spouse Parent Sibling Friend Partner].sample
    }
  )
  employees << emp

  print "\r    Created #{employees.size}/500 employees" if (employees.size % 50).zero?
end

# Assign managers
puts "\n    Assigning managers..."
employees.group_by(&:organization_unit_id).each do |_ou_id, team_members|
  next if team_members.size <= 1
  manager = team_members.max_by { |e| e.position&.level.to_i > 0 ? -e.position.level : 0 }
  team_members.each do |emp|
    next if emp.id == manager.id
    emp.update_columns(manager_id: manager.id)
  end
end

puts "    Created #{Employee.count} employees"

# ============================================================================
# 7. LEAVE BALANCES (active employees x 6 leave types)
# ============================================================================

puts "  Creating leave balances..."

current_year = Date.current.year
active_employees = employees.select { |e| e.status != "terminated" }

active_employees.each do |emp|
  leave_types.each_value do |lt|
    used = rand(0..([ lt.default_days, 5 ].min)).to_f
    LeaveBalance.create!(
      employee_id: emp.id,
      leave_type_id: lt.id,
      year: current_year,
      total_days: lt.default_days,
      used_days: used
    )
  end
end

puts "    Created #{LeaveBalance.count} leave balances"

# ============================================================================
# 8. LEAVE REQUESTS (~800)
# ============================================================================

puts "  Creating leave requests..."

lr_statuses = %w[approved approved approved pending pending draft rejected cancelled]

# Build a lookup for remaining balance per employee+leave_type
balance_remaining = {}
LeaveBalance.where(year: current_year).find_each do |bal|
  key = "#{bal.employee_id}-#{bal.leave_type_id}"
  balance_remaining[key] = bal.total_days.to_f - bal.used_days.to_f
end

active_employees.sample(400).each do |emp|
  rand(1..4).times do
    lt = leave_types.values.sample
    bal_key = "#{emp.id}-#{lt.id}"
    remaining = balance_remaining[bal_key] || 0

    start_date = Faker::Date.between(from: 6.months.ago, to: 3.months.from_now)
    days = [ rand(1..5), remaining.floor ].min
    next if days <= 0

    status = lr_statuses.sample
    approver = status.in?(%w[approved rejected]) ? employees.sample : nil

    LeaveRequest.create!(
      employee_id: emp.id,
      leave_type_id: lt.id,
      start_date: start_date,
      end_date: start_date + days.days,
      days_count: days,
      status: status,
      reason: Faker::Lorem.sentence(word_count: rand(5..15)),
      rejection_note: status == "rejected" ? Faker::Lorem.sentence : nil,
      approved_by_id: approver&.id,
      approved_at: approver ? Faker::Time.between(from: start_date - 7.days, to: start_date) : nil
    )

    # Track consumed balance
    balance_remaining[bal_key] = remaining - days
  end
end

puts "    Created #{LeaveRequest.count} leave requests"

# ============================================================================
# 9. PERFORMANCE REVIEWS (~400)
# ============================================================================

puts "  Creating performance reviews..."

review_statuses = %w[completed completed completed acknowledged self_review manager_review draft]

active_employees.sample(350).each do |emp|
  reviewer = employees.find { |e| e.id == emp.manager_id } || employees.sample
  status = review_statuses.sample

  PerformanceReview.create!(
    employee_id: emp.id,
    reviewer_id: reviewer.id,
    review_period: %w[q1 q2 q3 q4 annual].sample,
    year: [ current_year, current_year - 1 ].sample,
    status: status,
    self_rating: status.in?(%w[completed acknowledged manager_review]) ? rand(2..5) : nil,
    manager_rating: status.in?(%w[completed acknowledged]) ? rand(2..5) : nil,
    overall_rating: status.in?(%w[completed acknowledged]) ? rand(2..5) : nil,
    self_comments: status != "draft" ? Faker::Lorem.paragraph(sentence_count: 2) : nil,
    manager_comments: status.in?(%w[completed acknowledged]) ? Faker::Lorem.paragraph(sentence_count: 2) : nil,
    goals_summary: status.in?(%w[completed acknowledged]) ? Faker::Lorem.paragraph : nil,
    strengths: status.in?(%w[completed acknowledged]) ? Faker::Lorem.paragraph : nil,
    improvements: status.in?(%w[completed acknowledged]) ? Faker::Lorem.paragraph : nil,
    completed_at: status.in?(%w[completed acknowledged]) ? Faker::Time.between(from: 6.months.ago, to: Time.current) : nil
  )
end

puts "    Created #{PerformanceReview.count} performance reviews"

# ============================================================================
# 10. GOALS (~600)
# ============================================================================

puts "  Creating goals..."

goal_statuses = %w[not_started in_progress in_progress completed completed cancelled]
goal_priorities = %w[low medium medium high critical]

active_employees.sample(400).each do |emp|
  rand(1..3).times do
    status = goal_statuses.sample
    Goal.create!(
      title: Faker::Company.catch_phrase,
      description: Faker::Lorem.paragraph(sentence_count: 2),
      employee_id: emp.id,
      status: status,
      priority: goal_priorities.sample,
      due_date: Faker::Date.between(from: Date.current, to: 6.months.from_now),
      progress: case status
                when "completed" then 100
                when "in_progress" then rand(10..90)
                when "not_started" then 0
                else rand(0..50)
                end,
      weight: rand(1..5)
    )
  end
end

puts "    Created #{Goal.count} goals"

# ============================================================================
# 11. EMPLOYEE SKILLS (~1500)
# ============================================================================

puts "  Creating employee skills..."

leaf_skills = Skill.where.not(id: skills.values_at("technical", "soft", "language", "certification").compact.map(&:id))
proficiencies = %w[beginner intermediate intermediate advanced expert]

employees.each do |emp|
  leaf_skills.sample(rand(2..5)).each do |skill|
    certified = rand < 0.2
    EmployeeSkill.create!(
      employee_id: emp.id,
      skill_id: skill.id,
      proficiency: proficiencies.sample,
      certified: certified,
      certified_at: certified ? Faker::Date.between(from: 3.years.ago, to: Date.current) : nil,
      expires_at: certified ? Faker::Date.between(from: Date.current, to: 3.years.from_now) : nil
    )
  rescue ActiveRecord::RecordInvalid
    next # Skip duplicates
  end
end

puts "    Created #{EmployeeSkill.count} employee skills"

# ============================================================================
# 12. ASSETS (250)
# ============================================================================

puts "  Creating assets..."

assets = []
asset_categories = %w[laptop laptop laptop phone phone monitor desk chair access_card other]

250.times do |i|
  category = asset_categories.sample
  tag_prefix = { "laptop" => "LAP", "phone" => "PHN", "monitor" => "MON", "desk" => "DSK",
                 "chair" => "CHR", "vehicle" => "VEH", "access_card" => "ACS", "other" => "OTH" }[category] || "OTH"

  status = %w[available available assigned assigned in_repair retired].sample

  asset = Asset.new(
    name: "#{category.titleize} ##{i + 1}",
    asset_tag: format("%s-%04d-%04d", tag_prefix, current_year, i + 1),
    category: category,
    brand: Faker::Appliance.brand,
    serial_number: Faker::Device.serial,
    purchase_date: Faker::Date.between(from: 5.years.ago, to: Date.current),
    purchase_price: rand(200..3000).round(-1),
    warranty_until: Faker::Date.between(from: Date.current, to: 3.years.from_now),
    status: status,
    notes: rand < 0.3 ? Faker::Lorem.sentence : nil
  )
  asset.product_model = Faker::Device.model_name
  asset.save!
  assets << asset
end

puts "    Created #{Asset.count} assets"

# ============================================================================
# 13. ASSET ASSIGNMENTS (~600)
# ============================================================================

puts "  Creating asset assignments..."

assigned_assets = assets.select { |a| a.status == "assigned" }
returned_conditions = %w[good good fair poor damaged]

# Assign currently assigned assets
assigned_assets.each do |asset|
  emp = active_employees.sample
  AssetAssignment.create!(
    asset_id: asset.id,
    employee_id: emp.id,
    assigned_at: Faker::Date.between(from: 2.years.ago, to: Date.current),
    condition_on_assign: %w[new good good fair].sample,
    notes: rand < 0.2 ? Faker::Lorem.sentence : nil
  )
end

# Historical (returned) assignments
200.times do
  asset = assets.sample
  emp = employees.sample
  assigned_at = Faker::Date.between(from: 4.years.ago, to: 1.year.ago)
  AssetAssignment.create!(
    asset_id: asset.id,
    employee_id: emp.id,
    assigned_at: assigned_at,
    returned_at: Faker::Date.between(from: assigned_at + 30.days, to: Date.current),
    condition_on_assign: %w[new good fair].sample,
    condition_on_return: returned_conditions.sample,
    notes: rand < 0.2 ? Faker::Lorem.sentence : nil
  )
end

puts "    Created #{AssetAssignment.count} asset assignments"

# ============================================================================
# 14. DOCUMENTS (~1000)
# ============================================================================

puts "  Creating documents..."

doc_categories = %w[contract contract certificate id_document tax_form review amendment other]

employees.sample(450).each do |emp|
  rand(1..4).times do
    Document.create!(
      title: "#{doc_categories.sample.titleize} - #{emp.first_name} #{emp.last_name}",
      category: doc_categories.sample,
      description: rand < 0.5 ? Faker::Lorem.sentence : nil,
      employee_id: emp.id,
      confidential: rand < 0.15,
      valid_from: Faker::Date.between(from: 3.years.ago, to: Date.current),
      valid_until: rand < 0.6 ? Faker::Date.between(from: Date.current, to: 3.years.from_now) : nil
    )
  end
end

puts "    Created #{Document.count} documents"

# ============================================================================
# 15. TRAINING ENROLLMENTS (~300)
# ============================================================================

puts "  Creating training enrollments..."

enrollment_statuses = %w[enrolled enrolled completed completed cancelled no_show]

active_employees.sample(200).each do |emp|
  courses.sample(rand(1..3)).each do |course|
    status = enrollment_statuses.sample
    TrainingEnrollment.create!(
      employee_id: emp.id,
      training_course_id: course.id,
      status: status,
      completed_at: status == "completed" ? Faker::Time.between(from: 6.months.ago, to: Time.current) : nil,
      score: status == "completed" ? rand(60..100) : nil,
      feedback: status == "completed" && rand < 0.5 ? Faker::Lorem.paragraph : nil
    )
  rescue ActiveRecord::RecordInvalid
    next # Skip duplicates
  end
end

puts "    Created #{TrainingEnrollment.count} training enrollments"

# ============================================================================
# 16. JOB POSTINGS (12)
# ============================================================================

puts "  Creating job postings..."

postings = []
posting_data = [
  { title: "Senior Backend Engineer", status: "open", employment_type: "full_time", remote_option: "hybrid", headcount: 3 },
  { title: "Frontend Developer", status: "open", employment_type: "full_time", remote_option: "remote", headcount: 2 },
  { title: "QA Engineer", status: "open", employment_type: "full_time", remote_option: "on_site", headcount: 1 },
  { title: "DevOps Engineer", status: "open", employment_type: "full_time", remote_option: "hybrid", headcount: 2 },
  { title: "Product Manager", status: "open", employment_type: "full_time", remote_option: "hybrid", headcount: 1 },
  { title: "Sales Representative", status: "closed", employment_type: "full_time", remote_option: "on_site", headcount: 2 },
  { title: "Marketing Specialist", status: "filled", employment_type: "full_time", remote_option: "hybrid", headcount: 1 },
  { title: "Summer Intern - Engineering", status: "open", employment_type: "intern", remote_option: "on_site", headcount: 5 },
  { title: "Legal Counsel", status: "draft", employment_type: "full_time", remote_option: "on_site", headcount: 1 },
  { title: "Data Analyst", status: "draft", employment_type: "contract", remote_option: "remote", headcount: 1 },
  { title: "Customer Support Specialist", status: "closed", employment_type: "full_time", remote_option: "on_site", headcount: 3 },
  { title: "HR Business Partner", status: "filled", employment_type: "full_time", remote_option: "hybrid", headcount: 1 }
]

posting_data.each do |data|
  team = org_units[weighted_teams.sample]
  position = Position.all.sample
  manager = active_employees.sample

  postings << JobPosting.create!(
    title: data[:title],
    description: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
    status: data[:status],
    employment_type: data[:employment_type],
    location: "Prague, Czech Republic",
    remote_option: data[:remote_option],
    salary_min: rand(40_000..80_000).round(-3),
    salary_max: rand(80_000..150_000).round(-3),
    currency: "CZK",
    headcount: data[:headcount],
    published_at: data[:status] != "draft" ? Faker::Time.between(from: 3.months.ago, to: Time.current) : nil,
    closes_at: Faker::Date.between(from: Date.current, to: 3.months.from_now),
    organization_unit_id: team.id,
    position_id: position.id,
    hiring_manager_id: manager.id
  )
end

puts "    Created #{JobPosting.count} job postings"

# ============================================================================
# 17. CANDIDATES (~80)
# ============================================================================

puts "  Creating candidates..."

candidates = []
candidate_statuses = %w[applied applied screening interviewing interviewing offer hired rejected withdrawn]
sources = %w[website referral linkedin agency job_board other]

open_postings = postings.select { |p| p.status.in?(%w[open closed filled]) }

80.times do
  posting = open_postings.sample
  status = candidate_statuses.sample
  gender = genders.sample
  first_name = gender == "female" ? Faker::Name.female_first_name : Faker::Name.male_first_name

  candidates << Candidate.create!(
    first_name: first_name,
    last_name: Faker::Name.last_name,
    email: Faker::Internet.email,
    phone: Faker::PhoneNumber.phone_number_with_country_code,
    status: status,
    source: sources.sample,
    cover_letter: rand < 0.6 ? Faker::Lorem.paragraphs(number: 2).join("\n") : nil,
    rating: status.in?(%w[interviewing offer hired]) ? rand(2..5) : nil,
    notes: rand < 0.4 ? Faker::Lorem.paragraph : nil,
    rejection_reason: status == "rejected" ? Faker::Lorem.sentence : nil,
    job_posting_id: posting.id
  )
end

puts "    Created #{Candidate.count} candidates"

# ============================================================================
# 18. INTERVIEWS (~150)
# ============================================================================

puts "  Creating interviews..."

interview_types = %w[phone_screen technical behavioral panel final]
recommendations = %w[strong_yes yes yes neutral no strong_no]

candidates.each do |candidate|
  next if candidate.status == "applied"

  rand(1..3).times do |round|
    interviewer = active_employees.sample
    completed = candidate.status.in?(%w[interviewing offer hired rejected])
    status = completed && round < 2 ? "completed" : "scheduled"

    Interview.create!(
      candidate_id: candidate.id,
      interviewer_id: interviewer.id,
      interview_type: interview_types[round] || interview_types.sample,
      scheduled_at: Faker::Time.between(from: 2.months.ago, to: 1.month.from_now),
      duration_minutes: [ 30, 45, 60, 90 ].sample,
      location: rand < 0.5 ? "Office - Meeting Room #{rand(1..10)}" : nil,
      meeting_url: rand < 0.5 ? "https://meet.example.com/#{SecureRandom.hex(4)}" : nil,
      status: status,
      rating: status == "completed" ? rand(1..5) : nil,
      feedback: status == "completed" ? Faker::Lorem.paragraph(sentence_count: 3) : nil,
      recommendation: status == "completed" ? recommendations.sample : nil,
      notes: status == "completed" ? { communication: rand(1..5), technical: rand(1..5), culture_fit: rand(1..5) } : nil
    )
  end
end

puts "    Created #{Interview.count} interviews"

# ============================================================================
# 19. EXPENSE CLAIMS (~200)
# ============================================================================

puts "  Creating expense claims..."

expense_categories = %w[travel travel meals accommodation equipment education other]
expense_statuses = %w[draft submitted submitted approved approved rejected reimbursed]

active_employees.sample(150).each do |emp|
  rand(1..3).times do
    status = expense_statuses.sample
    approver = status.in?(%w[approved rejected reimbursed]) ? active_employees.sample : nil

    ExpenseClaim.create!(
      title: "#{expense_categories.sample.titleize} - #{Faker::Lorem.words(number: 3).join(" ").titleize}",
      description: Faker::Lorem.sentence,
      amount: (rand(20..499) + rand).round(2),
      currency: "CZK",
      category: expense_categories.sample,
      status: status,
      expense_date: Faker::Date.between(from: 3.months.ago, to: Date.current),
      employee_id: emp.id,
      approved_by_id: approver&.id,
      approved_at: approver ? Faker::Time.between(from: 1.month.ago, to: Time.current) : nil,
      rejection_note: status == "rejected" ? Faker::Lorem.sentence : nil,
      items: [
        { description: Faker::Commerce.product_name, amount: rand(10..500).round(2), category: expense_categories.sample },
        { description: Faker::Commerce.product_name, amount: rand(10..300).round(2), category: expense_categories.sample }
      ]
    )
  end
end

puts "    Created #{ExpenseClaim.count} expense claims"

# ============================================================================
# 20. ANNOUNCEMENTS (20)
# ============================================================================

puts "  Creating announcements..."

20.times do |i|
  published = i < 15
  Announcement.create!(
    title: Faker::Company.catch_phrase,
    body: Faker::Lorem.paragraphs(number: rand(2..5)).join("\n\n"),
    priority: %w[normal normal normal important urgent].sample,
    published: published,
    published_at: published ? Faker::Time.between(from: 6.months.ago, to: Time.current) : nil,
    expires_at: published && rand < 0.3 ? Faker::Date.between(from: Date.current, to: 6.months.from_now) : nil,
    pinned: i < 3,
    organization_unit_id: rand < 0.3 ? org_units.values.sample.id : nil
  )
end

puts "    Created #{Announcement.count} announcements"

# ============================================================================
# 21. GROUPS (8) + MEMBERSHIPS (~120)
# ============================================================================

puts "  Creating groups and memberships..."

groups_data = [
  { name: "Safety Committee", code: "safety-committee", group_type: "committee" },
  { name: "Innovation Lab", code: "innovation-lab", group_type: "project" },
  { name: "Social Club", code: "social-club", group_type: "interest" },
  { name: "Diversity & Inclusion", code: "diversity-inclusion", group_type: "committee" },
  { name: "Tech Guild", code: "tech-guild", group_type: "cross_functional" },
  { name: "Green Initiative", code: "green-initiative", group_type: "interest" },
  { name: "Product Launch Team", code: "product-launch", group_type: "temporary" },
  { name: "Mentorship Program", code: "mentorship-program", group_type: "cross_functional" }
]

groups_data.each do |gdata|
  group = Group.create!(gdata.merge(active: true))

  active_employees.sample(rand(10..20)).each do |emp|
    GroupMembership.create!(
      group_id: group.id,
      employee_id: emp.id,
      role_in_group: %w[member member member member lead admin].sample,
      joined_at: Faker::Date.between(from: 2.years.ago, to: Date.current),
      active: true
    )
  rescue ActiveRecord::RecordInvalid
    next
  end
end

puts "    Created #{Group.count} groups with #{GroupMembership.count} memberships"

# ============================================================================
# Set org unit heads
# ============================================================================

puts "  Assigning org unit heads..."

org_units.each_value do |ou|
  head = Employee.where(organization_unit_id: ou.id).order(:hire_date).first
  ou.update_columns(head_id: head.id) if head
end

# ============================================================================
# Summary
# ============================================================================

puts "\n--- Seed Summary ---"
puts "  Organization Units:   #{OrganizationUnit.count}"
puts "  Positions:            #{Position.count}"
puts "  Employees:            #{Employee.count}"
puts "  Skills:               #{Skill.count}"
puts "  Employee Skills:      #{EmployeeSkill.count}"
puts "  Leave Types:          #{LeaveType.count}"
puts "  Leave Balances:       #{LeaveBalance.count}"
puts "  Leave Requests:       #{LeaveRequest.count}"
puts "  Performance Reviews:  #{PerformanceReview.count}"
puts "  Goals:                #{Goal.count}"
puts "  Assets:               #{Asset.count}"
puts "  Asset Assignments:    #{AssetAssignment.count}"
puts "  Documents:            #{Document.count}"
puts "  Training Courses:     #{TrainingCourse.count}"
puts "  Training Enrollments: #{TrainingEnrollment.count}"
puts "  Job Postings:         #{JobPosting.count}"
puts "  Candidates:           #{Candidate.count}"
puts "  Interviews:           #{Interview.count}"
puts "  Expense Claims:       #{ExpenseClaim.count}"
puts "  Announcements:        #{Announcement.count}"
puts "  Groups:               #{Group.count}"
puts "  Group Memberships:    #{GroupMembership.count}"
puts "\nDone! HR Management System seeded successfully."
