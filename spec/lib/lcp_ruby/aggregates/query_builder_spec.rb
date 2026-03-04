require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::Aggregates::QueryBuilder do
  before do
    LcpRuby.reset!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  def build_model(name, hash)
    model_def = LcpRuby::Metadata::ModelDefinition.from_hash(hash)
    # Register in the loader so QueryBuilder can look up target models
    LcpRuby.loader.model_definitions[name] = model_def
    schema_manager = LcpRuby::ModelFactory::SchemaManager.new(model_def)
    schema_manager.ensure_table!
    builder = LcpRuby::ModelFactory::Builder.new(model_def)
    model_class = builder.build
    LcpRuby.registry.register(name, model_class)
    [model_def, model_class]
  end

  let!(:issue_setup) do
    build_model("agg_issue", {
      "name" => "agg_issue",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "status", "type" => "string" },
        { "name" => "priority", "type" => "integer" },
        { "name" => "agg_project_id", "type" => "integer" }
      ]
    })
  end

  let!(:project_setup) do
    build_model("agg_project", {
      "name" => "agg_project",
      "fields" => [
        { "name" => "name", "type" => "string" }
      ],
      "associations" => [
        { "type" => "has_many", "name" => "agg_issues", "target_model" => "agg_issue", "foreign_key" => "agg_project_id" }
      ],
      "aggregates" => {
        "issues_count" => { "function" => "count", "association" => "agg_issues" },
        "open_issues_count" => {
          "function" => "count",
          "association" => "agg_issues",
          "where" => { "status" => "open" }
        },
        "max_priority" => {
          "function" => "max",
          "association" => "agg_issues",
          "source_field" => "priority",
          "default" => 0
        }
      }
    })
  end

  let(:project_model_def) { project_setup[0] }
  let(:project_class) { project_setup[1] }
  let(:issue_class) { issue_setup[1] }

  after(:all) do
    conn = ActiveRecord::Base.connection
    conn.drop_table("agg_issues", if_exists: true)
    conn.drop_table("agg_projects", if_exists: true)
  end

  describe ".apply" do
    it "returns unmodified scope and empty service list when no aggregate names" do
      scope = project_class.all
      result_scope, service_only = described_class.apply(scope, project_model_def, [])
      expect(service_only).to eq([])
    end

    it "injects COUNT subquery for count aggregate" do
      scope = project_class.all
      result_scope, _ = described_class.apply(scope, project_model_def, ["issues_count"])

      sql = result_scope.to_sql
      expect(sql).to include("COUNT(*)")
      expect(sql).to include("AS \"issues_count\"").or include("AS `issues_count`")
    end

    it "applies where conditions in subquery" do
      scope = project_class.all
      result_scope, _ = described_class.apply(scope, project_model_def, ["open_issues_count"])

      sql = result_scope.to_sql
      expect(sql).to include("open")
    end

    it "applies MAX function with default COALESCE" do
      scope = project_class.all
      result_scope, _ = described_class.apply(scope, project_model_def, ["max_priority"])

      sql = result_scope.to_sql
      expect(sql).to include("MAX")
      expect(sql).to include("COALESCE")
    end

    it "computes correct aggregate values" do
      project = project_class.create!(name: "Alpha")
      issue_class.create!(title: "Bug 1", status: "open", priority: 3, agg_project_id: project.id)
      issue_class.create!(title: "Bug 2", status: "closed", priority: 1, agg_project_id: project.id)
      issue_class.create!(title: "Bug 3", status: "open", priority: 5, agg_project_id: project.id)

      scope = project_class.all
      result_scope, _ = described_class.apply(
        scope, project_model_def, ["issues_count", "open_issues_count", "max_priority"]
      )

      record = result_scope.find(project.id)
      expect(record.read_attribute("issues_count")).to eq(3)
      expect(record.read_attribute("open_issues_count")).to eq(2)
      expect(record.read_attribute("max_priority")).to eq(5)
    end

    context "with :current_user placeholder" do
      let!(:user_issue_setup) do
        build_model("user_issue", {
          "name" => "user_issue",
          "fields" => [
            { "name" => "title", "type" => "string" },
            { "name" => "assignee_id", "type" => "integer" },
            { "name" => "board_id", "type" => "integer" }
          ]
        })
      end

      let!(:board_setup) do
        build_model("board", {
          "name" => "board",
          "fields" => [
            { "name" => "name", "type" => "string" }
          ],
          "associations" => [
            { "type" => "has_many", "name" => "user_issues", "target_model" => "user_issue", "foreign_key" => "board_id" }
          ],
          "aggregates" => {
            "my_issues_count" => {
              "function" => "count",
              "association" => "user_issues",
              "where" => { "assignee_id" => ":current_user" }
            }
          }
        })
      end

      let(:board_model_def) { board_setup[0] }
      let(:board_class) { board_setup[1] }
      let(:user_issue_class) { user_issue_setup[1] }

      after(:all) do
        conn = ActiveRecord::Base.connection
        conn.drop_table("user_issues", if_exists: true)
        conn.drop_table("boards", if_exists: true)
      end

      it "substitutes :current_user with user id" do
        current_user = OpenStruct.new(id: 42)
        board = board_class.create!(name: "Dev Board")
        user_issue_class.create!(title: "My task", assignee_id: 42, board_id: board.id)
        user_issue_class.create!(title: "Other task", assignee_id: 99, board_id: board.id)

        scope = board_class.all
        result_scope, _ = described_class.apply(
          scope, board_model_def, ["my_issues_count"], current_user: current_user
        )

        record = result_scope.find(board.id)
        expect(record.read_attribute("my_issues_count")).to eq(1)
      end
    end
  end

  describe "SQL type aggregate" do
    let!(:sql_project_setup) do
      build_model("agg_sql_project", {
        "name" => "agg_sql_project",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "aggregates" => {
          "custom_calc" => {
            "sql" => "SELECT COUNT(*) FROM agg_issues WHERE agg_issues.agg_project_id = %{table}.id",
            "type" => "integer"
          }
        }
      })
    end

    let(:sql_project_model_def) { sql_project_setup[0] }
    let(:sql_project_class) { sql_project_setup[1] }

    after(:all) do
      conn = ActiveRecord::Base.connection
      conn.drop_table("agg_sql_projects", if_exists: true)
    end

    it "expands %{table} placeholder in SQL" do
      scope = sql_project_class.all
      result_scope, _ = described_class.apply(scope, sql_project_model_def, ["custom_calc"])

      sql = result_scope.to_sql
      expect(sql).to include("agg_issues")
      expect(sql).not_to include("%{table}")
    end
  end
end
