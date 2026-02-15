require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe LcpRuby::Metadata::ConfigurationValidator do
  let(:loader) { LcpRuby::Metadata::Loader.new(metadata_path) }
  let(:validator) { described_class.new(loader) }

  before { loader.load_all }

  # Helper to create a temporary metadata directory with YAML files
  def create_metadata(models: [], presenters: [], permissions: [])
    dir = Dir.mktmpdir("lcp_test")
    %w[models presenters permissions].each { |d| FileUtils.mkdir_p(File.join(dir, d)) }

    models.each_with_index do |yaml, i|
      File.write(File.join(dir, "models", "model_#{i}.yml"), yaml)
    end
    presenters.each_with_index do |yaml, i|
      File.write(File.join(dir, "presenters", "presenter_#{i}.yml"), yaml)
    end
    permissions.each_with_index do |yaml, i|
      File.write(File.join(dir, "permissions", "perm_#{i}.yml"), yaml)
    end

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
        models: [<<~YAML]
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
        models: [<<~YAML]
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
        models: [<<~YAML]
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
        models: [<<~YAML]
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
        models: [<<~YAML]
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
          models: [<<~YAML],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [<<~YAML]
            presenter:
              name: ghost_admin
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [<<~YAML]
          presenter:
            name: project_admin
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [<<~YAML]
          presenter:
            name: project_admin
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
            scopes:
              - name: active
                where: { title: "x" }
        YAML
        presenters: [<<~YAML]
          presenter:
            name: project_admin
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [<<~YAML]
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [<<~YAML]
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [<<~YAML]
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [<<~YAML]
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
        models: [<<~YAML],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project_admin
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
        models: [<<~YAML]
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
        models: [<<~YAML]
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
        models: [<<~YAML]
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

  # --- Polymorphic _type in presenter/permission fields ---

  context "polymorphic _type field in presenter" do
    let(:metadata_path) { "" }

    it "accepts commentable_type as valid presenter field" do
      v = with_metadata(
        models: [<<~YAML],
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
        presenters: [<<~YAML]
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
        models: [<<~YAML],
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
        presenters: [<<~YAML]
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
        models: [<<~YAML]
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

  # --- CRM integration fixtures (complex, multi-model) ---

  context "with CRM integration fixtures" do
    let(:metadata_path) { File.expand_path("../../../fixtures/integration/crm", __dir__) }

    it "validates without errors" do
      result = validator.validate
      expect(result).to be_valid
    end
  end

end

RSpec.describe LcpRuby::Metadata::ConfigurationValidator::ValidationResult do
  it "is valid when no errors" do
    result = described_class.new(errors: [], warnings: ["some warning"])
    expect(result).to be_valid
  end

  it "is not valid when errors exist" do
    result = described_class.new(errors: ["some error"], warnings: [])
    expect(result).not_to be_valid
  end

  it "formats output with errors and warnings" do
    result = described_class.new(errors: ["err1"], warnings: ["warn1"])
    output = result.to_s
    expect(output).to include("[ERROR] err1")
    expect(output).to include("[WARN]  warn1")
  end

  it "shows success message when valid" do
    result = described_class.new(errors: [], warnings: [])
    expect(result.to_s).to include("Configuration is valid.")
  end
end
