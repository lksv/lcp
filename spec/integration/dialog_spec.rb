require "spec_helper"
require "support/integration_helper"

RSpec.describe "Dialog Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("dialog")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("dialog")
  end

  before(:each) do
    load_integration_metadata!("dialog")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("contact").delete_all
  end

  let(:contact_model) { LcpRuby.registry.model_for("contact") }

  describe "Dialog via routable page (ResourcesController)" do
    describe "GET /:slug/new?_dialog=1" do
      it "returns dialog HTML (not full page)" do
        get "/contacts/new", params: { _dialog: "1" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("first_name")
        expect(response.body).not_to include("<!DOCTYPE html>")
      end
    end

    describe "POST /:slug?_dialog=1 with valid data" do
      it "returns success response" do
        post "/contacts", params: {
          _dialog: "1",
          record: { first_name: "Alice", last_name: "Smith", email: "alice@example.com" }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-lcp-dialog-action")
        expect(contact_model.count).to eq(1)
        expect(contact_model.last.first_name).to eq("Alice")
      end
    end

    describe "POST /:slug?_dialog=1 with invalid data" do
      it "returns form with errors" do
        post "/contacts", params: {
          _dialog: "1",
          record: { first_name: "", last_name: "Smith" }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("error")
        expect(contact_model.count).to eq(0)
      end
    end

    describe "GET /:slug/:id/edit?_dialog=1 (record: current)" do
      it "renders edit form in dialog" do
        contact = contact_model.create!(first_name: "Bob", last_name: "Jones")

        get "/contacts/#{contact.id}/edit", params: { _dialog: "1" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("Bob")
      end
    end

    describe "PATCH /:slug/:id?_dialog=1 with valid data" do
      it "updates record and returns success" do
        contact = contact_model.create!(first_name: "Bob", last_name: "Jones")

        patch "/contacts/#{contact.id}", params: {
          _dialog: "1",
          record: { first_name: "Robert" }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-lcp-dialog-action")
        expect(contact.reload.first_name).to eq("Robert")
      end
    end
  end

  describe "Dialog via slugless route (DialogsController)" do
    describe "GET /lcp_dialog/:page_name/new" do
      it "renders dialog form" do
        get "/lcp_dialog/contact_quick_form/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("first_name")
      end
    end

    describe "POST /lcp_dialog/:page_name" do
      it "creates record and returns success" do
        post "/lcp_dialog/contact_quick_form", params: {
          record: { first_name: "Charlie", last_name: "Brown" }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-lcp-dialog-action")
        expect(contact_model.count).to eq(1)
      end
    end

    describe "GET /lcp_dialog/:page_name/:id/edit" do
      it "renders edit dialog for existing record" do
        contact = contact_model.create!(first_name: "Dana", last_name: "White")

        get "/lcp_dialog/contact_quick_form/#{contact.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("Dana")
      end
    end

    describe "PATCH /lcp_dialog/:page_name/:id" do
      it "updates record via dialog" do
        contact = contact_model.create!(first_name: "Dana", last_name: "White")

        patch "/lcp_dialog/contact_quick_form/#{contact.id}", params: {
          record: { first_name: "Dana Updated" }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-lcp-dialog-action")
        expect(contact.reload.first_name).to eq("Dana Updated")
      end
    end
  end

  describe "Virtual model dialog" do
    describe "GET /lcp_dialog/:page_name/new (virtual model)" do
      it "renders dialog form for virtual model" do
        get "/lcp_dialog/bulk_status_change_dialog/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("new_status")
      end
    end

    describe "POST /lcp_dialog/:page_name (virtual model, valid)" do
      it "validates and returns success" do
        post "/lcp_dialog/bulk_status_change_dialog", params: {
          record: { new_status: "closed", comment: "Done" }
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-lcp-dialog-action")
      end
    end

    describe "POST /lcp_dialog/:page_name (virtual model, invalid)" do
      it "returns form with validation errors" do
        post "/lcp_dialog/bulk_status_change_dialog", params: {
          record: { new_status: "", comment: "Missing status" }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("lcp-dialog-header")
        expect(response.body).to include("error")
      end
    end
  end

  describe "Dialog action buttons" do
    it "renders record:current dialog action on show page" do
      contact = contact_model.create!(first_name: "Frank", last_name: "Test")

      get "/contacts/#{contact.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Quick Edit")
      expect(response.body).to include("lcpOpenDialog")
    end

    it "renders dialog action with correct edit URL for record:current" do
      contact = contact_model.create!(first_name: "Grace", last_name: "Hopper")

      get "/contacts/#{contact.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/lcp_dialog/contact_quick_form/#{contact.id}/edit")
    end

    it "renders dialog action on index rows" do
      contact_model.create!(first_name: "Heidi", last_name: "Test")

      get "/contacts"

      expect(response).to have_http_status(:ok)
      # Single actions (including dialog type) render per-row
      expect(response.body).to include("Quick Edit")
      expect(response.body).to include("lcpOpenDialog")
    end
  end

  describe "Page-based confirmation dialogs (confirm: { page: ... })" do
    it "renders action button with data-lcp-confirm-page attribute" do
      contact = contact_model.create!(first_name: "Alice", last_name: "Test")

      get "/contacts/#{contact.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Delete with Reason")
      expect(response.body).to include('data-lcp-confirm-page="delete_reason_dialog"')
      expect(response.body).to include("data-lcp-confirm-page-url")
      expect(response.body).to include("data-lcp-confirm-page-size")
      expect(response.body).to include("data-lcp-confirm-action-method")
    end

    it "renders confirm page action button on index rows" do
      contact_model.create!(first_name: "Bob", last_name: "Test")

      get "/contacts"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Delete with Reason")
      expect(response.body).to include('data-lcp-confirm-page="delete_reason_dialog"')
    end

    it "serves the confirmation dialog form via DialogsController" do
      get "/lcp_dialog/delete_reason_dialog/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-dialog-header")
      expect(response.body).to include("reason")
      expect(response.body).to include("notify")
    end

    it "validates confirmation dialog form and returns success on valid data" do
      post "/lcp_dialog/delete_reason_dialog", params: {
        record: { reason: "No longer needed", notify: "true" }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-dialog-action")
    end

    it "validates confirmation dialog form and returns errors on invalid data" do
      post "/lcp_dialog/delete_reason_dialog", params: {
        record: { reason: "", notify: "false" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("lcp-dialog-header")
      expect(response.body).to include("error")
    end
  end

  describe "Styled confirmation rendering" do
    it "passes through styled confirmation hash to resolve_confirm" do
      # Unit-level test: styled confirmation is tested in action_set_dialog_spec.rb
      # Here we verify the destroy button uses confirm (data-turbo-confirm for built-in default)
      contact = contact_model.create!(first_name: "Eve", last_name: "Test")

      get "/contacts/#{contact.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Delete")
      expect(response.body).to include("turbo-confirm")
    end
  end
end
