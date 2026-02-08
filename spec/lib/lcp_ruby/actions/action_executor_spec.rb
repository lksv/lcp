require "spec_helper"

RSpec.describe LcpRuby::Actions::ActionExecutor do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  before do
    model_hash = YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
    model_def = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)

    LcpRuby::ModelFactory::SchemaManager.new(model_def).ensure_table!
    @model_class = LcpRuby::ModelFactory::Builder.new(model_def).build
    LcpRuby.registry.register("project", @model_class)
  end

  after do
    ActiveRecord::Base.connection.drop_table(:projects) if ActiveRecord::Base.connection.table_exists?(:projects)
  end

  describe "#execute" do
    let(:archive_action) do
      Class.new(LcpRuby::Actions::BaseAction) do
        def call
          record.update!(status: "archived")
          success(message: "Project archived.")
        end
      end
    end

    before do
      LcpRuby::Actions::ActionRegistry.register("project/archive", archive_action)
    end

    it "executes a registered action" do
      record = @model_class.create!(title: "Test Project", status: "active")

      result = described_class.new("project/archive", {
        record: record,
        current_user: double("User"),
        model_class: @model_class
      }).execute

      expect(result).to be_success
      expect(result.message).to eq("Project archived.")
      expect(record.reload.status).to eq("archived")
    end

    it "returns failure for unregistered action" do
      result = described_class.new("project/nonexistent", {}).execute
      expect(result).to be_failure
      expect(result.message).to include("not found")
    end

    it "returns failure when action raises" do
      failing_action = Class.new(LcpRuby::Actions::BaseAction) do
        def call
          raise "Something went wrong"
        end
      end

      LcpRuby::Actions::ActionRegistry.register("project/fail", failing_action)

      result = described_class.new("project/fail", {
        record: @model_class.create!(title: "Test"),
        current_user: double("User")
      }).execute

      expect(result).to be_failure
      expect(result.message).to include("Something went wrong")
    end

    it "checks authorization" do
      restricted_action = Class.new(LcpRuby::Actions::BaseAction) do
        def self.authorized?(_record, _user)
          false
        end

        def call
          success(message: "Should not reach here")
        end
      end

      LcpRuby::Actions::ActionRegistry.register("project/restricted", restricted_action)

      result = described_class.new("project/restricted", {
        record: @model_class.create!(title: "Test"),
        current_user: double("User")
      }).execute

      expect(result).to be_failure
      expect(result.message).to include("Not authorized")
    end
  end
end
