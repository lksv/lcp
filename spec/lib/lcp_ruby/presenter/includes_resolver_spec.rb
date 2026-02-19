require "spec_helper"

RSpec.describe LcpRuby::Presenter::IncludesResolver do
  # Shared model definitions used across tests
  let(:company_assoc_hash) do
    {
      "type" => "belongs_to",
      "name" => "company",
      "target_model" => "company",
      "foreign_key" => "company_id"
    }
  end

  let(:contact_assoc_hash) do
    {
      "type" => "belongs_to",
      "name" => "contact",
      "target_model" => "contact",
      "foreign_key" => "contact_id",
      "required" => false
    }
  end

  let(:deals_assoc_hash) do
    {
      "type" => "has_many",
      "name" => "deals",
      "target_model" => "deal",
      "foreign_key" => "company_id",
      "dependent" => "destroy"
    }
  end

  let(:contacts_assoc_hash) do
    {
      "type" => "has_many",
      "name" => "contacts",
      "target_model" => "contact",
      "foreign_key" => "company_id",
      "dependent" => "destroy"
    }
  end

  let(:deal_model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "deal",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "value", "type" => "decimal" }
      ],
      "associations" => [ company_assoc_hash, contact_assoc_hash ]
    )
  end

  let(:company_model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "company",
      "fields" => [
        { "name" => "name", "type" => "string" }
      ],
      "associations" => [ deals_assoc_hash, contacts_assoc_hash ]
    )
  end

  let(:todo_list_model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "todo_list",
      "fields" => [
        { "name" => "title", "type" => "string" }
      ],
      "associations" => [
        {
          "type" => "has_many",
          "name" => "todo_items",
          "target_model" => "todo_item",
          "foreign_key" => "todo_list_id",
          "dependent" => "destroy",
          "nested_attributes" => { "allow_destroy" => true }
        }
      ]
    )
  end

  describe LcpRuby::Presenter::IncludesResolver::AssociationDependency do
    it "creates a dependency with symbol path" do
      dep = described_class.new(path: :company, reason: :display)

      expect(dep.path).to eq(:company)
      expect(dep.reason).to eq(:display)
      expect(dep.association_name).to eq(:company)
      expect(dep).not_to be_nested
      expect(dep).to be_display
      expect(dep).not_to be_query
    end

    it "creates a dependency with hash path" do
      dep = described_class.new(path: { company: :industry }, reason: :query)

      expect(dep.path).to eq({ company: :industry })
      expect(dep.association_name).to eq(:company)
      expect(dep).to be_nested
      expect(dep).to be_query
      expect(dep).not_to be_display
    end

    it "raises on invalid path type" do
      expect {
        described_class.new(path: "company", reason: :display)
      }.to raise_error(ArgumentError, /must be a Symbol or Hash/)
    end

    it "raises on invalid reason" do
      expect {
        described_class.new(path: :company, reason: :invalid)
      }.to raise_error(ArgumentError, /must be one of/)
    end
  end

  describe LcpRuby::Presenter::IncludesResolver::LoadingStrategy do
    it "applies includes, eager_load, and joins to scope" do
      strategy = described_class.new(
        includes: [ :company ],
        eager_load: [ :contact ],
        joins: [ :deals ]
      )

      scope = double("scope")
      expect(scope).to receive(:includes).with(:company).and_return(scope)
      expect(scope).to receive(:eager_load).with(:contact).and_return(scope)
      expect(scope).to receive(:joins).with(:deals).and_return(scope)

      result = strategy.apply(scope)
      expect(result).to eq(scope)
    end

    it "skips empty lists" do
      strategy = described_class.new(includes: [ :company ])

      scope = double("scope")
      expect(scope).to receive(:includes).with(:company).and_return(scope)
      expect(scope).not_to receive(:eager_load)
      expect(scope).not_to receive(:joins)

      strategy.apply(scope)
    end

    it "reports empty? correctly" do
      empty = described_class.new
      expect(empty).to be_empty

      non_empty = described_class.new(includes: [ :company ])
      expect(non_empty).not_to be_empty
    end
  end

  describe LcpRuby::Presenter::IncludesResolver::DependencyCollector do
    subject(:collector) { described_class.new }

    describe "#from_presenter with :index context" do
      it "detects FK columns matching belongs_to associations" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "title" },
              { "field" => "company_id", "display" => "link" }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :index)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:company)
        expect(dep.reason).to eq(:display)
      end

      it "ignores non-FK columns" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "title" },
              { "field" => "value" }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :index)

        expect(collector.dependencies).to be_empty
      end
    end

    describe "#from_presenter with :show context" do
      it "detects association_list sections" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "company",
          "model" => "company",
          "show" => {
            "layout" => [
              {
                "section" => "Details",
                "fields" => [ { "field" => "name" } ]
              },
              {
                "section" => "Deals",
                "type" => "association_list",
                "association" => "deals"
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, company_model_def, :show)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:deals)
        expect(dep.reason).to eq(:display)
      end

      it "detects multiple association_list sections" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "company",
          "model" => "company",
          "show" => {
            "layout" => [
              { "section" => "Contacts", "type" => "association_list", "association" => "contacts" },
              { "section" => "Deals", "type" => "association_list", "association" => "deals" }
            ]
          }
        )

        collector.from_presenter(presenter_def, company_model_def, :show)

        names = collector.dependencies.map(&:association_name)
        expect(names).to contain_exactly(:contacts, :deals)
      end
    end

    describe "#from_presenter with :form context" do
      it "detects nested_fields sections" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "todo_list",
          "model" => "todo_list",
          "form" => {
            "sections" => [
              { "title" => "Details", "fields" => [ { "field" => "title" } ] },
              {
                "title" => "Items",
                "type" => "nested_fields",
                "association" => "todo_items",
                "fields" => [ { "field" => "title" } ]
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, todo_list_model_def, :form)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:todo_items)
        expect(dep.reason).to eq(:display)
      end

      it "ignores association_select fields (those are separate queries)" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "form" => {
            "sections" => [
              {
                "title" => "Details",
                "fields" => [
                  { "field" => "title" },
                  { "field" => "company_id", "input_type" => "association_select" }
                ]
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :form)

        expect(collector.dependencies).to be_empty
      end
    end

    describe "#from_sort" do
      it "creates query dependency for dot-notation field" do
        collector.from_sort("company.name", deal_model_def)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:company)
        expect(dep.reason).to eq(:query)
      end

      it "ignores plain field names" do
        collector.from_sort("title", deal_model_def)

        expect(collector.dependencies).to be_empty
      end

      it "ignores unknown associations" do
        collector.from_sort("nonexistent.name", deal_model_def)

        expect(collector.dependencies).to be_empty
      end
    end

    describe "#from_search" do
      it "creates query dependencies for dot-notation fields" do
        collector.from_search([ "title", "company.name" ], deal_model_def)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:company)
        expect(dep.reason).to eq(:query)
      end

      it "handles multiple dot-notation fields" do
        collector.from_search([ "company.name", "contact.email" ], deal_model_def)

        names = collector.dependencies.map(&:association_name)
        expect(names).to contain_exactly(:company, :contact)
      end
    end

    describe "dot-path and template column detection" do
      it "detects dot-path column as display dependency" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "title" },
              { "field" => "company.name" }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :index)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:company)
        expect(dep.reason).to eq(:display)
      end

      it "detects has_many dot-path column as display dependency" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "company",
          "model" => "company",
          "index" => {
            "table_columns" => [
              { "field" => "name" },
              { "field" => "contacts.first_name" }
            ]
          }
        )

        collector.from_presenter(presenter_def, company_model_def, :index)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:contacts)
        expect(dep.reason).to eq(:display)
      end

      it "detects template with dot-path as dependency" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "{company.name}: {title}" }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :index)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:company)
      end

      it "ignores template refs without dot-path" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "{title} ({value})" }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :index)

        expect(collector.dependencies).to be_empty
      end
    end

    describe "dot-path in show fields" do
      it "detects dot-path fields in show layout sections" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal",
          "model" => "deal",
          "show" => {
            "layout" => [
              {
                "section" => "Details",
                "fields" => [
                  { "field" => "title" },
                  { "field" => "company.name" }
                ]
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, deal_model_def, :show)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.association_name).to eq(:company)
        expect(dep.reason).to eq(:display)
      end
    end

    describe "nested eager loading from display templates" do
      let(:contact_model_def) do
        LcpRuby::Metadata::ModelDefinition.from_hash(
          "name" => "contact",
          "fields" => [
            { "name" => "first_name", "type" => "string" },
            { "name" => "last_name", "type" => "string" },
            { "name" => "position", "type" => "string" }
          ],
          "associations" => [
            { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" }
          ],
          "display_templates" => {
            "default" => {
              "template" => "{first_name} {last_name}",
              "subtitle" => "{position} at {company.name}"
            },
            "compact" => {
              "template" => "{last_name}, {first_name}"
            }
          }
        )
      end

      before do
        loader = instance_double(LcpRuby::Metadata::Loader)
        allow(LcpRuby).to receive(:loader).and_return(loader)
        allow(loader).to receive(:model_definition).with("contact").and_return(contact_model_def)
        allow(loader).to receive(:model_definition).with("deal").and_raise(LcpRuby::MetadataError, "not found")
      end

      it "detects nested includes from display template dot-paths" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "company_admin",
          "model" => "company",
          "show" => {
            "layout" => [
              {
                "section" => "Contacts",
                "type" => "association_list",
                "association" => "contacts",
                "display" => "default"
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, company_model_def, :show)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.path).to eq({ contacts: [ :company ] })
        expect(dep.reason).to eq(:display)
      end

      it "falls back to simple include when template has no dot-paths" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "company_admin",
          "model" => "company",
          "show" => {
            "layout" => [
              {
                "section" => "Contacts",
                "type" => "association_list",
                "association" => "contacts",
                "display" => "compact"
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, company_model_def, :show)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.path).to eq(:contacts)
      end

      it "falls back to simple include when target model has no display templates" do
        presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "company_admin",
          "model" => "company",
          "show" => {
            "layout" => [
              {
                "section" => "Deals",
                "type" => "association_list",
                "association" => "deals"
              }
            ]
          }
        )

        collector.from_presenter(presenter_def, company_model_def, :show)

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.path).to eq(:deals)
      end
    end

    describe "#from_manual" do
      it "reads includes as display dependencies" do
        collector.from_manual("includes" => [ "company" ])

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.path).to eq(:company)
        expect(dep.reason).to eq(:display)
      end

      it "reads eager_load as query dependencies" do
        collector.from_manual("eager_load" => [ "company" ])

        expect(collector.dependencies.size).to eq(1)
        dep = collector.dependencies.first
        expect(dep.path).to eq(:company)
        expect(dep.reason).to eq(:query)
      end

      it "handles nested hash paths" do
        collector.from_manual("includes" => [ { "company" => "industry" } ])

        dep = collector.dependencies.first
        expect(dep.path).to eq({ company: :industry })
        expect(dep).to be_nested
      end

      it "does not duplicate identical dependencies" do
        collector.from_manual("includes" => [ "company", "company" ])

        expect(collector.dependencies.size).to eq(1)
      end
    end
  end

  describe LcpRuby::Presenter::IncludesResolver::StrategyResolver do
    it "maps belongs_to + display to includes" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :company, reason: :display)
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      expect(strategy.includes).to eq([ :company ])
      expect(strategy.eager_load).to be_empty
      expect(strategy.joins).to be_empty
    end

    it "maps belongs_to + query to eager_load" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :company, reason: :query)
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      expect(strategy.eager_load).to eq([ :company ])
      expect(strategy.includes).to be_empty
      expect(strategy.joins).to be_empty
    end

    it "maps has_many + display to includes" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :deals, reason: :display)
      ]

      strategy = described_class.resolve(deps, company_model_def)

      expect(strategy.includes).to eq([ :deals ])
      expect(strategy.eager_load).to be_empty
      expect(strategy.joins).to be_empty
    end

    it "maps has_many + query to joins + includes" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :deals, reason: :query)
      ]

      strategy = described_class.resolve(deps, company_model_def)

      expect(strategy.joins).to eq([ :deals ])
      expect(strategy.includes).to eq([ :deals ])
      expect(strategy.eager_load).to be_empty
    end

    it "combines display and query for same belongs_to into eager_load" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :company, reason: :display),
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :company, reason: :query)
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      expect(strategy.eager_load).to eq([ :company ])
      expect(strategy.includes).to be_empty
    end

    it "handles multiple associations of different types" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :contacts, reason: :display),
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :deals, reason: :query)
      ]

      strategy = described_class.resolve(deps, company_model_def)

      expect(strategy.includes).to contain_exactly(:contacts, :deals)
      expect(strategy.joins).to eq([ :deals ])
    end

    it "ignores unknown associations" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :nonexistent, reason: :display)
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      expect(strategy).to be_empty
    end

    it "merges multiple nested paths for the same association" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(
          path: { company: :industry }, reason: :display
        ),
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(
          path: { company: :address }, reason: :display
        )
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      expect(strategy.includes).to eq([ { company: [ :industry, :address ] } ])
    end

    it "keeps single nested path without wrapping in array" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(
          path: { company: :industry }, reason: :display
        )
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      expect(strategy.includes).to eq([ { company: :industry } ])
    end

    it "merges nested path with simple path for same association" do
      deps = [
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(path: :company, reason: :display),
        LcpRuby::Presenter::IncludesResolver::AssociationDependency.new(
          path: { company: :industry }, reason: :display
        )
      ]

      strategy = described_class.resolve(deps, deal_model_def)

      # Nested path wins: { company: :industry } covers simple :company too
      expect(strategy.includes).to eq([ { company: :industry } ])
    end
  end

  describe ".resolve" do
    it "integrates all collectors into a single strategy" do
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "deal",
        "model" => "deal",
        "index" => {
          "table_columns" => [
            { "field" => "title" },
            { "field" => "company_id", "display" => "link" }
          ]
        }
      )

      strategy = described_class.resolve(
        presenter_def: presenter_def,
        model_def: deal_model_def,
        context: :index
      )

      expect(strategy.includes).to eq([ :company ])
      expect(strategy).not_to be_empty
    end

    it "combines auto-detected and sort dependencies" do
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "deal",
        "model" => "deal",
        "index" => {
          "table_columns" => [
            { "field" => "title" },
            { "field" => "company_id" }
          ]
        }
      )

      strategy = described_class.resolve(
        presenter_def: presenter_def,
        model_def: deal_model_def,
        context: :index,
        sort_field: "company.name"
      )

      # company_id column -> display dep, company.name sort -> query dep
      # belongs_to + query upgrades to eager_load
      expect(strategy.eager_load).to eq([ :company ])
    end

    it "returns empty strategy when no associations needed" do
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "deal",
        "model" => "deal",
        "index" => {
          "table_columns" => [
            { "field" => "title" },
            { "field" => "value" }
          ]
        }
      )

      strategy = described_class.resolve(
        presenter_def: presenter_def,
        model_def: deal_model_def,
        context: :index
      )

      expect(strategy).to be_empty
    end

    it "resolves show context with association_list" do
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "company",
        "model" => "company",
        "show" => {
          "layout" => [
            { "section" => "Details", "fields" => [ { "field" => "name" } ] },
            { "section" => "Deals", "type" => "association_list", "association" => "deals" },
            { "section" => "Contacts", "type" => "association_list", "association" => "contacts" }
          ]
        }
      )

      strategy = described_class.resolve(
        presenter_def: presenter_def,
        model_def: company_model_def,
        context: :show
      )

      expect(strategy.includes).to contain_exactly(:deals, :contacts)
    end

    it "resolves form context with nested_fields" do
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "todo_list",
        "model" => "todo_list",
        "form" => {
          "sections" => [
            { "title" => "Details", "fields" => [ { "field" => "title" } ] },
            {
              "title" => "Items",
              "type" => "nested_fields",
              "association" => "todo_items",
              "fields" => [ { "field" => "title" } ]
            }
          ]
        }
      )

      strategy = described_class.resolve(
        presenter_def: presenter_def,
        model_def: todo_list_model_def,
        context: :form
      )

      expect(strategy.includes).to eq([ :todo_items ])
    end

    it "includes manual overrides from config" do
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "deal",
        "model" => "deal",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "includes" => [ "contact" ]
        }
      )

      strategy = described_class.resolve(
        presenter_def: presenter_def,
        model_def: deal_model_def,
        context: :index
      )

      expect(strategy.includes).to eq([ :contact ])
    end
  end
end
