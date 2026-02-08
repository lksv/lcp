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
end
