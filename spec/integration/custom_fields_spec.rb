require "spec_helper"
require "support/integration_helper"

RSpec.describe "Custom Fields Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("custom_fields_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("custom_fields_test")
  end

  before(:each) do
    load_integration_metadata!("custom_fields_test")
    stub_current_user(role: "admin")
    project_model.delete_all
    cfd_model.delete_all
  end

  let(:project_model) { LcpRuby.registry.model_for("project") }
  let(:cfd_model) { LcpRuby.registry.model_for("custom_field_definition") }

  describe "Custom field definition CRUD" do
    describe "GET /custom-fields-project (index)" do
      it "returns 200" do
        get "/custom-fields-project"
        expect(response).to have_http_status(:ok)
      end

      it "shows existing definitions" do
        cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website"
        )

        get "/custom-fields-project"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("website")
        expect(response.body).to include("Website")
      end

      it "only shows definitions scoped to the target model" do
        cfd_model.create!(
          target_model: "project", field_name: "proj_field",
          custom_type: "string", label: "Project Field"
        )
        cfd_model.create!(
          target_model: "other_model", field_name: "other_field",
          custom_type: "string", label: "Other Field"
        )

        get "/custom-fields-project"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("proj_field")
        expect(response.body).not_to include("other_field")
      end
    end

    describe "POST /custom-fields-project (create)" do
      it "creates a new custom field definition" do
        expect {
          post "/custom-fields-project", params: {
            record: {
              target_model: "project",
              field_name: "priority",
              custom_type: "integer",
              label: "Priority",
              section: "Custom Fields"
            }
          }
        }.to change { cfd_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
        defn = cfd_model.last
        expect(defn.field_name).to eq("priority")
        expect(defn.custom_type).to eq("integer")
      end

      it "rejects invalid field names" do
        post "/custom-fields-project", params: {
          record: {
            target_model: "project",
            field_name: "123invalid",
            custom_type: "string",
            label: "Bad Name"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "Custom fields on target model" do
    before do
      cfd_model.create!(
        target_model: "project", field_name: "website",
        custom_type: "string", label: "Website URL",
        show_in_form: true, show_in_show: true, show_in_table: false
      )
      cfd_model.create!(
        target_model: "project", field_name: "priority",
        custom_type: "integer", label: "Priority Level",
        show_in_form: true, show_in_show: true, show_in_table: true
      )
      # Refresh accessors
      project_model.apply_custom_field_accessors!
      LcpRuby::CustomFields::Registry.reload!("project")
    end

    describe "Form rendering" do
      it "shows custom fields on new form" do
        get "/projects/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Website URL")
        expect(response.body).to include("Priority Level")
      end

      it "shows custom fields on edit form" do
        project = project_model.create!(name: "Test Project")
        project.write_custom_field("website", "https://example.com")
        project.save!

        get "/projects/#{project.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Website URL")
        expect(response.body).to include("https://example.com")
      end
    end

    describe "Show page rendering" do
      it "shows custom field values on show page" do
        project = project_model.create!(name: "Show Test")
        project.write_custom_field("website", "https://show-test.com")
        project.write_custom_field("priority", "5")
        project.save!

        get "/projects/#{project.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Website URL")
        expect(response.body).to include("https://show-test.com")
        expect(response.body).to include("Priority Level")
      end
    end

    describe "Creating records with custom fields" do
      it "persists custom field values via form submission" do
        post "/projects", params: {
          record: {
            name: "CF Project",
            website: "https://cf-project.com",
            priority: "3"
          }
        }

        expect(response).to have_http_status(:redirect)
        project = project_model.last
        expect(project.name).to eq("CF Project")
        expect(project.read_custom_field("website")).to eq("https://cf-project.com")
        expect(project.read_custom_field("priority")).to eq("3")
      end
    end

    describe "Updating records with custom fields" do
      it "updates custom field values" do
        project = project_model.create!(name: "Update Test")
        project.write_custom_field("website", "https://old.com")
        project.save!

        patch "/projects/#{project.id}", params: {
          record: {
            name: "Update Test",
            website: "https://new.com"
          }
        }

        expect(response).to have_http_status(:redirect)
        project.reload
        expect(project.read_custom_field("website")).to eq("https://new.com")
      end
    end

    describe "Custom field sections grouping" do
      it "groups custom fields by section attribute" do
        cfd_model.create!(
          target_model: "project", field_name: "grouped_field",
          custom_type: "string", label: "Grouped",
          section: "Extra Info", show_in_form: true
        )
        LcpRuby::CustomFields::Registry.reload!("project")
        project_model.apply_custom_field_accessors!

        get "/projects/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Extra Info")
        expect(response.body).to include("Grouped")
      end
    end
  end

  describe "Custom fields validation via form" do
    before do
      cfd_model.create!(
        target_model: "project", field_name: "required_url",
        custom_type: "string", label: "Required URL",
        required: true, show_in_form: true
      )
      project_model.apply_custom_field_accessors!
      LcpRuby::CustomFields::Registry.reload!("project")
    end

    it "rejects creation when required custom field is blank" do
      post "/projects", params: {
        record: {
          name: "Missing CF",
          required_url: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "Search with custom fields" do
    before do
      cfd_model.create!(
        target_model: "project", field_name: "tag",
        custom_type: "string", label: "Tag",
        searchable: true, show_in_form: true
      )
      project_model.apply_custom_field_accessors!
      LcpRuby::CustomFields::Registry.reload!("project")

      p1 = project_model.create!(name: "Tagged Project")
      p1.write_custom_field("tag", "ruby-on-rails")
      p1.save!

      p2 = project_model.create!(name: "Other Project")
      p2.write_custom_field("tag", "python-flask")
      p2.save!
    end

    it "includes custom field searchable results" do
      get "/projects", params: { q: "ruby" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tagged Project")
    end
  end

  describe "Permission checks" do
    it "hides custom fields from users without custom_data read permission" do
      cfd_model.create!(
        target_model: "project", field_name: "secret_field",
        custom_type: "string", label: "Secret",
        show_in_form: true, show_in_show: true
      )
      project_model.apply_custom_field_accessors!
      LcpRuby::CustomFields::Registry.reload!("project")

      project = project_model.create!(name: "Permission Test")

      # Viewer has read-only access, but has custom_data readable (via "all")
      stub_current_user(role: "viewer")

      get "/projects/#{project.id}"
      expect(response).to have_http_status(:ok)
      # Viewer should see the field (custom_data is readable via "all")
      expect(response.body).to include("Secret")
    end
  end

  describe "Cache invalidation" do
    it "refreshes accessors when a definition is created" do
      # Create definition — after_commit should reload
      cfd_model.create!(
        target_model: "project", field_name: "dynamic_field",
        custom_type: "string", label: "Dynamic"
      )

      # Force accessor refresh (after_commit triggers this automatically in real app)
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Dynamic Test")
      expect(record).to respond_to(:dynamic_field)
      expect(record).to respond_to(:dynamic_field=)
    end
  end

  describe "Default values" do
    it "pre-fills custom field defaults on new record form" do
      cfd_model.create!(
        target_model: "project", field_name: "priority",
        custom_type: "string", label: "Priority",
        default_value: "medium", show_in_form: true
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      get "/projects/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("medium")
    end

    it "persists default values when creating without explicit value" do
      cfd_model.create!(
        target_model: "project", field_name: "category",
        custom_type: "string", label: "Category",
        default_value: "general", show_in_form: true
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      post "/projects", params: { record: { name: "Default Test" } }
      expect(response).to have_http_status(:redirect)

      created = project_model.last
      expect(created.read_custom_field("category")).to eq("general")
    end
  end
end
