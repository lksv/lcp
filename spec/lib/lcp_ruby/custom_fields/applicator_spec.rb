require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::CustomFields::Applicator do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("custom_fields_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("custom_fields_test")
  end

  before(:each) do
    Object.new.extend(IntegrationHelper).load_integration_metadata!("custom_fields_test")
    # Clean definitions from previous tests to avoid cross-test interference
    LcpRuby.registry.model_for("custom_field_definition").delete_all
    LcpRuby::CustomFields::Registry.reload!
  end

  let(:project_model) { LcpRuby.registry.model_for("project") }
  let(:cfd_model) { LcpRuby.registry.model_for("custom_field_definition") }

  describe "custom data read/write" do
    it "reads and writes custom field values" do
      record = project_model.new(name: "Test")
      record.write_custom_field("website", "https://example.com")
      expect(record.read_custom_field("website")).to eq("https://example.com")
    end

    it "persists custom field values" do
      record = project_model.create!(name: "Persist Test")
      record.write_custom_field("website", "https://example.com")
      record.save!

      reloaded = project_model.find(record.id)
      expect(reloaded.read_custom_field("website")).to eq("https://example.com")
    end
  end

  describe "dynamic accessors" do
    before do
      cfd_model.create!(
        target_model: "project", field_name: "website",
        custom_type: "string", label: "Website"
      )
      project_model.apply_custom_field_accessors!
    end

    it "defines getter method" do
      record = project_model.new(name: "Test")
      record.website = "https://example.com"
      expect(record.website).to eq("https://example.com")
    end

    it "defines setter method" do
      record = project_model.new(name: "Test")
      record.website = "https://example.com"
      expect(record.read_custom_field("website")).to eq("https://example.com")
    end

    it "persists via dynamic accessors" do
      record = project_model.create!(name: "Accessor Test")
      record.website = "https://example.com"
      record.save!

      reloaded = project_model.find(record.id)
      expect(reloaded.website).to eq("https://example.com")
    end
  end

  describe "validations" do
    it "validates required custom fields" do
      cfd_model.create!(
        target_model: "project", field_name: "required_field",
        custom_type: "string", label: "Required", required: true
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      expect(record).not_to be_valid
      expect(record.errors[:required_field]).to include(a_string_matching(/blank|can't be blank/i))
    end

    it "validates max_length" do
      cfd_model.create!(
        target_model: "project", field_name: "short_field",
        custom_type: "string", label: "Short", max_length: 5
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.short_field = "toolongvalue"
      expect(record).not_to be_valid
      expect(record.errors[:short_field]).to be_present
    end

    it "validates min_length" do
      cfd_model.create!(
        target_model: "project", field_name: "min_field",
        custom_type: "string", label: "Min", min_length: 3
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.min_field = "ab"
      expect(record).not_to be_valid
      expect(record.errors[:min_field]).to be_present
    end

    it "validates numeric range" do
      cfd_model.create!(
        target_model: "project", field_name: "score",
        custom_type: "integer", label: "Score",
        min_value: 0, max_value: 100
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.score = "150"
      expect(record).not_to be_valid
      expect(record.errors[:score]).to be_present
    end

    it "skips validation for non-required blank fields" do
      cfd_model.create!(
        target_model: "project", field_name: "optional",
        custom_type: "string", label: "Optional", required: false
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      expect(record).to be_valid
    end

    it "rejects non-numeric values for integer fields" do
      cfd_model.create!(
        target_model: "project", field_name: "count",
        custom_type: "integer", label: "Count"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.count = "not_a_number"
      expect(record).not_to be_valid
      expect(record.errors[:count]).to include(a_string_matching(/number/i))
    end

    it "does not apply length constraints to integer fields" do
      cfd_model.create!(
        target_model: "project", field_name: "age",
        custom_type: "integer", label: "Age",
        min_length: 3, max_length: 10
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.age = "5"
      expect(record).to be_valid
    end

    it "does not apply length constraints to boolean fields" do
      cfd_model.create!(
        target_model: "project", field_name: "active_flag",
        custom_type: "boolean", label: "Active",
        min_length: 5
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.active_flag = "true"
      expect(record).to be_valid
    end
  end

  describe "stale accessor cleanup" do
    it "removes accessors when a custom field definition is deleted" do
      defn = cfd_model.create!(
        target_model: "project", field_name: "temp_field",
        custom_type: "string", label: "Temp"
      )
      project_model.apply_custom_field_accessors!
      expect(project_model.new(name: "Test")).to respond_to(:temp_field)
      expect(project_model.new(name: "Test")).to respond_to(:temp_field=)

      defn.destroy!
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      expect(project_model.new(name: "Test")).not_to respond_to(:temp_field)
      expect(project_model.new(name: "Test")).not_to respond_to(:temp_field=)
    end

    it "removes old accessors and adds new ones on re-apply" do
      cfd_model.create!(
        target_model: "project", field_name: "old_field",
        custom_type: "string", label: "Old"
      )
      project_model.apply_custom_field_accessors!
      expect(project_model.new(name: "Test")).to respond_to(:old_field)

      cfd_model.where(field_name: "old_field").destroy_all
      cfd_model.create!(
        target_model: "project", field_name: "new_field",
        custom_type: "string", label: "New"
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      expect(project_model.new(name: "Test")).not_to respond_to(:old_field)
      expect(project_model.new(name: "Test")).to respond_to(:new_field)
    end
  end

  describe "default values" do
    it "applies default_value to new records" do
      cfd_model.create!(
        target_model: "project", field_name: "priority",
        custom_type: "string", label: "Priority",
        default_value: "medium"
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      expect(record.read_custom_field("priority")).to eq("medium")
    end

    it "does not override explicitly set values" do
      cfd_model.create!(
        target_model: "project", field_name: "priority",
        custom_type: "string", label: "Priority",
        default_value: "medium"
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      record.write_custom_field("priority", "high")
      expect(record.read_custom_field("priority")).to eq("high")
    end

    it "does not apply defaults to existing records" do
      record = project_model.create!(name: "Existing")

      cfd_model.create!(
        target_model: "project", field_name: "priority",
        custom_type: "string", label: "Priority",
        default_value: "medium"
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      reloaded = project_model.find(record.id)
      expect(reloaded.read_custom_field("priority")).to be_nil
    end

    it "skips fields with blank default_value" do
      cfd_model.create!(
        target_model: "project", field_name: "optional",
        custom_type: "string", label: "Optional",
        default_value: ""
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      expect(record.read_custom_field("optional")).to be_nil
    end

    it "makes default values visible via dynamic accessors" do
      cfd_model.create!(
        target_model: "project", field_name: "status_cf",
        custom_type: "string", label: "Status CF",
        default_value: "active"
      )
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      expect(record.status_cf).to eq("active")
    end
  end

  describe "custom field deleted then regular field added with same name" do
    after do
      # Remove the dynamically added column so it doesn't affect other tests
      conn = ActiveRecord::Base.connection
      table = project_model.table_name
      if project_model.column_names.include?("website")
        conn.remove_column(table, :website)
        project_model.reset_column_information
      end
    end

    it "writes to the regular DB column, not custom_data" do
      # Step 1: Create custom field "website"
      defn = cfd_model.create!(
        target_model: "project", field_name: "website",
        custom_type: "string", label: "Website"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.create!(name: "Test")
      record.website = "https://via-custom.com"
      record.save!
      expect(record.read_custom_field("website")).to eq("https://via-custom.com")

      # Step 2: Delete custom field definition
      defn.destroy!
      LcpRuby::CustomFields::Registry.reload!("project")
      project_model.apply_custom_field_accessors!
      expect(project_model.new(name: "X")).not_to respond_to(:website)

      # Step 3: Add a regular DB column "website" to the same table
      conn = ActiveRecord::Base.connection
      table = project_model.table_name
      conn.add_column(table, :website, :string) unless project_model.column_names.include?("website")
      project_model.reset_column_information

      # Step 4: Re-apply accessors (simulates reload after config change)
      project_model.apply_custom_field_accessors!

      # Step 5: Write via the regular column — must NOT go to custom_data
      fresh_record = project_model.create!(name: "Regular Column Test")
      fresh_record.website = "https://via-column.com"
      fresh_record.save!

      reloaded = project_model.find(fresh_record.id)
      expect(reloaded.website).to eq("https://via-column.com")
      expect(reloaded.read_custom_field("website")).to be_nil
    end
  end

  describe "type change on existing custom field" do
    it "validates with new type rules after string -> integer change" do
      defn = cfd_model.create!(
        target_model: "project", field_name: "score",
        custom_type: "string", label: "Score"
      )
      project_model.apply_custom_field_accessors!

      # Write a string value while type is "string"
      record = project_model.create!(name: "Type Change")
      record.score = "hello"
      record.save!

      # Change type to integer
      defn.update!(custom_type: "integer")
      LcpRuby::CustomFields::Registry.reload!("project")

      # Existing string value is now invalid under integer validation
      reloaded = project_model.find(record.id)
      expect(reloaded).not_to be_valid
      expect(reloaded.errors[:score]).to include(a_string_matching(/number/i))
    end

    it "accepts numeric string value after string -> integer change" do
      defn = cfd_model.create!(
        target_model: "project", field_name: "amount",
        custom_type: "string", label: "Amount"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.create!(name: "Numeric String")
      record.amount = "42"
      record.save!

      # Change type to integer
      defn.update!(custom_type: "integer")
      LcpRuby::CustomFields::Registry.reload!("project")

      reloaded = project_model.find(record.id)
      expect(reloaded).to be_valid
    end

    it "allows saving after integer -> string change" do
      defn = cfd_model.create!(
        target_model: "project", field_name: "code",
        custom_type: "integer", label: "Code"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.create!(name: "Int to String")
      record.code = "99"
      record.save!

      # Change type to string — numeric value is a valid string
      defn.update!(custom_type: "string")
      LcpRuby::CustomFields::Registry.reload!("project")

      reloaded = project_model.find(record.id)
      expect(reloaded).to be_valid
      expect(reloaded.code).to eq("99")
    end

    it "applies new length constraints after type change to string" do
      defn = cfd_model.create!(
        target_model: "project", field_name: "tag",
        custom_type: "integer", label: "Tag"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.create!(name: "Length After Type Change")
      record.tag = "12345"
      record.save!

      # Change to string with max_length
      defn.update!(custom_type: "string", max_length: 3)
      LcpRuby::CustomFields::Registry.reload!("project")

      reloaded = project_model.find(record.id)
      expect(reloaded).not_to be_valid
      expect(reloaded.errors[:tag]).to be_present
    end
  end

  describe "conflict avoidance" do
    it "does not override existing column accessors" do
      cfd_model.create!(
        target_model: "project", field_name: "name",
        custom_type: "string", label: "Name Override"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Real Name")
      expect(record.name).to eq("Real Name")
    end

    it "skips reserved names" do
      cfd_model.create!(
        target_model: "project", field_name: "id",
        custom_type: "integer", label: "ID Override"
      )
      project_model.apply_custom_field_accessors!

      record = project_model.new(name: "Test")
      # id should still work as primary key
      expect(record).to respond_to(:id)
    end
  end
end
