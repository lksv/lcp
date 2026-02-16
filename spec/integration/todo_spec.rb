require "spec_helper"
require "support/integration_helper"

RSpec.describe "TODO App Integration", type: :request do
  # Create tables once for the suite
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("todo")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("todo")
  end

  # spec_helper resets LcpRuby state before each test, so reload metadata each time.
  # Tables already exist so ensure_table! is a no-op on schema.
  before(:each) do
    load_integration_metadata!("todo")
    stub_current_user(role: "admin")
    # Clear records between tests
    LcpRuby.registry.model_for("todo_item").delete_all
    LcpRuby.registry.model_for("todo_list").delete_all
  end

  let(:todo_list_model) { LcpRuby.registry.model_for("todo_list") }
  let(:todo_item_model) { LcpRuby.registry.model_for("todo_item") }

  describe "Todo Lists CRUD" do
    describe "GET /admin/lists (index)" do
      it "returns 200 and renders the list" do
        todo_list_model.create!(title: "Groceries", description: "Weekly shopping")
        todo_list_model.create!(title: "Work Tasks", description: "Important deadlines")

        get "/admin/lists"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Groceries")
        expect(response.body).to include("Work Tasks")
        expect(response.body).to include("Todo Lists")
      end

      it "returns empty table when no records" do
        get "/admin/lists"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Todo Lists")
      end
    end

    describe "GET /admin/lists/:id (show)" do
      it "returns 200 and shows the record" do
        list = todo_list_model.create!(title: "Groceries", description: "Weekly shopping")

        get "/admin/lists/#{list.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Groceries")
        expect(response.body).to include("Weekly shopping")
      end
    end

    describe "GET /admin/lists/new" do
      it "returns 200 and renders the form" do
        get "/admin/lists/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("New")
        expect(response.body).to include("Title")
      end
    end

    describe "POST /admin/lists (create)" do
      it "creates a new list and redirects" do
        expect {
          post "/admin/lists", params: { record: { title: "New List", description: "A new list" } }
        }.to change { todo_list_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).to include("New List")
      end

      it "returns validation error when title is blank" do
        post "/admin/lists", params: { record: { title: "", description: "No title" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("error")
      end
    end

    describe "PATCH /admin/lists/:id (update)" do
      it "updates the record and redirects" do
        list = todo_list_model.create!(title: "Old Title", description: "Old desc")

        patch "/admin/lists/#{list.id}", params: { record: { title: "Updated Title" } }

        expect(response).to have_http_status(:redirect)
        expect(list.reload.title).to eq("Updated Title")
      end
    end

    describe "DELETE /admin/lists/:id (destroy)" do
      it "deletes the record and redirects" do
        list = todo_list_model.create!(title: "To Delete")

        expect {
          delete "/admin/lists/#{list.id}"
        }.to change { todo_list_model.count }.by(-1)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "Todo Items CRUD" do
    let!(:list) { todo_list_model.create!(title: "Test List") }

    describe "GET /admin/items (index)" do
      it "returns 200" do
        todo_item_model.create!(title: "Buy milk", todo_list_id: list.id)

        get "/admin/items"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Buy milk")
      end
    end

    describe "POST /admin/items (create)" do
      it "creates item with belongs_to association" do
        expect {
          post "/admin/items", params: { record: { title: "New Item", todo_list_id: list.id } }
        }.to change { todo_item_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
        item = todo_item_model.last
        expect(item.title).to eq("New Item")
        expect(item.todo_list_id).to eq(list.id)
      end

      it "returns validation error when title is blank" do
        post "/admin/items", params: { record: { title: "", todo_list_id: list.id } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "GET /admin/items/:id (show)" do
      it "shows item details" do
        item = todo_item_model.create!(title: "Buy milk", todo_list_id: list.id, completed: false)

        get "/admin/items/#{item.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Buy milk")
      end
    end

    describe "PATCH /admin/items/:id (update)" do
      it "updates the item" do
        item = todo_item_model.create!(title: "Old", todo_list_id: list.id)

        patch "/admin/items/#{item.id}", params: { record: { title: "Updated", completed: true } }

        expect(response).to have_http_status(:redirect)
        item.reload
        expect(item.title).to eq("Updated")
      end
    end

    describe "DELETE /admin/items/:id (destroy)" do
      it "deletes the item" do
        item = todo_item_model.create!(title: "To Delete", todo_list_id: list.id)

        expect {
          delete "/admin/items/#{item.id}"
        }.to change { todo_item_model.count }.by(-1)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "Search" do
    it "filters results by search query" do
      todo_list_model.create!(title: "Groceries", description: "food shopping")
      todo_list_model.create!(title: "Work Tasks", description: "office stuff")

      get "/admin/lists", params: { q: "Groceries" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Groceries")
      expect(response.body).not_to include("Work Tasks")
    end
  end

  describe "Association select rendering" do
    let!(:list) { todo_list_model.create!(title: "My List") }

    it "renders a <select> for todo_list_id on new item form" do
      get "/admin/items/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<select")
      expect(response.body).to include("My List")
      expect(response.body).to include("-- Select --")
    end

    it "renders a <select> for todo_list_id on edit item form" do
      item = todo_item_model.create!(title: "Test", todo_list_id: list.id)

      get "/admin/items/#{item.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<select")
      expect(response.body).to include("My List")
    end
  end

  describe "Edit button visibility" do
    let!(:list) { todo_list_model.create!(title: "Test List") }

    it "shows Edit link on index page" do
      get "/admin/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link on show page" do
      get "/admin/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link for items on index page" do
      item = todo_item_model.create!(title: "Buy milk", todo_list_id: list.id)

      get "/admin/items"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link for items on show page" do
      item = todo_item_model.create!(title: "Buy milk", todo_list_id: list.id)

      get "/admin/items/#{item.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end
  end

  describe "Confirm dialog on delete" do
    it "includes turbo-confirm data attribute on delete button" do
      list = todo_list_model.create!(title: "Delete Me")

      get "/admin/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-confirm")
      expect(response.body).to include("Are you sure?")
    end

    it "includes confirm dialog script in layout" do
      get "/admin/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turboConfirm")
      expect(response.body).to include("confirm(confirmMsg)")
    end
  end

  describe "Nested forms" do
    it "renders nested fields section on new list form" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-nested-section")
      expect(response.body).to include("Add Item")
    end

    it "creates list with nested items" do
      expect {
        post "/admin/lists", params: {
          record: {
            title: "My List",
            description: "List with items",
            todo_items_attributes: {
              "0" => { title: "Item 1", completed: false },
              "1" => { title: "Item 2", completed: true }
            }
          }
        }
      }.to change { todo_list_model.count }.by(1)
        .and change { todo_item_model.count }.by(2)

      expect(response).to have_http_status(:redirect)
      list = todo_list_model.last
      expect(list.todo_items.count).to eq(2)
      expect(list.todo_items.map(&:title)).to contain_exactly("Item 1", "Item 2")
    end

    it "renders nested items on edit form" do
      list = todo_list_model.create!(title: "Edit List")
      todo_item_model.create!(title: "Existing Item", todo_list_id: list.id)

      get "/admin/lists/#{list.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Existing Item")
      expect(response.body).to include("lcp-nested-row")
    end

    it "updates list adding a new nested item" do
      list = todo_list_model.create!(title: "Update List")
      item = todo_item_model.create!(title: "Old Item", todo_list_id: list.id)

      expect {
        patch "/admin/lists/#{list.id}", params: {
          record: {
            title: "Updated List",
            todo_items_attributes: {
              "0" => { id: item.id, title: "Old Item Updated" },
              "1" => { title: "New Item" }
            }
          }
        }
      }.to change { todo_item_model.count }.by(1)

      expect(response).to have_http_status(:redirect)
      expect(item.reload.title).to eq("Old Item Updated")
    end

    it "updates list removing a nested item" do
      list = todo_list_model.create!(title: "Remove List")
      item = todo_item_model.create!(title: "Delete Me", todo_list_id: list.id)

      expect {
        patch "/admin/lists/#{list.id}", params: {
          record: {
            title: "Remove List",
            todo_items_attributes: {
              "0" => { id: item.id, _destroy: true }
            }
          }
        }
      }.to change { todo_item_model.count }.by(-1)
    end
  end

  describe "Empty state" do
    it "shows empty message when no records" do
      get "/admin/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-empty-state")
      expect(response.body).to include("No lists yet.")
    end
  end

  describe "Row click" do
    it "renders row-clickable class on table rows" do
      todo_list_model.create!(title: "Clickable")

      get "/admin/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-row-clickable")
    end
  end

  describe "Display helpers" do
    it "renders show page with association list" do
      list = todo_list_model.create!(title: "With Items")
      todo_item_model.create!(title: "Sub Item", todo_list_id: list.id)

      get "/admin/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sub Item")
      expect(response.body).to include("Items")
    end

    it "renders heading display type on show page" do
      list = todo_list_model.create!(title: "Bold Title")

      get "/admin/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<strong>")
      expect(response.body).to include("Bold Title")
    end
  end

  describe "Nested form template" do
    it "renders hidden template for JS cloning" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-nested-template")
      expect(response.body).to include("NEW_RECORD")
    end

    it "renders nested column count" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      # columns: 3 in the fixture
      expect(response.body).to include("repeat(3, 1fr)")
    end

    it "builds minimum required nested records on new form (min: 1)" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-nested-section")
      # min: 1 should pre-build one nested row
      expect(response.body).to include("lcp-nested-row")
    end
  end

  describe "Dynamic defaults" do
    it "applies current_date default on new form" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      # start_date should be pre-filled with today's date
      expect(response.body).to include(Date.today.to_s)
    end

    it "does not overwrite existing value on edit form" do
      list = todo_list_model.create!(title: "Test", start_date: Date.new(2025, 1, 15))

      get "/admin/lists/#{list.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2025-01-15")
    end
  end

  describe "Form field features" do
    it "renders hint text below input" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-field-hint")
      expect(response.body).to include("Give your list a descriptive name")
    end

    it "renders col_span on form fields" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("grid-column: span 2")
    end

    it "renders divider with label" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-divider")
      expect(response.body).to include("Additional Info")
    end

    it "hides visible_when field on new form (persisted? is false)" do
      get "/admin/lists/new"

      expect(response).to have_http_status(:ok)
      # description field has visible_when: "persisted?" — should not render on new form
      expect(response.body).not_to include("Description")
    end

    it "shows visible_when field on edit form (persisted? is true)" do
      list = todo_list_model.create!(title: "Test")

      get "/admin/lists/#{list.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Description")
    end
  end

  describe "Nested permits (build_nested_permits)" do
    it "permits nested attributes based on model association" do
      expect {
        post "/admin/lists", params: {
          record: {
            title: "Permit Test",
            todo_items_attributes: {
              "0" => { title: "Item 1", completed: false, due_date: "2025-06-01" }
            }
          }
        }
      }.to change { todo_list_model.count }.by(1)
        .and change { todo_item_model.count }.by(1)

      item = todo_item_model.last
      expect(item.title).to eq("Item 1")
      expect(item.due_date).to eq(Date.new(2025, 6, 1))
    end

    it "permits _destroy flag when allow_destroy is true" do
      list = todo_list_model.create!(title: "Destroy Test")
      item = todo_item_model.create!(title: "Remove Me", todo_list_id: list.id)

      expect {
        patch "/admin/lists/#{list.id}", params: {
          record: {
            title: "Destroy Test",
            todo_items_attributes: {
              "0" => { id: item.id, _destroy: true }
            }
          }
        }
      }.to change { todo_item_model.count }.by(-1)
    end
  end
end
