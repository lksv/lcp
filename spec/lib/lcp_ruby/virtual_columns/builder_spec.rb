require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::VirtualColumns::Builder do
  before do
    LcpRuby.reset!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  def build_model(name, hash)
    model_def = LcpRuby::Metadata::ModelDefinition.from_hash(hash)
    LcpRuby.loader.model_definitions[name] = model_def
    schema_manager = LcpRuby::ModelFactory::SchemaManager.new(model_def)
    schema_manager.ensure_table!
    builder = LcpRuby::ModelFactory::Builder.new(model_def)
    model_class = builder.build
    LcpRuby.registry.register(name, model_class)
    [ model_def, model_class ]
  end

  let!(:issue_setup) do
    build_model("vc_issue", {
      "name" => "vc_issue",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "status", "type" => "string" },
        { "name" => "priority", "type" => "integer" },
        { "name" => "quantity", "type" => "integer" },
        { "name" => "unit_price", "type" => "decimal" },
        { "name" => "vc_project_id", "type" => "integer" }
      ]
    })
  end

  let!(:project_setup) do
    build_model("vc_project", {
      "name" => "vc_project",
      "fields" => [
        { "name" => "name", "type" => "string" },
        { "name" => "due_date", "type" => "date" },
        { "name" => "status", "type" => "string" }
      ],
      "associations" => [
        { "type" => "has_many", "name" => "vc_issues", "target_model" => "vc_issue", "foreign_key" => "vc_project_id" }
      ],
      "virtual_columns" => {
        "issues_count" => { "function" => "count", "association" => "vc_issues" },
        "open_count" => {
          "function" => "count",
          "association" => "vc_issues",
          "where" => { "status" => "open" }
        },
        "is_overdue" => {
          "expression" => "CASE WHEN %{table}.due_date < date('now') AND %{table}.status != 'done' THEN 1 ELSE 0 END",
          "type" => "boolean",
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
    conn.drop_table("vc_issues", if_exists: true)
    conn.drop_table("vc_projects", if_exists: true)
  end

  describe ".apply" do
    it "returns unmodified scope and empty service list when no VC names" do
      scope = project_class.all
      result_scope, service_only = described_class.apply(scope, project_model_def, [])
      expect(service_only).to eq([])
    end

    it "injects COUNT subquery for declarative aggregate" do
      scope = project_class.all
      result_scope, _ = described_class.apply(scope, project_model_def, [ "issues_count" ])

      sql = result_scope.to_sql
      expect(sql).to include("COUNT(*)")
      expect(sql).to include("AS \"issues_count\"").or include("AS `issues_count`")
    end

    it "computes correct aggregate values" do
      project = project_class.create!(name: "Alpha", due_date: Date.tomorrow, status: "active")
      issue_class.create!(title: "Bug 1", status: "open", priority: 3, quantity: 1, unit_price: 10, vc_project_id: project.id)
      issue_class.create!(title: "Bug 2", status: "closed", priority: 1, quantity: 2, unit_price: 20, vc_project_id: project.id)

      scope = project_class.all
      result_scope, _ = described_class.apply(
        scope, project_model_def, [ "issues_count", "open_count" ]
      )

      record = result_scope.find(project.id)
      expect(record.read_attribute("issues_count")).to eq(2)
      expect(record.read_attribute("open_count")).to eq(1)
    end
  end

  describe "expression building" do
    it "expands %{table} placeholder in expression" do
      scope = project_class.all
      result_scope, _ = described_class.apply(scope, project_model_def, [ "is_overdue" ])

      sql = result_scope.to_sql
      expect(sql).not_to include("%{table}")
      expect(sql).to include("CASE WHEN")
      expect(sql).to include("COALESCE")
    end

    it "computes expression values" do
      # Create a project with a past due date
      project = project_class.create!(name: "Overdue", due_date: Date.yesterday, status: "active")

      scope = project_class.all
      result_scope, _ = described_class.apply(scope, project_model_def, [ "is_overdue" ])

      record = result_scope.find(project.id)
      # The expression returns 1 (true-ish) for overdue
      expect(record.read_attribute("is_overdue")).to be_truthy
    end
  end

  describe "JOIN collection and deduplication" do
    let!(:join_project_setup) do
      build_model("join_project", {
        "name" => "join_project",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "join_company_id", "type" => "integer" }
        ],
        "virtual_columns" => {
          "company_name" => {
            "expression" => "join_companies.name",
            "join" => "LEFT JOIN join_companies ON join_companies.id = %{table}.join_company_id",
            "type" => "string"
          },
          "company_code" => {
            "expression" => "join_companies.name",
            "join" => "LEFT JOIN join_companies ON join_companies.id = %{table}.join_company_id",
            "type" => "string"
          }
        }
      })
    end

    let!(:company_setup) do
      build_model("join_company", {
        "name" => "join_company",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ]
      })
    end

    let(:join_project_model_def) { join_project_setup[0] }
    let(:join_project_class) { join_project_setup[1] }
    let(:join_company_class) { company_setup[1] }

    after(:all) do
      conn = ActiveRecord::Base.connection
      conn.drop_table("join_projects", if_exists: true)
      conn.drop_table("join_companies", if_exists: true)
    end

    it "applies JOIN and resolves expression" do
      company = join_company_class.create!(name: "Acme Corp")
      proj = join_project_class.create!(name: "Project X", join_company_id: company.id)

      scope = join_project_class.all
      result_scope, _ = described_class.apply(
        scope, join_project_model_def, [ "company_name" ]
      )

      sql = result_scope.to_sql
      expect(sql).to include("LEFT JOIN")

      record = result_scope.find(proj.id)
      expect(record.read_attribute("company_name")).to eq("Acme Corp")
    end

    it "deduplicates identical JOINs" do
      scope = join_project_class.all
      result_scope, _ = described_class.apply(
        scope, join_project_model_def, [ "company_name", "company_code" ]
      )

      sql = result_scope.to_sql
      # The JOIN should appear only once even though two VCs reference it
      join_count = sql.scan(/LEFT JOIN/).size
      expect(join_count).to eq(1)
    end
  end

  describe "GROUP BY injection" do
    let!(:group_project_setup) do
      build_model("grp_project", {
        "name" => "grp_project",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "virtual_columns" => {
          "total_value" => {
            "expression" => "SUM(grp_line_items.quantity * grp_line_items.unit_price)",
            "join" => "LEFT JOIN grp_line_items ON grp_line_items.grp_project_id = %{table}.id",
            "group" => true,
            "type" => "decimal",
            "default" => 0
          }
        }
      })
    end

    let!(:line_item_setup) do
      build_model("grp_line_item", {
        "name" => "grp_line_item",
        "fields" => [
          { "name" => "quantity", "type" => "integer" },
          { "name" => "unit_price", "type" => "decimal" },
          { "name" => "grp_project_id", "type" => "integer" }
        ]
      })
    end

    let(:group_project_model_def) { group_project_setup[0] }
    let(:group_project_class) { group_project_setup[1] }
    let(:line_item_class) { line_item_setup[1] }

    after(:all) do
      conn = ActiveRecord::Base.connection
      conn.drop_table("grp_projects", if_exists: true)
      conn.drop_table("grp_line_items", if_exists: true)
    end

    it "adds GROUP BY when group: true" do
      scope = group_project_class.all
      result_scope, _ = described_class.apply(
        scope, group_project_model_def, [ "total_value" ]
      )

      sql = result_scope.to_sql
      expect(sql).to include("GROUP BY")
    end

    it "computes grouped aggregate value" do
      project = group_project_class.create!(name: "Order 1")
      line_item_class.create!(quantity: 2, unit_price: 10.0, grp_project_id: project.id)
      line_item_class.create!(quantity: 3, unit_price: 5.0, grp_project_id: project.id)

      scope = group_project_class.all
      result_scope, _ = described_class.apply(
        scope, group_project_model_def, [ "total_value" ]
      )

      record = result_scope.find(project.id)
      # 2*10 + 3*5 = 35
      expect(record.read_attribute("total_value").to_f).to eq(35.0)
    end
  end

  describe "mixed declarative+expression queries" do
    it "handles both types in a single apply" do
      project = project_class.create!(name: "Mixed", due_date: Date.tomorrow, status: "active")
      issue_class.create!(title: "T1", status: "open", priority: 1, quantity: 1, unit_price: 10, vc_project_id: project.id)

      scope = project_class.all
      result_scope, _ = described_class.apply(
        scope, project_model_def, [ "issues_count", "is_overdue" ]
      )

      record = result_scope.find(project.id)
      expect(record.read_attribute("issues_count")).to eq(1)
      expect(record.read_attribute("is_overdue")).not_to be_nil
    end
  end

  describe ":current_user placeholder" do
    let!(:assignment_setup) do
      build_model("vc_assignment", {
        "name" => "vc_assignment",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "assigned_to", "type" => "integer" },
          { "name" => "vc_proj2_id", "type" => "integer" }
        ]
      })
    end

    let!(:proj2_setup) do
      build_model("vc_proj2", {
        "name" => "vc_proj2",
        "fields" => [ { "name" => "name", "type" => "string" } ],
        "associations" => [
          { "type" => "has_many", "name" => "vc_assignments", "target_model" => "vc_assignment", "foreign_key" => "vc_proj2_id" }
        ],
        "virtual_columns" => {
          "my_count" => {
            "function" => "count",
            "association" => "vc_assignments",
            "where" => { "assigned_to" => ":current_user" }
          }
        }
      })
    end

    let(:proj2_class) { proj2_setup[1] }
    let(:proj2_model_def) { proj2_setup[0] }
    let(:assignment_class) { assignment_setup[1] }

    after(:all) do
      conn = ActiveRecord::Base.connection
      conn.drop_table("vc_assignments", if_exists: true)
      conn.drop_table("vc_proj2s", if_exists: true)
    end

    it "replaces :current_user string placeholder with user id" do
      user = OpenStruct.new(id: 42)
      proj = proj2_class.create!(name: "P1")
      assignment_class.create!(title: "A1", assigned_to: 42, vc_proj2_id: proj.id)
      assignment_class.create!(title: "A2", assigned_to: 99, vc_proj2_id: proj.id)

      scope = proj2_class.all
      result_scope, _ = described_class.apply(scope, proj2_model_def, [ "my_count" ], current_user: user)
      record = result_scope.find(proj.id)
      expect(record.read_attribute("my_count")).to eq(1)
    end

    it "uses NULL when current_user is nil" do
      proj = proj2_class.create!(name: "P2")
      assignment_class.create!(title: "A3", assigned_to: 42, vc_proj2_id: proj.id)

      scope = proj2_class.all
      result_scope, _ = described_class.apply(scope, proj2_model_def, [ "my_count" ], current_user: nil)
      record = result_scope.find(proj.id)
      expect(record.read_attribute("my_count")).to eq(0)
    end
  end

  describe "DISTINCT aggregate" do
    it "generates DISTINCT in SQL" do
      project = project_class.create!(name: "Distinct Test", due_date: Date.tomorrow, status: "active")
      issue_class.create!(title: "I1", status: "open", priority: 1, quantity: 1, unit_price: 10, vc_project_id: project.id)
      issue_class.create!(title: "I2", status: "open", priority: 1, quantity: 1, unit_price: 10, vc_project_id: project.id)

      distinct_model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "vc_project",
        "fields" => [ { "name" => "name", "type" => "string" }, { "name" => "due_date", "type" => "date" }, { "name" => "status", "type" => "string" } ],
        "associations" => [
          { "type" => "has_many", "name" => "vc_issues", "target_model" => "vc_issue", "foreign_key" => "vc_project_id" }
        ],
        "virtual_columns" => {
          "distinct_statuses" => {
            "function" => "count",
            "association" => "vc_issues",
            "source_field" => "status",
            "distinct" => true
          }
        }
      })

      scope = project_class.all
      result_scope, _ = described_class.apply(scope, distinct_model_def, [ "distinct_statuses" ])

      sql = result_scope.to_sql
      expect(sql).to include("DISTINCT")

      record = result_scope.find(project.id)
      # Both issues have status "open", so distinct count = 1
      expect(record.read_attribute("distinct_statuses")).to eq(1)
    end
  end

  describe "where condition types" do
    it "generates IN clause for array values" do
      project = project_class.create!(name: "Array Where", due_date: Date.tomorrow, status: "active")
      issue_class.create!(title: "I1", status: "open", priority: 1, quantity: 1, unit_price: 10, vc_project_id: project.id)
      issue_class.create!(title: "I2", status: "closed", priority: 1, quantity: 1, unit_price: 10, vc_project_id: project.id)
      issue_class.create!(title: "I3", status: "wip", priority: 1, quantity: 1, unit_price: 10, vc_project_id: project.id)

      array_model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "vc_project",
        "fields" => [ { "name" => "name", "type" => "string" }, { "name" => "due_date", "type" => "date" }, { "name" => "status", "type" => "string" } ],
        "associations" => [
          { "type" => "has_many", "name" => "vc_issues", "target_model" => "vc_issue", "foreign_key" => "vc_project_id" }
        ],
        "virtual_columns" => {
          "active_count" => {
            "function" => "count",
            "association" => "vc_issues",
            "where" => { "status" => [ "open", "wip" ] }
          }
        }
      })

      scope = project_class.all
      result_scope, _ = described_class.apply(scope, array_model_def, [ "active_count" ])

      sql = result_scope.to_sql
      expect(sql).to include("IN")

      record = result_scope.find(project.id)
      expect(record.read_attribute("active_count")).to eq(2)
    end
  end

  describe "service with sql_expression" do
    it "uses sql_expression when service provides one" do
      service = double("vc_service")
      allow(service).to receive(:respond_to?).with(:sql_expression).and_return(true)
      allow(service).to receive(:sql_expression).and_return("(SELECT 42)")
      LcpRuby::Services::Registry.register("virtual_columns", "sql_svc", service)

      svc_model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "vc_project",
        "fields" => [ { "name" => "name", "type" => "string" }, { "name" => "due_date", "type" => "date" }, { "name" => "status", "type" => "string" } ],
        "virtual_columns" => {
          "computed_val" => { "service" => "sql_svc", "type" => "integer" }
        }
      })
      LcpRuby.loader.model_definitions["vc_project"] = svc_model_def

      project = project_class.create!(name: "Svc Test", due_date: Date.tomorrow, status: "active")
      scope = project_class.all
      result_scope, service_only = described_class.apply(scope, svc_model_def, [ "computed_val" ])

      expect(service_only).to be_empty
      record = result_scope.find(project.id)
      expect(record.read_attribute("computed_val")).to eq(42)
    end
  end

  describe "needs_group_by return value" do
    it "returns false when no group VCs" do
      scope = project_class.all
      _, _, needs_group_by = described_class.apply(scope, project_model_def, [ "issues_count" ])
      expect(needs_group_by).to be false
    end

    it "returns true when group VCs present" do
      grp_model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "vc_project",
        "fields" => [ { "name" => "name", "type" => "string" }, { "name" => "due_date", "type" => "date" }, { "name" => "status", "type" => "string" } ],
        "virtual_columns" => {
          "grouped_val" => {
            "expression" => "COUNT(*)",
            "join" => "LEFT JOIN vc_issues ON vc_issues.vc_project_id = %{table}.id",
            "group" => true,
            "type" => "integer"
          }
        }
      })

      scope = project_class.all
      _, _, needs_group_by = described_class.apply(scope, grp_model_def, [ "grouped_val" ])
      expect(needs_group_by).to be true
    end
  end

  describe "backward compatibility alias" do
    it "LcpRuby::Aggregates::QueryBuilder is aliased to Builder" do
      expect(LcpRuby::Aggregates::QueryBuilder).to eq(described_class)
    end
  end

  describe "service lookup with fallback" do
    it "looks up in virtual_columns category first, falls back to aggregates" do
      # Register a service in "aggregates" category
      service = double("service")
      allow(service).to receive(:respond_to?).with(:sql_expression).and_return(false)
      LcpRuby::Services::Registry.register("aggregates", "test_svc", service)

      vc_def = LcpRuby::Metadata::VirtualColumnDefinition.new(
        name: "svc_test", service: "test_svc", type: "integer"
      )

      # Should find via aggregates fallback (since not registered in virtual_columns)
      model_def = project_model_def
      conn = ActiveRecord::Base.connection

      # Calling build_service_subquery privately via send
      result = described_class.send(:build_service_subquery, vc_def, model_def, conn)
      # Service doesn't have sql_expression, so returns nil (per-record computation)
      expect(result).to be_nil
    end
  end
end
