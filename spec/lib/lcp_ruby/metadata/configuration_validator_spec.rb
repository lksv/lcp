require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe LcpRuby::Metadata::ConfigurationValidator do
  let(:loader) { LcpRuby::Metadata::Loader.new(metadata_path) }
  let(:validator) { described_class.new(loader) }

  before { loader.load_all }

  # Helper to create a temporary metadata directory with YAML files
  def create_metadata(models: [], presenters: [], permissions: [], view_groups: [], menu: nil)
    dir = Dir.mktmpdir("lcp_test")
    %w[models presenters permissions views].each { |d| FileUtils.mkdir_p(File.join(dir, d)) }

    models.each_with_index do |yaml, i|
      File.write(File.join(dir, "models", "model_#{i}.yml"), yaml)
    end
    presenters.each_with_index do |yaml, i|
      File.write(File.join(dir, "presenters", "presenter_#{i}.yml"), yaml)
    end
    permissions.each_with_index do |yaml, i|
      File.write(File.join(dir, "permissions", "perm_#{i}.yml"), yaml)
    end
    view_groups.each_with_index do |yaml, i|
      File.write(File.join(dir, "views", "vg_#{i}.yml"), yaml)
    end
    File.write(File.join(dir, "menu.yml"), menu) if menu

    dir
  end

  after do
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  def with_metadata(**opts)
    @tmpdir = create_metadata(**opts)
    loader = LcpRuby::Metadata::Loader.new(@tmpdir)
    loader.load_all
    described_class.new(loader)
  end

  # --- Valid configuration (existing fixtures) ---

  context "with valid fixtures" do
    let(:metadata_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

    it "returns valid result" do
      result = validator.validate
      expect(result).to be_valid
      expect(result.errors).to be_empty
    end

    it "produces a readable summary" do
      result = validator.validate
      expect(result.to_s).to include("valid")
    end
  end

  # --- Association validations ---

  context "association target_model does not exist" do
    let(:metadata_path) { "" } # overridden by with_metadata

    it "reports error for unknown target_model" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: order
            fields:
              - { name: title, type: string }
            associations:
              - type: belongs_to
                name: customer
                target_model: customer
                foreign_key: customer_id
        YAML
      )

      result = v.validate
      expect(result).not_to be_valid
      expect(result.errors).to include(
        a_string_matching(/target_model 'customer' does not exist/)
      )
    end
  end

  context "association reciprocity" do
    let(:metadata_path) { "" }

    it "warns when belongs_to has no inverse has_many" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: title, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ]
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/no corresponding has_many\/has_one found on model 'project'/)
      )
    end

    it "does not warn when inverse exists" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
                  foreign_key: project_id
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: title, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ]
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end
  end

  # --- Enum validations ---

  context "enum field validations" do
    let(:metadata_path) { "" }

    it "reports error when enum has no values" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - name: priority
                type: enum
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/enum type requires enum_values/)
      )
    end

    it "reports error when default is not in enum_values" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - name: priority
                type: enum
                enum_values:
                  - { value: low, label: "Low" }
                  - { value: high, label: "High" }
                default: critical
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default value 'critical' is not in enum_values/)
      )
    end

    it "passes when default is in enum_values" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - name: priority
                type: enum
                enum_values:
                  - { value: low, label: "Low" }
                  - { value: high, label: "High" }
                default: low
        YAML
      )

      result = v.validate
      enum_errors = result.errors.select { |e| e.include?("enum") }
      expect(enum_errors).to be_empty
    end
  end

  # --- Event validations ---

  context "event field_change references unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: order
            fields:
              - { name: title, type: string }
            events:
              - name: on_nonexistent_change
                type: field_change
                field: nonexistent_field
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field_change references unknown field 'nonexistent_field'/)
      )
    end
  end

  # --- Presenter validations ---

  context "presenter references unknown model" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      # The Loader's own validate_references raises before the validator runs.
      # This test confirms that protection layer works.
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ]
            presenter:
              name: ghost
              model: ghost
              slug: ghosts
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown model/)
    end
  end

  context "presenter table_columns reference unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
                - { field: nonexistent_col }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown field 'nonexistent_col'/)
      )
    end
  end

  context "presenter form references unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Info"
                  fields:
                    - { field: bad_field }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/form:.*references unknown field 'bad_field'/)
      )
    end
  end

  context "presenter predefined_filters reference unknown scope" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
            scopes:
              - name: active
                where: { title: "x" }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            search:
              enabled: true
              predefined_filters:
                - { name: missing, label: "Missing", scope: nonexistent_scope }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown scope 'nonexistent_scope'/)
      )
    end
  end

  # --- Permission validations ---

  context "permission references unknown CRUD action" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show, invent]
                fields: { readable: all, writable: all }
            default_role: admin
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown CRUD action 'invent'/)
      )
    end
  end

  context "permission references unknown presenter" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show]
                fields: { readable: all, writable: all }
                presenters: [ghost_presenter]
            default_role: admin
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown presenter 'ghost_presenter'/)
      )
    end
  end

  context "permission record_rules reference unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: test_rule
                condition: { field: ghost_field, operator: eq, value: x }
                effect:
                  deny_crud: [update]
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/condition references unknown field 'ghost_field'/)
      )
    end
  end

  context "permission record_rules use unknown operator" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: test_rule
                condition: { field: title, operator: fuzzy_match, value: x }
                effect:
                  deny_crud: [show]
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown operator 'fuzzy_match'/)
      )
    end
  end

  # --- Uniqueness validations ---

  context "duplicate presenter slugs" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: projects
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/Duplicate slug 'projects'/)
      )
    end
  end

  context "duplicate table names" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: item
              table_name: products
              fields:
                - { name: title, type: string }
          YAML
          <<~YAML
            model:
              name: product
              table_name: products
              fields:
                - { name: name, type: string }
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/Duplicate table_name 'products'/)
      )
    end
  end

  # --- Polymorphic association validations ---

  context "polymorphic belongs_to" do
    let(:metadata_path) { "" }

    it "does not error when polymorphic belongs_to has no target_model" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
      )

      result = v.validate
      expect(result).to be_valid
    end

    it "does not warn about missing reciprocity for polymorphic belongs_to" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end

    it "does not warn about missing reciprocity for has_many with as" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: post
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: comments
                  target_model: comment
                  as: commentable
          YAML
          <<~YAML
            model:
              name: comment
              fields:
                - { name: body, type: text }
              associations:
                - type: belongs_to
                  name: commentable
                  polymorphic: true
                  required: false
          YAML
        ]
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end
  end

  # --- Through association validations ---

  context "through associations" do
    let(:metadata_path) { "" }

    it "does not warn about reciprocity for through associations" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: post
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: taggings
                  target_model: tagging
                - type: has_many
                  name: tags
                  target_model: tag
                  through: taggings
          YAML
          <<~YAML,
            model:
              name: tagging
              fields: []
              associations:
                - type: belongs_to
                  name: post
                  target_model: post
                - type: belongs_to
                  name: tag
                  target_model: tag
          YAML
          <<~YAML
            model:
              name: tag
              fields:
                - { name: label, type: string }
              associations:
                - type: has_many
                  name: taggings
                  target_model: tagging
          YAML
        ]
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end

    it "errors when through references non-existent association" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: post
            fields:
              - { name: title, type: string }
            associations:
              - type: has_many
                name: tags
                through: nonexistent
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/through 'nonexistent' does not match any association/)
      )
    end

    it "passes when through references existing association" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: post
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: taggings
                  target_model: tagging
                - type: has_many
                  name: tags
                  through: taggings
          YAML
          <<~YAML
            model:
              name: tagging
              fields: []
              associations:
                - type: belongs_to
                  name: post
                  target_model: post
          YAML
        ]
      )

      result = v.validate
      through_errors = result.errors.select { |e| e.include?("through") }
      expect(through_errors).to be_empty
    end
  end

  # --- View group validations ---
  # Note: Structural errors (unknown model/presenter, presenter in multiple groups,
  # primary not in views list) are caught by Loader.validate_references at load time,
  # before the ConfigurationValidator runs. Those are tested in loader_view_groups_spec.
  # The ConfigurationValidator adds position uniqueness warnings.

  context "view group references unknown model" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ]
            view_group:
              name: bad_group
              model: nonexistent
              primary: project
              views:
                - presenter: project
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown model/)
    end
  end

  context "view group references unknown presenter" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ]
            view_group:
              name: bad_group
              model: project
              primary: project
              views:
                - presenter: project
                - presenter: ghost_presenter
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown presenter/)
    end
  end

  context "presenter in multiple view groups" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [
            <<~YAML,
              presenter:
                name: project
                model: project
                slug: projects
            YAML
            <<~YAML
              presenter:
                name: project_public
                model: project
                slug: public-projects
            YAML
          ],
          view_groups: [
            <<~YAML,
              view_group:
                name: group_a
                model: project
                primary: project
                views:
                  - presenter: project
            YAML
            <<~YAML
              view_group:
                name: group_b
                model: project
                primary: project_public
                views:
                  - presenter: project_public
                  - presenter: project
            YAML
          ]
        )
      }.to raise_error(LcpRuby::MetadataError, /multiple view groups/)
    end
  end

  context "view group primary not in views list" do
    let(:metadata_path) { "" }

    it "is caught by ViewGroupDefinition.validate! at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [
            <<~YAML,
              presenter:
                name: project
                model: project
                slug: projects
            YAML
            <<~YAML
              presenter:
                name: project_public
                model: project
                slug: public-projects
            YAML
          ],
          view_groups: [ <<~YAML ]
            view_group:
              name: bad_primary
              model: project
              primary: project_public
              views:
                - presenter: project
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /primary presenter 'project_public'.*not in the views list/)
    end
  end

  context "view group duplicate navigation positions" do
    let(:metadata_path) { "" }

    it "warns about duplicate positions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [
          <<~YAML,
            view_group:
              name: group_a
              model: project
              primary: project
              navigation:
                menu: main
                position: 1
              views:
                - presenter: project
          YAML
          <<~YAML
            view_group:
              name: group_b
              model: project
              primary: project_public
              navigation:
                menu: main
                position: 1
              views:
                - presenter: project_public
          YAML
        ]
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/navigation position 1.*also used by/)
      )
    end
  end

  context "valid view group configuration" do
    let(:metadata_path) { "" }

    it "passes validation" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [ <<~YAML ]
          view_group:
            name: projects
            model: project
            primary: project
            navigation:
              menu: main
              position: 1
            views:
              - presenter: project
                label: "Admin"
              - presenter: project_public
                label: "Public"
        YAML
      )

      result = v.validate
      vg_errors = result.errors.select { |e| e.include?("View group") || e.include?("view group") }
      expect(vg_errors).to be_empty
    end
  end

  # --- Polymorphic _type in presenter/permission fields ---

  context "polymorphic _type field in presenter" do
    let(:metadata_path) { "" }

    it "accepts commentable_type as valid presenter field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: comments
            model: comment
            slug: comments
            index:
              table_columns:
                - { field: body }
                - { field: commentable_id }
                - { field: commentable_type }
        YAML
      )

      result = v.validate
      type_errors = result.errors.select { |e| e.include?("commentable_type") }
      expect(type_errors).to be_empty
    end

    it "still reports error for truly unknown fields on polymorphic model" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: comments
            model: comment
            slug: comments
            index:
              table_columns:
                - { field: nonexistent }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown field 'nonexistent'/)
      )
    end
  end

  # --- Scope field validations ---

  context "scope references unknown field" do
    let(:metadata_path) { "" }

    it "warns about unknown where field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            scopes:
              - name: active
                where: { ghost_field: "active" }
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/scope 'active':.*unknown field 'ghost_field'/)
      )
    end
  end

  # --- Virtual field validations ---

  context "virtual field with service accessor" do
    let(:metadata_path) { "" }

    it "errors when accessor service column references non-existent field" do
      LcpRuby::Services::Registry.register("accessors", "json_field", ->(_r, _f) {})

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: product
            fields:
              - { name: title, type: string }
              - name: color
                type: string
                source:
                  service: json_field
                  options:
                    column: nonexistent
                    key: color
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/source references column 'nonexistent' which is not a defined field/)
      )
    ensure
      LcpRuby::Services::Registry.clear!
    end

    it "warns when virtual field has transforms" do
      LcpRuby::Services::Registry.register("accessors", "json_field", ->(_r, _f) {})

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: product
            fields:
              - { name: title, type: string }
              - { name: data, type: json }
              - name: color
                type: string
                transforms: [strip]
                source:
                  service: json_field
                  options:
                    column: data
                    key: color
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/transforms are ignored on virtual fields/)
      )
    ensure
      LcpRuby::Services::Registry.clear!
    end

    it "passes for valid virtual field configuration" do
      LcpRuby::Services::Registry.register("accessors", "json_field", ->(_r, _f) {})

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: product
            fields:
              - { name: title, type: string }
              - { name: data, type: json }
              - name: color
                type: string
                source:
                  service: json_field
                  options:
                    column: data
                    key: color
        YAML
      )

      result = v.validate
      virtual_errors = result.errors.select { |e| e.include?("accessor") || e.include?("virtual") }
      expect(virtual_errors).to be_empty
    ensure
      LcpRuby::Services::Registry.clear!
    end
  end

  # --- CRM integration fixtures (complex, multi-model) ---

  context "with CRM integration fixtures" do
    let(:metadata_path) { File.expand_path("../../../fixtures/integration/crm", __dir__) }
    let(:loader) do
      LcpRuby::Types::BuiltInTypes.register_all!
      LcpRuby::Metadata::Loader.new(metadata_path)
    end

    it "validates without errors" do
      result = validator.validate
      expect(result).to be_valid
    end
  end

  # --- Condition validation ---

  context "condition with invalid regex pattern" do
    let(:metadata_path) { "" }

    it "reports error for invalid regex in matches operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: code, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                    - field: code
                      visible_when: { field: title, operator: matches, value: "[invalid" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/invalid regex pattern '\[invalid'/)
      )
    end

    it "accepts valid regex in matches operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: code, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                    - field: code
                      visible_when: { field: title, operator: matches, value: "^[A-Z]+$" }
        YAML
      )

      result = v.validate
      regex_errors = result.errors.select { |e| e.include?("regex") }
      expect(regex_errors).to be_empty
    end
  end

  context "condition validation on fields and sections" do
    let(:metadata_path) { "" }

    it "reports error for unknown field in field-level disable_when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      disable_when: { field: ghost_field, operator: eq, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/disable_when.*references unknown field 'ghost_field'/)
      )
    end

    it "reports error for unknown field in section-level visible_when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  visible_when: { field: nonexistent, operator: eq, value: x }
                  fields:
                    - { field: title }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/section 'Details', visible_when.*references unknown field 'nonexistent'/)
      )
    end

    it "accepts valid visible_when on show section" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Metrics"
                  visible_when: { field: status, operator: not_eq, value: draft }
                  fields:
                    - { field: title }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(condition_errors).to be_empty
    end

    it "reports error for unknown field in show section visible_when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Metrics"
                  visible_when: { field: nonexistent, operator: eq, value: x }
                  fields:
                    - { field: title }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/section 'Metrics', visible_when.*references unknown field 'nonexistent'/)
      )
    end

    it "reports error for unknown field in association_list visible_when" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: project
            fields:
              - { name: title, type: string }
            associations:
              - { type: has_many, name: tasks, target_model: task }
        YAML
          model:
            name: task
            fields:
              - { name: name, type: string }
            associations:
              - { type: belongs_to, name: project, target_model: project }
        YAML2
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Tasks"
                  type: association_list
                  association: tasks
                  visible_when: { field: ghost_field, operator: eq, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/section 'Tasks', visible_when.*references unknown field 'ghost_field'/)
      )
    end

    it "reports error for action disable_when with unknown operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            actions:
              single:
                - name: close
                  type: custom
                  disable_when: { field: title, operator: fuzzy_match, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/disable_when.*uses unknown operator 'fuzzy_match'/)
      )
    end

    it "skips validation for service conditions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { service: some_service }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("visible_when") || e.include?("disable_when") }
      expect(condition_errors).to be_empty
    end
  end

  # --- Display template validations ---

  context "display template references unknown field" do
    let(:metadata_path) { "" }

    it "warns about unknown field in template placeholder" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            display_templates:
              default:
                template: "{title} - {nonexistent}"
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/display template 'default'.*unknown field 'nonexistent'/)
      )
    end

    it "does not warn for valid field references" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            display_templates:
              default:
                template: "{title}"
                subtitle: "{created_at}"
        YAML
      )

      result = v.validate
      template_warnings = result.warnings.select { |w| w.include?("display template") }
      expect(template_warnings).to be_empty
    end

    it "skips dot-path references in templates" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            display_templates:
              default:
                template: "{title} ({category.name})"
        YAML
      )

      result = v.validate
      template_warnings = result.warnings.select { |w| w.include?("display template") }
      expect(template_warnings).to be_empty
    end
  end

  # --- Nested fields association validation ---

  context "nested_fields references unknown association" do
    let(:metadata_path) { "" }

    it "reports error for unknown association" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Tasks"
                  type: nested_fields
                  association: tasks
                  fields:
                    - { field: name }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested_fields references unknown association 'tasks'/)
      )
    end

    it "passes when association exists" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: name, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Tasks"
                  type: nested_fields
                  association: tasks
                  fields:
                    - { field: name }
        YAML
      )

      result = v.validate
      nested_errors = result.errors.select { |e| e.include?("nested_fields") }
      expect(nested_errors).to be_empty
    end
  end

  # --- Association list section validation ---

  context "association_list references unknown association" do
    let(:metadata_path) { "" }

    it "reports error for unknown association" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Comments"
                  type: association_list
                  association: comments
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/association_list references unknown association 'comments'/)
      )
    end

    it "passes when association exists" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: comments
                  target_model: comment
          YAML
          <<~YAML
            model:
              name: comment
              fields:
                - { name: body, type: text }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Comments"
                  type: association_list
                  association: comments
        YAML
      )

      result = v.validate
      assoc_errors = result.errors.select { |e| e.include?("association_list") }
      expect(assoc_errors).to be_empty
    end
  end

  # --- Default sort validation ---

  context "presenter default_sort" do
    let(:metadata_path) { "" }

    it "reports error for unknown sort field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              default_sort:
                field: nonexistent
                direction: asc
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default_sort.*unknown field 'nonexistent'/)
      )
    end

    it "reports error for invalid direction" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              default_sort:
                field: title
                direction: upward
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default_sort.*invalid direction 'upward'/)
      )
    end

    it "passes with valid sort config" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              default_sort:
                field: created_at
                direction: desc
        YAML
      )

      result = v.validate
      sort_errors = result.errors.select { |e| e.include?("default_sort") }
      expect(sort_errors).to be_empty
    end
  end

  # --- Includes/eager_load validation ---

  context "presenter includes references unknown association" do
    let(:metadata_path) { "" }

    it "warns about unknown association in includes" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: name, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              includes: [nonexistent_assoc]
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/index\.includes.*unknown association 'nonexistent_assoc'/)
      )
    end

    it "does not warn for valid association in eager_load" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: name, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Info"
                  fields:
                    - { field: title }
              eager_load: [tasks]
        YAML
      )

      result = v.validate
      includes_warnings = result.warnings.select { |w| w.include?("eager_load") }
      expect(includes_warnings).to be_empty
    end
  end

  # --- Custom action name validation ---

  context "custom action with built-in name" do
    let(:metadata_path) { "" }

    it "warns when custom action uses built-in name" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            actions:
              single:
                - name: destroy
                  type: custom
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/custom action uses built-in name 'destroy'/)
      )
    end

    it "does not warn for properly named custom actions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            actions:
              single:
                - name: archive
                  type: custom
        YAML
      )

      result = v.validate
      action_warnings = result.warnings.select { |w| w.include?("custom action") }
      expect(action_warnings).to be_empty
    end
  end

  # --- Menu validations ---

  context "menu references unknown view group" do
    let(:metadata_path) { "" }

    it "is caught by loader at load time for unknown view group" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ],
            view_group:
              name: projects
              model: project
              primary: project
              views:
                - presenter: project
          YAML
          menu: <<~YAML
            menu:
              top_menu:
                - view_group: projects
                - view_group: nonexistent_group
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown view group/)
    end

    it "is caught by loader at load time for unknown view group in children" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ],
            view_group:
              name: projects
              model: project
              primary: project
              views:
                - presenter: project
          YAML
          menu: <<~YAML
            menu:
              sidebar_menu:
                - label: "Group"
                  children:
                    - view_group: projects
                    - view_group: ghost_group
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown view group/)
    end

    it "passes with valid menu" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: project
            model: project
            slug: projects
        YAML
        view_groups: [ <<~YAML ],
          view_group:
            name: projects
            model: project
            primary: project
            views:
              - presenter: project
        YAML
        menu: <<~YAML
          menu:
            top_menu:
              - view_group: projects
        YAML
      )

      result = v.validate
      menu_errors = result.errors.select { |e| e.include?("Menu") }
      expect(menu_errors).to be_empty
    end
  end

  context "menu visible_when references undefined role" do
    let(:metadata_path) { "" }

    it "warns about undefined role" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: project
            model: project
            slug: projects
        YAML
        permissions: [ <<~YAML ],
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show]
                fields: { readable: all }
            default_role: admin
        YAML
        view_groups: [ <<~YAML ],
          view_group:
            name: projects
            model: project
            primary: project
            views:
              - presenter: project
        YAML
        menu: <<~YAML
          menu:
            top_menu:
              - view_group: projects
                visible_when:
                  role: [admin, superuser]
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/visible_when references undefined role 'superuser'/)
      )
    end
  end

  # --- Custom fields validations ---

  context "custom_fields enabled" do
    let(:metadata_path) { "" }

    it "does not warn about custom_data (auto-added at runtime)" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            options:
              custom_fields: true
        YAML
      )

      result = v.validate
      cf_warnings = result.warnings.select { |w| w.include?("custom_fields") || w.include?("custom_data") }
      expect(cf_warnings).to be_empty
    end
  end

  # --- Positioning validations ---

  context "positioning field not defined" do
    let(:metadata_path) { "" }

    it "reports error when positioning field is missing" do
      v = with_metadata(
        models: [<<~YAML]
          model:
            name: stage
            fields:
              - { name: title, type: string }
            positioning: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning field 'position' is not defined/))
    end
  end

  context "positioning field wrong type" do
    let(:metadata_path) { "" }

    it "reports error when positioning field is not integer" do
      v = with_metadata(
        models: [<<~YAML]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: string }
            positioning: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning field 'position' must be type 'integer'/))
    end
  end

  context "positioning field is virtual" do
    let(:metadata_path) { "" }

    it "reports error when positioning field is virtual" do
      v = with_metadata(
        models: [<<~YAML]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: metadata, type: json }
              - name: position
                type: integer
                source:
                  service: json_field
                  options:
                    column: metadata
                    key: position
            positioning: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning field 'position' cannot be a virtual field/))
    end
  end

  context "positioning scope references unknown field" do
    let(:metadata_path) { "" }

    it "reports error when scope field does not exist" do
      v = with_metadata(
        models: [<<~YAML]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: integer }
            positioning:
              scope: nonexistent_id
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning scope 'nonexistent_id' is not a defined field or FK/))
    end
  end

  context "valid positioning config" do
    let(:metadata_path) { "" }

    it "passes validation with correct positioning config" do
      v = with_metadata(
        models: [<<~YAML]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: integer }
            positioning: true
        YAML
      )

      result = v.validate
      positioning_errors = result.errors.select { |e| e.include?("positioning") }
      expect(positioning_errors).to be_empty
    end
  end

  context "presenter reorderable without model positioning" do
    let(:metadata_path) { "" }

    it "reports error when reorderable is true but model has no positioning" do
      v = with_metadata(
        models: [<<~YAML],
          model:
            name: stage
            fields:
              - { name: title, type: string }
        YAML
        presenters: [<<~YAML]
          presenter:
            name: stages
            model: stage
            slug: stages
            index:
              reorderable: true
              table_columns:
                - { field: title }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/reorderable is true but model 'stage' has no positioning/))
    end
  end

  context "positioning field in form section" do
    let(:metadata_path) { "" }

    it "adds warning when positioning field appears in form" do
      v = with_metadata(
        models: [<<~YAML],
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: integer }
            positioning: true
        YAML
        presenters: [<<~YAML]
          presenter:
            name: stages
            model: stage
            slug: stages
            index:
              reorderable: true
              table_columns:
                - { field: title }
            form:
              sections:
                - title: Details
                  fields:
                    - { field: title }
                    - { field: position }
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(match(/positioning field 'position' appears in a form section/))
    end
  end
end

RSpec.describe LcpRuby::Metadata::ConfigurationValidator::ValidationResult do
  it "is valid when no errors" do
    result = described_class.new(errors: [], warnings: [ "some warning" ])
    expect(result).to be_valid
  end

  it "is not valid when errors exist" do
    result = described_class.new(errors: [ "some error" ], warnings: [])
    expect(result).not_to be_valid
  end

  it "formats output with errors and warnings" do
    result = described_class.new(errors: [ "err1" ], warnings: [ "warn1" ])
    output = result.to_s
    expect(output).to include("[ERROR] err1")
    expect(output).to include("[WARN]  warn1")
  end

  it "shows success message when valid" do
    result = described_class.new(errors: [], warnings: [])
    expect(result.to_s).to include("Configuration is valid.")
  end
end
