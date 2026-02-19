require "spec_helper"
require "support/integration_helper"

RSpec.describe "Engine Features Integration", type: :request do
  # Create tables once for the suite
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("features")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("features")
  end

  # spec_helper resets LcpRuby state before each test, so reload metadata each time.
  before(:each) do
    load_integration_metadata!("features")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("feature_record").delete_all
    LcpRuby.registry.model_for("feature_dsl").delete_all
  end

  let(:record_model) { LcpRuby.registry.model_for("feature_record") }
  let(:dsl_model) { LcpRuby.registry.model_for("feature_dsl") }

  # Helper to clear the event handler state
  def clear_event_handler!
    LcpRuby::HostEventHandlers::FeatureRecord::OnStatusChange.last_change = nil
  end

  def event_handler_last_change
    LcpRuby::HostEventHandlers::FeatureRecord::OnStatusChange.last_change
  end

  # ---------------------------------------------------------------------------
  # GAP 1: Computed fields
  # ---------------------------------------------------------------------------
  describe "Computed fields" do
    it "computes template-based computed_label on create" do
      record = record_model.create!(name: "Alpha", code: "alpha-1", amount: 10.0)

      expect(record.computed_label).to eq("Alpha (alpha-1)")
    end

    it "computes service-based computed_score on create" do
      record = record_model.create!(name: "Beta", code: "beta-1", status: "active", amount: 100.0)

      # active multiplier is 1.5
      expect(record.computed_score.to_f).to eq(150.0)
    end

    it "recomputes on save when inputs change" do
      record = record_model.create!(name: "Gamma", code: "gamma-1", status: "draft", amount: 50.0)
      # draft multiplier is 1.0
      expect(record.computed_score.to_f).to eq(50.0)

      record.update!(status: "completed", amount: 80.0)
      # completed multiplier is 2.0
      expect(record.reload.computed_score.to_f).to eq(160.0)
      expect(record.computed_label).to eq("Gamma (gamma-1)")
    end

    it "shows computed fields on show page" do
      record = record_model.create!(name: "Delta", code: "delta-1", status: "active", amount: 200.0)

      get "/features/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Delta (delta-1)")
      # computed_score = 200 * 1.5 = 300.0
      expect(response.body).to include("300")
    end

    it "applies service default for auto_date on new record" do
      # Service defaults are applied via after_initialize on new records
      new_record = record_model.new
      expect(new_record.auto_date).to eq(Date.current + 7)
    end
  end

  # ---------------------------------------------------------------------------
  # GAP 2: Business types end-to-end
  # ---------------------------------------------------------------------------
  describe "Business types end-to-end" do
    it "normalizes email on create (strip + downcase)" do
      post "/features", params: {
        record: { name: "Email Test", code: "email-test", email: "  USER@Example.COM  " }
      }

      expect(response).to have_http_status(:redirect)
      expect(record_model.last.email).to eq("user@example.com")
    end

    it "normalizes phone on create (strip + remove non-digits)" do
      post "/features", params: {
        record: { name: "Phone Test", code: "phone-test", phone: "(123) 456-7890" }
      }

      expect(response).to have_http_status(:redirect)
      stored_phone = record_model.last.phone
      # normalize_phone removes non-digit chars except +
      expect(stored_phone).to eq("1234567890")
    end

    it "normalizes url on create (adds https:// scheme)" do
      post "/features", params: {
        record: { name: "URL Test", code: "url-test", website: "example.com" }
      }

      expect(response).to have_http_status(:redirect)
      expect(record_model.last.website).to eq("https://example.com")
    end

    it "renders phone as phone_link on show page" do
      record = record_model.create!(name: "Phone Show", code: "phone-show", phone: "1234567890")

      get "/features/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("tel:")
    end

    it "renders url as url_link on show page" do
      record = record_model.create!(name: "URL Show", code: "url-show", website: "https://example.com")

      get "/features/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="_blank"')
      expect(response.body).to include("https://example.com")
    end

    it "renders email as email_link on show page" do
      record = record_model.create!(name: "Email Show", code: "email-show", email: "test@example.com")

      get "/features/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("mailto:")
      expect(response.body).to include("test@example.com")
    end
  end

  # ---------------------------------------------------------------------------
  # GAP 3: Custom action execution
  # ---------------------------------------------------------------------------
  describe "Custom action execution" do
    # Action redirect uses redirect_back, so we need a Referer header
    let(:referer_headers) { { "HTTP_REFERER" => "/features" } }

    it "executes lock action and updates status" do
      record = record_model.create!(name: "Lockable", code: "lockable", status: "active", amount: 10.0)

      post "/features/#{record.id}/actions/lock", headers: referer_headers

      expect(response).to have_http_status(:redirect)
      expect(record.reload.status).to eq("locked")
    end

    it "returns failure when record is already locked" do
      record = record_model.create!(name: "Already Locked", code: "already-locked", status: "locked")

      post "/features/#{record.id}/actions/lock", headers: referer_headers

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("already locked")
    end

    it "denies action for unauthorized role" do
      stub_current_user(role: "editor")
      record = record_model.create!(name: "No Lock", code: "no-lock", status: "active", amount: 10.0)

      post "/features/#{record.id}/actions/lock", headers: referer_headers

      # Editor is denied the lock action
      expect(response).to have_http_status(:redirect)
      expect(record.reload.status).to eq("active")
    end
  end

  # ---------------------------------------------------------------------------
  # GAP 4: Event handlers
  # ---------------------------------------------------------------------------
  describe "Event handlers" do
    before { clear_event_handler! }

    it "fires handler when status field changes on update" do
      record = record_model.create!(name: "Event Test", code: "event-test", amount: 50.0)

      patch "/features/#{record.id}", params: { record: { status: "active" } }

      expect(response).to have_http_status(:redirect)
      change = event_handler_last_change
      expect(change).not_to be_nil
      expect(change[:old_status]).to eq("draft")
      expect(change[:new_status]).to eq("active")
      expect(change[:record_name]).to eq("Event Test")
    end

    it "does not fire handler when non-status field changes" do
      record = record_model.create!(name: "No Event", code: "no-event")

      patch "/features/#{record.id}", params: { record: { description: "Updated" } }

      expect(response).to have_http_status(:redirect)
      expect(event_handler_last_change).to be_nil
    end

    it "does not fire field_change handler on create" do
      post "/features", params: {
        record: { name: "Create Event", code: "create-event", status: "active", amount: 10.0 }
      }

      expect(response).to have_http_status(:redirect)
      # field_change events only fire on update, not create
      expect(event_handler_last_change).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # GAP 5: Model DSL full stack
  # ---------------------------------------------------------------------------
  describe "Model DSL full stack" do
    it "GET /dsl-records returns 200" do
      dsl_model.create!(title: "First DSL")

      get "/dsl-records"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("First DSL")
    end

    it "POST /dsl-records creates a record" do
      expect {
        post "/dsl-records", params: { record: { title: "New DSL", body: "Some body text" } }
      }.to change { dsl_model.count }.by(1)

      expect(response).to have_http_status(:redirect)
      expect(dsl_model.last.title).to eq("New DSL")
      expect(dsl_model.last.body).to eq("Some body text")
    end

    it "GET /dsl-records/:id shows the record" do
      record = dsl_model.create!(title: "Show DSL", body: "Body text")

      get "/dsl-records/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Show DSL")
      expect(response.body).to include("Body text")
    end

    it "PATCH /dsl-records/:id updates the record" do
      record = dsl_model.create!(title: "Old DSL")

      patch "/dsl-records/#{record.id}", params: { record: { title: "Updated DSL" } }

      expect(response).to have_http_status(:redirect)
      expect(record.reload.title).to eq("Updated DSL")
    end

    it "DELETE /dsl-records/:id deletes the record" do
      record = dsl_model.create!(title: "Delete DSL")

      expect {
        delete "/dsl-records/#{record.id}"
      }.to change { dsl_model.count }.by(-1)

      expect(response).to have_http_status(:redirect)
    end

    it "validates presence on title" do
      post "/dsl-records", params: { record: { title: "", body: "No title" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "applies default value for active field" do
      post "/dsl-records", params: { record: { title: "Default Active" } }

      expect(response).to have_http_status(:redirect)
      expect(dsl_model.last.active).to eq(true)
    end
  end

  # ---------------------------------------------------------------------------
  # GAP 6: Validations in HTTP cycle
  # ---------------------------------------------------------------------------
  describe "Validations in HTTP cycle" do
    describe "format validation" do
      it "rejects invalid code format" do
        post "/features", params: {
          record: { name: "Format Fail", code: "INVALID CODE!" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "accepts valid code format" do
        expect {
          post "/features", params: {
            record: { name: "Format Pass", code: "valid-code-123" }
          }
        }.to change { record_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
      end
    end

    describe "uniqueness validation" do
      it "rejects duplicate name" do
        record_model.create!(name: "Unique Name", code: "unique-1")

        post "/features", params: {
          record: { name: "Unique Name", code: "unique-2" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "conditional presence validation" do
      it "requires amount when status is active" do
        post "/features", params: {
          record: { name: "Active No Amount", code: "active-no-amt", status: "active", amount: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "allows blank amount when status is draft" do
        expect {
          post "/features", params: {
            record: { name: "Draft No Amount", code: "draft-no-amt", status: "draft" }
          }
        }.to change { record_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
      end
    end

    describe "cross-field comparison validation" do
      it "rejects when min_value >= max_value" do
        post "/features", params: {
          record: { name: "Compare Fail", code: "compare-fail", min_value: 100, max_value: 50 }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "accepts when min_value < max_value" do
        expect {
          post "/features", params: {
            record: { name: "Compare Pass", code: "compare-pass", min_value: 10, max_value: 50 }
          }
        }.to change { record_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GAP 7: Display renderers
  # ---------------------------------------------------------------------------
  describe "Display renderers" do
    let!(:record) do
      record_model.create!(
        name: "Display Test",
        code: "display-test",
        description: "A longer description text that should be truncated at some point",
        status: "active",
        amount: 1234.50,
        email: "display@example.com",
        phone: "5551234567",
        website: "https://example.com",
        brand_color: "#ff5500",
        is_active: true,
        rating_value: 3.0,
        min_value: 10,
        max_value: 100
      )
    end

    describe "index page" do
      it "renders heading display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<strong>")
        expect(response.body).to include("Display Test")
      end

      it "renders truncate display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        # truncate with max: 30 should add a title attribute
        expect(response.body).to include("title=")
      end

      it "renders code display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-code")
        expect(response.body).to include("display-test")
      end

      it "renders badge display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("badge")
        expect(response.body).to include("active")
      end

      it "renders boolean_icon display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-bool-true")
      end

      it "renders rating display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-rating-display")
      end

      it "renders currency display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("1,234.50")
      end

      it "renders email_link display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("mailto:")
        expect(response.body).to include("display@example.com")
      end

      it "renders phone_link display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("tel:")
      end

      it "renders url_link display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('target="_blank"')
        expect(response.body).to include("https://example.com")
      end

      it "renders color_swatch display type" do
        get "/features"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-color-swatch")
        expect(response.body).to include("#ff5500")
      end

      it "renders date with custom format" do
        get "/features"

        expect(response).to have_http_status(:ok)
        # format: "%B %d, %Y" e.g. "January 01, 2026"
        expected = record.due_date.strftime("%B %d, %Y")
        expect(response.body).to include(expected)
      end

      it "renders relative_date display type for auto_date" do
        get "/features"

        expect(response).to have_http_status(:ok)
        # auto_date is 7 days from now; relative_date uses time_ago_in_words + "ago"
        expect(response.body).to include("ago")
      end

      it "renders number display type for computed_score" do
        get "/features"

        expect(response).to have_http_status(:ok)
        # computed_score = 1234.5 * 1.5 = 1851.75, number display adds delimiter
        expect(response.body).to include("1,851.75")
      end
    end

    describe "show page" do
      it "renders heading on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<strong>")
        expect(response.body).to include("Display Test")
      end

      it "renders email_link on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("mailto:")
      end

      it "renders phone_link on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("tel:")
      end

      it "renders url_link on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('target="_blank"')
      end

      it "renders color_swatch on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-color-swatch")
      end

      it "renders boolean_icon on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-bool-true")
      end

      it "renders rating on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("lcp-rating-display")
      end

      it "renders badge on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("badge")
      end

      it "renders date with custom format on show" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        expected = record.due_date.strftime("%B %d, %Y")
        expect(response.body).to include(expected)
      end

      it "renders relative_date on show for auto_date" do
        get "/features/#{record.id}"

        expect(response).to have_http_status(:ok)
        # auto_date uses relative_date display
        expect(response.body).to include("ago")
      end
    end
  end
end
