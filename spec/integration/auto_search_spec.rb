require "spec_helper"
require "support/integration_helper"

RSpec.describe "Auto-Search Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("auto_search_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("auto_search_test")
  end

  before(:each) do
    load_integration_metadata!("auto_search_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("article").delete_all
  end

  let(:article_model) { LcpRuby.registry.model_for("article") }

  describe "with auto_search enabled" do
    it "renders data attributes on the search form" do
      get "/articles-auto"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lcp-auto-search="true"')
      expect(response.body).to include('data-lcp-debounce="500"')
      expect(response.body).to include('data-lcp-min-query="3"')
    end

    it "renders the i18n placeholder" do
      get "/articles-auto"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('placeholder="Search..."')
    end

    it "renders the i18n submit button" do
      get "/articles-auto"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Search"')
    end

    it "preserves the active filter as a hidden field" do
      get "/articles-auto", params: { filter: "published" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="filter"')
      expect(response.body).to include('value="published"')
    end

    it "does not render a hidden filter field when no filter is active" do
      get "/articles-auto"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="filter" type="hidden"')
    end

    it "search still works with query param" do
      article_model.create!(title: "Rails Guide", body: "Getting started", status: "published")
      article_model.create!(title: "Ruby Basics", body: "Introduction", status: "draft")

      get "/articles-auto", params: { q: "Rails" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rails Guide")
      expect(response.body).not_to include("Ruby Basics")
    end
  end

  describe "without auto_search (default search)" do
    it "does not render auto_search data attributes" do
      get "/articles-default"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-lcp-auto-search')
    end

    it "renders default debounce and min_query data attributes" do
      get "/articles-default"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lcp-debounce="300"')
      expect(response.body).to include('data-lcp-min-query="2"')
    end

    it "renders i18n placeholder and submit" do
      get "/articles-default"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('placeholder="Search..."')
      expect(response.body).to include('value="Search"')
    end

    it "search works with query param" do
      article_model.create!(title: "Rails Guide", body: "Getting started", status: "published")
      article_model.create!(title: "Ruby Basics", body: "Introduction", status: "draft")

      get "/articles-default", params: { q: "Rails" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rails Guide")
      expect(response.body).not_to include("Ruby Basics")
    end
  end
end
