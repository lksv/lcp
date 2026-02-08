# Wait for metadata to load and tables to be created
LcpRuby::Engine.load_metadata!

Company = LcpRuby.registry.model_for("company")
Contact = LcpRuby.registry.model_for("contact")
Deal = LcpRuby.registry.model_for("deal")

# Create companies
acme = Company.create!(name: "Acme Corp", industry: "technology", website: "https://acme.example.com", phone: "+1-555-0100")
globex = Company.create!(name: "Globex Corporation", industry: "manufacturing", website: "https://globex.example.com", phone: "+1-555-0200")
initech = Company.create!(name: "Initech", industry: "technology", website: "https://initech.example.com", phone: "+1-555-0300")
wayne = Company.create!(name: "Wayne Enterprises", industry: "finance", website: "https://wayne.example.com", phone: "+1-555-0400")
stark = Company.create!(name: "Stark Industries", industry: "technology", website: "https://stark.example.com", phone: "+1-555-0500")

# Create contacts
john = Contact.create!(first_name: "John", last_name: "Smith", email: "john@acme.example.com", phone: "+1-555-0101", position: "CTO", company: acme)
jane = Contact.create!(first_name: "Jane", last_name: "Doe", email: "jane@globex.example.com", phone: "+1-555-0201", position: "VP Engineering", company: globex)
bob = Contact.create!(first_name: "Bob", last_name: "Wilson", email: "bob@initech.example.com", phone: "+1-555-0301", position: "Director of IT", company: initech)
alice = Contact.create!(first_name: "Alice", last_name: "Johnson", email: "alice@wayne.example.com", phone: "+1-555-0401", position: "CFO", company: wayne)
tony = Contact.create!(first_name: "Tony", last_name: "Martinez", email: "tony@stark.example.com", phone: "+1-555-0501", position: "CEO", company: stark)

# Create deals
Deal.create!(title: "Enterprise License - Acme", stage: "negotiation", value: 150000.00, company: acme, contact: john)
Deal.create!(title: "Consulting Package - Globex", stage: "proposal", value: 75000.00, company: globex, contact: jane)
Deal.create!(title: "SaaS Migration - Initech", stage: "qualified", value: 200000.00, company: initech, contact: bob)
Deal.create!(title: "Financial Platform - Wayne", stage: "closed_won", value: 500000.00, company: wayne, contact: alice)
Deal.create!(title: "Hardware Supply - Stark", stage: "lead", value: 50000.00, company: stark, contact: tony)
Deal.create!(title: "Support Contract - Acme", stage: "closed_lost", value: 30000.00, company: acme, contact: john)

puts "Seeded #{Company.count} companies, #{Contact.count} contacts, and #{Deal.count} deals."
