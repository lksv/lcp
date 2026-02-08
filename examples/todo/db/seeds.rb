# Wait for metadata to load and tables to be created
LcpRuby::Engine.load_metadata!

TodoList = LcpRuby.registry.model_for("todo_list")
TodoItem = LcpRuby.registry.model_for("todo_item")

# Create sample todo lists
groceries = TodoList.create!(title: "Groceries", description: "Weekly grocery shopping list")
work = TodoList.create!(title: "Work Tasks", description: "Important work items to complete")
home = TodoList.create!(title: "Home Improvement", description: "House projects and repairs")

# Create sample todo items
TodoItem.create!(title: "Buy milk", todo_list: groceries, completed: false, due_date: Date.today + 1)
TodoItem.create!(title: "Buy bread", todo_list: groceries, completed: true)
TodoItem.create!(title: "Buy eggs", todo_list: groceries, completed: false, due_date: Date.today + 2)

TodoItem.create!(title: "Finish quarterly report", todo_list: work, completed: false, due_date: Date.today + 7)
TodoItem.create!(title: "Review pull requests", todo_list: work, completed: true)
TodoItem.create!(title: "Update documentation", todo_list: work, completed: false, due_date: Date.today + 3)

TodoItem.create!(title: "Fix kitchen faucet", todo_list: home, completed: false, due_date: Date.today + 14)
TodoItem.create!(title: "Paint bedroom", todo_list: home, completed: false, due_date: Date.today + 30)

puts "Seeded #{TodoList.count} todo lists and #{TodoItem.count} todo items."
