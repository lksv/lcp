require "yaml"

module LcpRuby
  module Metadata
    class Loader
      attr_reader :base_path, :model_definitions, :presenter_definitions, :permission_definitions

      def initialize(base_path)
        @base_path = Pathname.new(base_path)
        @model_definitions = {}
        @presenter_definitions = {}
        @permission_definitions = {}
      end

      def load_all
        load_models
        load_presenters
        load_permissions
        validate_references
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
      end

      def load_permissions
        load_yamls("permissions") do |data, file_path|
          permission_data = data["permissions"] || raise(MetadataError, "Missing 'permissions' key in #{file_path}")
          definition = PermissionDefinition.from_hash(permission_data)
          @permission_definitions[definition.model] = definition
        end
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

      def validate_references
        @presenter_definitions.each_value do |presenter|
          unless @model_definitions.key?(presenter.model)
            raise MetadataError,
              "Presenter '#{presenter.name}' references unknown model '#{presenter.model}'"
          end
        end
      end
    end
  end
end
