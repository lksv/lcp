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

    it "applies scope_context to filter records" do
      task_model.create!(name: "Task A", status: "open")
      task_model.create!(name: "Task B", status: "closed")

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "filtered_tasks",
        presenter: "dashboard_tasks",
        limit: 10
      )

      result = described_class.new(zone, user: admin_user, scope_context: { "status" => "open" }).resolve
      expect(result[:records].length).to eq(1)
      expect(result[:records].first.name).to eq("Task A")
    end

    it "does not filter when scope_context is empty" do
      task_model.create!(name: "Task A", status: "open")
      task_model.create!(name: "Task B", status: "closed")

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "all_tasks",
        presenter: "dashboard_tasks",
        limit: 10
      )

      result = described_class.new(zone, user: admin_user, scope_context: {}).resolve
      expect(result[:records].length).to eq(2)
    end

    it "logs warning for unknown scope_context key without crashing" do
      task_model.create!(name: "Task", status: "open")

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "test",
        presenter: "dashboard_tasks",
        limit: 10
      )

      expect(Rails.logger).to receive(:warn).with(/scope_context key 'nonexistent'/)

      result = described_class.new(zone, user: admin_user, scope_context: { "nonexistent" => 42 }).resolve
      expect(result[:records]).not_to be_empty
    end

    it "calls filter_* method with 3 args when method accepts 3 parameters" do
      task_model.create!(name: "Task A", status: "open")
      task_model.create!(name: "Task B", status: "closed")

      # Define a 3-arg filter_* method (matching the advanced search convention)
      task_model.define_singleton_method(:filter_status) do |scope, value, _evaluator|
        scope.where(status: value)
      end

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "filtered",
        presenter: "dashboard_tasks",
        limit: 10
      )

      result = described_class.new(zone, user: admin_user, scope_context: { "status" => "open" }).resolve
      expect(result[:records].length).to eq(1)
      expect(result[:records].first.name).to eq("Task A")
    ensure
      task_model.singleton_class.remove_method(:filter_status) if task_model.respond_to?(:filter_status)
    end

    it "calls filter_* method with 2 args when method accepts 2 parameters" do
      task_model.create!(name: "Task A", status: "open")
      task_model.create!(name: "Task B", status: "closed")

      # Define a 2-arg filter_* method
      task_model.define_singleton_method(:filter_status) do |scope, value|
        scope.where(status: value)
      end

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "filtered",
        presenter: "dashboard_tasks",
        limit: 10
      )

      result = described_class.new(zone, user: admin_user, scope_context: { "status" => "open" }).resolve
      expect(result[:records].length).to eq(1)
      expect(result[:records].first.name).to eq("Task A")
    ensure
      task_model.singleton_class.remove_method(:filter_status) if task_model.respond_to?(:filter_status)
    end
  end
end
