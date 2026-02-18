require "yaml"

module LcpRuby
  module Metadata
    class Loader
      attr_reader :base_path, :model_definitions, :presenter_definitions,
                  :permission_definitions, :view_group_definitions

      def initialize(base_path)
        @base_path = Pathname.new(base_path)
        @model_definitions = {}
        @presenter_definitions = {}
        @permission_definitions = {}
        @view_group_definitions = {}
      end

      def load_all
        load_types
        load_models
        load_presenters
        load_permissions
        load_view_groups
        validate_references
        auto_create_view_groups
      end

      def load_types
        load_yamls("types") do |data, file_path|
          type_data = data["type"] || raise(MetadataError, "Missing 'type' key in #{file_path}")
          type_def = Types::TypeDefinition.from_hash(type_data)
          Types::TypeRegistry.register(type_def.name, type_def)
        end

        load_dsl_types("types")
      end

      def load_models
        load_yamls("models") do |data, file_path|
          model_data = data["model"] || raise(MetadataError, "Missing 'model' key in #{file_path}")
          definition = ModelDefinition.from_hash(model_data)
          @model_definitions[definition.name] = definition
        end

        load_dsl_models("models")
      end

      def load_presenters
        load_yamls("presenters") do |data, file_path|
          presenter_data = data["presenter"] || raise(MetadataError, "Missing 'presenter' key in #{file_path}")
          definition = PresenterDefinition.from_hash(presenter_data)
          @presenter_definitions[definition.name] = definition
        end

        load_dsl_presenters("presenters")
      end

      def load_permissions
        load_yamls("permissions") do |data, file_path|
          permission_data = data["permissions"] || raise(MetadataError, "Missing 'permissions' key in #{file_path}")
          definition = PermissionDefinition.from_hash(permission_data)
          @permission_definitions[definition.model] = definition
        end
      end

      def load_view_groups
        @view_group_definitions = {}

        load_yamls("views") do |data, file_path|
          vg_data = data["view_group"] || raise(MetadataError, "Missing 'view_group' key in #{file_path}")
          # Inject file-based name if not present
          vg_data["name"] ||= File.basename(file_path, ".*")
          definition = ViewGroupDefinition.from_hash({ "view_group" => vg_data })
          @view_group_definitions[definition.name] = definition
        end

        load_dsl_view_groups("views")
      end

      def view_groups_for_model(model_name)
        @view_group_definitions.values.select { |vg| vg.model == model_name.to_s }
      end

      def view_group_for_presenter(presenter_name)
        @view_group_definitions.values.find { |vg| vg.presenter_names.include?(presenter_name.to_s) }
      end

      def model_definition(name)
        @model_definitions[name.to_s] || raise(MetadataError, "Model '#{name}' not found")
      end

      def presenter_definition(name)
        @presenter_definitions[name.to_s] || raise(MetadataError, "Presenter '#{name}' not found")
      end

      def permission_definition(model_name)
        @permission_definitions[model_name.to_s] || @permission_definitions["_default"]
      end

      private

      def load_yamls(subdirectory)
        dir = base_path.join(subdirectory)
        return unless dir.exist?

        Dir[dir.join("*.yml"), dir.join("*.yaml")].sort.each do |file_path|
          data = YAML.safe_load_file(file_path, permitted_classes: [ Symbol, Regexp ])
          next unless data

          yield(data, file_path)
        rescue Psych::SyntaxError => e
          raise MetadataError, "YAML syntax error in #{file_path}: #{e.message}"
        end
      end

      def load_dsl_types(subdirectory)
        dir = base_path.join(subdirectory)
        Dsl::DslLoader.load_types(dir).each do |name, type_def|
          if Types::TypeRegistry.registered?(name)
            raise MetadataError,
              "Duplicate type '#{name}' — already loaded, conflict in DSL files"
          end
          Types::TypeRegistry.register(name, type_def)
        end
      end

      def load_dsl_models(subdirectory)
        dir = base_path.join(subdirectory)
        dsl_definitions = Dsl::DslLoader.load_models(dir)
        dsl_definitions.each do |name, definition|
          register_model_definition!(definition, dir.join("#{name}.rb"))
        end
      end

      def register_model_definition!(definition, source_path)
        if @model_definitions.key?(definition.name)
          raise MetadataError,
            "Duplicate model '#{definition.name}' — already loaded, conflict at #{source_path}"
        end
        @model_definitions[definition.name] = definition
      end

      def load_dsl_presenters(subdirectory)
        dir = base_path.join(subdirectory)
        dsl_definitions = Dsl::DslLoader.load_presenters(dir)
        dsl_definitions.each do |name, definition|
          register_presenter_definition!(definition, dir.join("#{name}.rb"))
        end
      end

      def register_presenter_definition!(definition, source_path)
        if @presenter_definitions.key?(definition.name)
          raise MetadataError,
            "Duplicate presenter '#{definition.name}' — already loaded, conflict at #{source_path}"
        end
        @presenter_definitions[definition.name] = definition
      end

      def register_view_group_definition!(definition, source_path)
        if @view_group_definitions.key?(definition.name)
          raise MetadataError,
            "Duplicate view group '#{definition.name}' — already loaded, conflict at #{source_path}"
        end
        @view_group_definitions[definition.name] = definition
      end

      def load_dsl_view_groups(subdirectory)
        dir = base_path.join(subdirectory)
        dsl_definitions = Dsl::DslLoader.load_view_groups(dir)
        dsl_definitions.each do |name, definition|
          register_view_group_definition!(definition, dir.join("#{name}.rb"))
        end
      end

      def auto_create_view_groups
        # Group presenters by model
        presenters_by_model = {}
        @presenter_definitions.each_value do |presenter|
          (presenters_by_model[presenter.model] ||= []) << presenter
        end

        presenters_by_model.each do |model_name, presenters|
          # Skip if an explicit view group already covers this model
          next if view_groups_for_model(model_name).any?
          # Only auto-create if exactly one presenter for this model
          next unless presenters.length == 1

          presenter = presenters.first
          vg = ViewGroupDefinition.new(
            name: "#{model_name}_auto",
            model: model_name,
            primary_presenter: presenter.name,
            navigation_config: { "menu" => "main", "position" => 99 },
            views: [ { "presenter" => presenter.name, "label" => presenter.label } ]
          )
          @view_group_definitions[vg.name] = vg

          Rails.logger.info("Auto-created view group for model '#{model_name}' with presenter '#{presenter.name}'") if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        end
      end

      def validate_references
        @presenter_definitions.each_value do |presenter|
          unless @model_definitions.key?(presenter.model)
            raise MetadataError,
              "Presenter '#{presenter.name}' references unknown model '#{presenter.model}'"
          end
        end

        validate_view_group_references
      end

      def validate_view_group_references
        presenter_in_groups = {}

        @view_group_definitions.each_value do |vg|
          unless @model_definitions.key?(vg.model)
            raise MetadataError,
              "View group '#{vg.name}' references unknown model '#{vg.model}'"
          end

          vg.presenter_names.each do |pname|
            unless @presenter_definitions.key?(pname)
              raise MetadataError,
                "View group '#{vg.name}' references unknown presenter '#{pname}'"
            end

            if presenter_in_groups.key?(pname)
              raise MetadataError,
                "Presenter '#{pname}' appears in multiple view groups: '#{presenter_in_groups[pname]}' and '#{vg.name}'"
            end
            presenter_in_groups[pname] = vg.name
          end
        end
      end
    end
  end
end
