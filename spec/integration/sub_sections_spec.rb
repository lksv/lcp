require "spec_helper"
require "support/integration_helper"

RSpec.describe "Sub-sections in Nested Rows", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("sub_sections_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("sub_sections_test")
  end

  before(:each) do
    load_integration_metadata!("sub_sections_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("member").delete_all
  end

  let(:member_model) { LcpRuby.registry.model_for("member") }

  describe "form rendering with sub-sections" do
    it "renders sub-section fieldsets on new form" do
      get "/members/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Addresses")
      expect(response.body).to include("Add Address")
      expect(response.body).to include("lcp-nested-sub-section")
    end

    it "renders sub-section titles" do
      get "/members/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Location")
      expect(response.body).to include("Additional")
    end

    it "renders collapsible sub-section with correct classes" do
      get "/members/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-collapsible")
      expect(response.body).to include("lcp-collapse-toggle")
    end

    it "renders collapsed sub-section with hidden content" do
      get "/members/new"

      expect(response).to have_http_status(:ok)
      # The "Additional" section is collapsed by default
      expect(response.body).to include("lcp-collapsed")
    end

    it "renders fields from both sub-sections" do
      get "/members/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Street")
      expect(response.body).to include("City")
      expect(response.body).to include("Zip")
      expect(response.body).to include("Notes")
      expect(response.body).to include("Is primary")
    end

    it "renders existing items on edit form" do
      member = member_model.create!(
        name: "Alice",
        addresses: [
          { "street" => "123 Main St", "city" => "Springfield", "zip" => "62701" }
        ]
      )

      get "/members/#{member.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("123 Main St")
      expect(response.body).to include("Springfield")
    end

    it "renders template row with sub-sections" do
      get "/members/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-nested-template")
      expect(response.body).to include("NEW_RECORD")
    end
  end

  describe "CRUD with sub-sections" do
    it "creates a member with addresses from sub-section fields" do
      expect {
        post "/members", params: {
          record: {
            name: "Alice",
            addresses: {
              "0" => {
                street: "123 Main St",
                city: "Springfield",
                zip: "62701",
                country: "US",
                notes: "Home address",
                is_primary: "1"
              }
            }
          }
        }
      }.to change { member_model.count }.by(1)

      expect(response).to have_http_status(:redirect)
      member = member_model.last
      expect(member.addresses).to be_an(Array)
      expect(member.addresses.size).to eq(1)
      expect(member.addresses[0]["street"]).to eq("123 Main St")
      expect(member.addresses[0]["city"]).to eq("Springfield")
      expect(member.addresses[0]["notes"]).to eq("Home address")
    end

    it "validates items with target_model rules across sub-sections" do
      post "/members", params: {
        record: {
          name: "Bob",
          addresses: {
            "0" => {
              street: "",
              city: "",
              zip: "12345"
            }
          }
        }
      }

      # street and city have presence validations
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates a member with sub-section fields" do
      member = member_model.create!(
        name: "Alice",
        addresses: [ { "street" => "Old St", "city" => "Old City" } ]
      )

      patch "/members/#{member.id}", params: {
        record: {
          name: "Alice",
          addresses: {
            "0" => { street: "New Street", city: "New City", zip: "99999" }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      member.reload
      expect(member.addresses[0]["street"]).to eq("New Street")
      expect(member.addresses[0]["zip"]).to eq("99999")
    end

    it "whitelists only target_model field keys from sub-sections" do
      post "/members", params: {
        record: {
          name: "Charlie",
          addresses: {
            "0" => { street: "123 St", city: "Town", evil_field: "hacked" }
          }
        }
      }

      expect(response).to have_http_status(:redirect)
      member = member_model.last
      expect(member.addresses[0].keys).not_to include("evil_field")
    end
  end
end
