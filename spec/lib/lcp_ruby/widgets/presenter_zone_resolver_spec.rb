require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Widgets::PresenterZoneResolver do
  include IntegrationHelper

  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("dashboard")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("dashboard")
  end

  before(:each) do
    load_integration_metadata!("dashboard")
  end

  let(:admin_user) do
    OpenStruct.new(id: 1, lcp_role: [ "admin" ], name: "Admin")
  end

  let(:task_model) { LcpRuby.registry.model_for("dashboard_task") }

  describe "#resolve" do
    let(:zone) do
      LcpRuby::Metadata::ZoneDefinition.new(
        name: "task_list",
        presenter: "dashboard_tasks",
        limit: 5
      )
    end

    it "returns records with rendering context" do
      3.times { |i| task_model.create!(name: "Task #{i}", status: "open") }

      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:records].length).to eq(3)
      expect(result[:presenter]).to be_a(LcpRuby::Metadata::PresenterDefinition)
      expect(result[:column_set]).to be_a(LcpRuby::Presenter::ColumnSet)
      expect(result[:action_set]).to be_a(LcpRuby::Presenter::ActionSet)
      expect(result[:evaluator]).to be_a(LcpRuby::Authorization::PermissionEvaluator)
      expect(result[:field_value_resolver]).to be_a(LcpRuby::Presenter::FieldValueResolver)
    end

    it "limits records" do
      10.times { |i| task_model.create!(name: "Task #{i}", status: "open") }

      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:records].length).to eq(5)
    end

    it "returns hidden when presenter references unknown model" do
      bad_zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "bad",
        presenter: "nonexistent_presenter"
      )
      result = described_class.new(bad_zone, user: admin_user).resolve
      expect(result[:hidden]).to be true
    end

    it "applies zone scope" do
      task_model.create!(name: "Open", status: "open")
      task_model.create!(name: "Closed", status: "closed")

      scoped_zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "open_tasks",
        presenter: "dashboard_tasks",
        scope: "open_tasks"
      )

      result = described_class.new(scoped_zone, user: admin_user).resolve
      expect(result[:records].length).to eq(1)
      expect(result[:records].first.name).to eq("Open")
    end
  end
end
