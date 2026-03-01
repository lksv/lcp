require "spec_helper"
require "support/integration_helper"

RSpec.describe "Copy URL & Copy Field Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("copy_url_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("copy_url_test")
  end

  before(:each) do
    load_integration_metadata!("copy_url_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("copy_item").delete_all
  end

  let(:model) { LcpRuby.registry.model_for("copy_item") }

  describe "Copy URL button" do
    it "renders copy URL button on show page by default" do
      record = model.create!(title: "Test Item", description: "A description")

      get "/copy-items/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-copy-url")
      expect(response.body).to include("Copy link")
      expect(response.body).to include("data-lcp-copy-url")
    end

    it "hides copy URL button when show.copy_url is false" do
      record = model.create!(title: "Test Item", description: "A description")

      get "/copy-items-no-url/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-copy-url")
      expect(response.body).not_to include("data-lcp-copy-url")
    end
  end

  describe "Copy field icon" do
    it "renders copy icon for fields with copyable: true" do
      record = model.create!(title: "Copyable Title", email: "test@example.com")

      get "/copy-items/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-copy-field")
      expect(response.body).to include('data-lcp-copy-value="Copyable Title"')
      expect(response.body).to include('data-lcp-copy-value="test@example.com"')
    end

    it "does not render copy icon for fields without copyable: true" do
      record = model.create!(title: "Test", description: "Some description")

      get "/copy-items/#{record.id}"

      expect(response).to have_http_status(:ok)
      # description field should not have copy icon
      expect(response.body).not_to include('data-lcp-copy-value="Some description"')
    end

    it "does not render copy icon when value is nil" do
      record = model.create!(title: "Test")

      get "/copy-items/#{record.id}"

      expect(response).to have_http_status(:ok)
      # email is copyable but nil, so no copy icon should appear for it
      # title is copyable and present, so it should have a copy icon
      expect(response.body).to include('data-lcp-copy-value="Test"')
      # Count the number of copy-field buttons - should be 1 (title only, not email)
      copy_field_count = response.body.scan("lcp-copy-field").count
      expect(copy_field_count).to eq(1)
    end
  end
end
