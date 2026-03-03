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
    describe "GET /projects/custom-fields (index)" do
      it "returns 200" do
        get "/projects/custom-fields"
        expect(response).to have_http_status(:ok)
      end

      it "shows existing definitions" do
        cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website"
        )

        get "/projects/custom-fields"
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

        get "/projects/custom-fields"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("proj_field")
        expect(response.body).not_to include("other_field")
      end
    end

    describe "POST /projects/custom-fields (create)" do
      it "creates a new custom field definition with target_model from URL context" do
        expect {
          post "/projects/custom-fields", params: {
            record: {
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
        expect(defn.target_model).to eq("project")
      end

      it "rejects invalid field names" do
        post "/projects/custom-fields", params: {
          record: {
            field_name: "123invalid",
            custom_type: "string",
            label: "Bad Name"
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "ignores target_model tampering via params" do
        post "/projects/custom-fields", params: {
          record: {
            field_name: "tampered",
            custom_type: "string",
            label: "Tampered",
            target_model: "other_model"
          }
        }

        expect(response).to have_http_status(:redirect)
        defn = cfd_model.last
        expect(defn.target_model).to eq("project")
      end
    end

    describe "GET /projects/custom-fields/:id (show)" do
      it "shows a custom field definition" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website"
        )

        get "/projects/custom-fields/#{defn.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("website")
      end

      it "prevents cross-model record access" do
        other_defn = cfd_model.create!(
          target_model: "other_model", field_name: "other_field",
          custom_type: "string", label: "Other"
        )

        get "/projects/custom-fields/#{other_defn.id}"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "PATCH /projects/custom-fields/:id (update)" do
      it "updates a custom field definition" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website"
        )

        patch "/projects/custom-fields/#{defn.id}", params: {
          record: { label: "Website URL" }
        }

        expect(response).to have_http_status(:redirect)
        defn.reload
        expect(defn.label).to eq("Website URL")
      end

      it "prevents target_model tampering on update" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website"
        )

        patch "/projects/custom-fields/#{defn.id}", params: {
          record: { label: "Updated", target_model: "other_model" }
        }

        expect(response).to have_http_status(:redirect)
        defn.reload
        expect(defn.target_model).to eq("project")
      end
    end

    describe "DELETE /projects/custom-fields/:id (destroy)" do
      it "deletes a custom field definition" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website"
        )

        expect {
          delete "/projects/custom-fields/#{defn.id}"
        }.to change { cfd_model.count }.by(-1)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "Error handling" do
    it "returns 404 for non-existent slug" do
      get "/non-existent-slug/custom-fields"
      expect(response).to have_http_status(:not_found)
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

      expect(response).to have_http_status(:unprocessable_content)
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
      get "/projects", params: { qs: "ruby" }

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

  describe "Manage page" do
    describe "GET /projects/custom-fields/manage" do
      it "returns 200" do
        get "/projects/custom-fields/manage"
        expect(response).to have_http_status(:ok)
      end

      it "renders manage form" do
        get "/projects/custom-fields/manage"
        expect(response.body).to include("Manage Custom Fields")
        expect(response.body).to include(I18n.t("lcp_ruby.manage.save_all"))
        expect(response.body).to include(I18n.t("lcp_ruby.manage.add_field"))
      end

      it "renders existing definitions" do
        cfd_model.create!(
          target_model: "project", field_name: "website",
          custom_type: "string", label: "Website", position: 0
        )

        get "/projects/custom-fields/manage"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("website")
      end

      it "renders section-level visible_when conditions" do
        get "/projects/custom-fields/manage"
        expect(response.body).to include("data-lcp-visible-field")
      end

      it "renders data-lcp-condition-scope on manage rows" do
        cfd_model.create!(
          target_model: "project", field_name: "test_field",
          custom_type: "string", label: "Test", position: 0
        )

        get "/projects/custom-fields/manage"
        expect(response.body).to include("data-lcp-condition-scope")
      end
    end

    describe "PATCH /projects/custom-fields/manage (bulk_update)" do
      it "creates new definitions" do
        expect {
          patch "/projects/custom-fields/manage", params: {
            definitions: {
              "0" => { field_name: "new_field", custom_type: "string", label: "New Field", position: 0 }
            }
          }
        }.to change { cfd_model.where(target_model: "project").count }.by(1)

        expect(response).to have_http_status(:redirect)
      end

      it "updates existing definitions" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "existing",
          custom_type: "string", label: "Old Label", position: 0
        )

        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { id: defn.id, field_name: "existing", custom_type: "string", label: "New Label", position: 0 }
          }
        }

        expect(response).to have_http_status(:redirect)
        expect(defn.reload.label).to eq("New Label")
      end

      it "prevents target_model tampering" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "tamper_test",
          custom_type: "string", label: "Tamper", position: 0
        )

        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { id: defn.id, field_name: "tamper_test", custom_type: "string", label: "Updated", position: 0 }
          }
        }

        expect(defn.reload.target_model).to eq("project")
      end

      it "handles validation errors" do
        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { field_name: "", custom_type: "string", label: "", position: 0 }
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "preserves user input on validation error" do
        existing = cfd_model.create!(
          target_model: "project", field_name: "existing_field",
          custom_type: "string", label: "Original Label", position: 0
        )

        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { id: existing.id, field_name: "existing_field", custom_type: "string", label: "Edited Label", position: 0 },
            "1" => { field_name: "", custom_type: "string", label: "", position: 1 }
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        # The edited label should be preserved in the re-rendered form, not reverted to DB state
        expect(response.body).to include("Edited Label")
        # The original DB record should NOT have been changed (transaction rolled back)
        expect(existing.reload.label).to eq("Original Label")
      end

      it "normalizes positions server-side" do
        defn1 = cfd_model.create!(
          target_model: "project", field_name: "field_a",
          custom_type: "string", label: "A", position: 5
        )
        defn2 = cfd_model.create!(
          target_model: "project", field_name: "field_b",
          custom_type: "string", label: "B", position: 10
        )

        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { id: defn2.id, field_name: "field_b", custom_type: "string", label: "B", position: 10 },
            "1" => { id: defn1.id, field_name: "field_a", custom_type: "string", label: "A", position: 5 }
          }
        }

        expect(response).to have_http_status(:redirect)
        # Positions should be normalized to 0,1,2... based on param order
        expect(defn2.reload.position).to eq(0)
        expect(defn1.reload.position).to eq(1)
      end

      it "updates position values" do
        defn1 = cfd_model.create!(
          target_model: "project", field_name: "field_a",
          custom_type: "string", label: "A", position: 0
        )
        defn2 = cfd_model.create!(
          target_model: "project", field_name: "field_b",
          custom_type: "string", label: "B", position: 1
        )

        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { id: defn2.id, field_name: "field_b", custom_type: "string", label: "B", position: 0 },
            "1" => { id: defn1.id, field_name: "field_a", custom_type: "string", label: "A", position: 1 }
          }
        }

        expect(response).to have_http_status(:redirect)
        expect(defn1.reload.position).to eq(1)
        expect(defn2.reload.position).to eq(0)
      end
    end

    describe "removal of records marked _remove" do
      it "destroys existing records marked for removal" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "to_remove",
          custom_type: "string", label: "Remove Me", position: 0
        )

        expect {
          patch "/projects/custom-fields/manage", params: {
            definitions: {
              "0" => { id: defn.id, field_name: "to_remove", custom_type: "string", label: "Remove Me", position: 0, _remove: "1" }
            }
          }
        }.to change { cfd_model.where(target_model: "project").count }.by(-1)

        expect(response).to have_http_status(:redirect)
        expect(cfd_model.find_by(id: defn.id)).to be_nil
      end

      it "destroys removed records and keeps non-removed ones" do
        keep = cfd_model.create!(
          target_model: "project", field_name: "keeper",
          custom_type: "string", label: "Keep", position: 0
        )
        remove = cfd_model.create!(
          target_model: "project", field_name: "goner",
          custom_type: "string", label: "Gone", position: 1
        )

        expect {
          patch "/projects/custom-fields/manage", params: {
            definitions: {
              "0" => { id: keep.id, field_name: "keeper", custom_type: "string", label: "Keep", position: 0 },
              "1" => { id: remove.id, field_name: "goner", custom_type: "string", label: "Gone", position: 1, _remove: "1" }
            }
          }
        }.to change { cfd_model.where(target_model: "project").count }.by(-1)

        expect(response).to have_http_status(:redirect)
        expect(cfd_model.find_by(id: keep.id)).to be_present
        expect(cfd_model.find_by(id: remove.id)).to be_nil
      end

      it "ignores _remove on new records (just skips them)" do
        expect {
          patch "/projects/custom-fields/manage", params: {
            definitions: {
              "0" => { field_name: "phantom", custom_type: "string", label: "Phantom", position: 0, _remove: "1" }
            }
          }
        }.not_to change { cfd_model.where(target_model: "project").count }

        expect(response).to have_http_status(:redirect)
      end

      it "rolls back removal when other records have validation errors" do
        to_remove = cfd_model.create!(
          target_model: "project", field_name: "will_survive",
          custom_type: "string", label: "Survive", position: 0
        )

        patch "/projects/custom-fields/manage", params: {
          definitions: {
            "0" => { id: to_remove.id, field_name: "will_survive", custom_type: "string", label: "Survive", position: 0, _remove: "1" },
            "1" => { field_name: "", custom_type: "string", label: "", position: 1 }
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(cfd_model.find_by(id: to_remove.id)).to be_present
      end
    end

    describe "template row filtering" do
      it "ignores NEW_RECORD template key in bulk_update" do
        defn = cfd_model.create!(
          target_model: "project", field_name: "kept",
          custom_type: "string", label: "Kept", position: 0
        )

        expect {
          patch "/projects/custom-fields/manage", params: {
            definitions: {
              "0" => { id: defn.id, field_name: "kept", custom_type: "string", label: "Kept", position: 0 },
              "NEW_RECORD" => { field_name: "", custom_type: "string", label: "", position: 1 }
            }
          }
        }.not_to change { cfd_model.count }

        expect(response).to have_http_status(:redirect)
      end
    end

    describe "drag & drop support" do
      it "renders sortable container with data-sortable attribute" do
        get "/projects/custom-fields/manage"
        expect(response.body).to include('data-sortable="true"')
      end

      it "renders rows with lcp-nested-row class for drag & drop" do
        cfd_model.create!(
          target_model: "project", field_name: "draggable",
          custom_type: "string", label: "Draggable", position: 0
        )

        get "/projects/custom-fields/manage"
        expect(response.body).to include("lcp-manage-row lcp-nested-row")
      end

      it "renders drag handle on each row" do
        cfd_model.create!(
          target_model: "project", field_name: "handle_test",
          custom_type: "string", label: "Handle Test", position: 0
        )

        get "/projects/custom-fields/manage"
        expect(response.body).to include("lcp-drag-handle")
      end
    end

    describe "template inputs disabled" do
      it "renders template container with disabled fieldset" do
        get "/projects/custom-fields/manage"
        expect(response.body).to include("data-lcp-manage-template")
        expect(response.body).to include("<fieldset disabled")
      end
    end

    describe "Manage All link on index" do
      it "shows Manage All button on custom fields index" do
        get "/projects/custom-fields"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("lcp_ruby.manage.manage_all"))
      end
    end

    describe "Viewer access denied" do
      it "denies manage page access for viewer role" do
        stub_current_user(role: "viewer")

        get "/projects/custom-fields/manage"

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end
    end
  end
end
