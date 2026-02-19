require "yaml"

module LcpRuby
  module Metadata
    class Loader
      attr_reader :base_path, :model_definitions, :presenter_definitions,
                  :permission_definitions, :view_group_definitions, :menu_definition

      def initialize(base_path)
        @base_path = Pathname.new(base_path)
        @model_definitions = {}
        @presenter_definitions = {}
        @permission_definitions = {}
        @view_group_definitions = {}
        @menu_definition = nil
      end

      def load_all
        load_types
        load_models
        load_presenters
        load_permissions
        load_view_groups
        validate_references
        auto_create_view_groups
        load_menu
      end

      def menu_defined?
        !@menu_definition.nil?
      end

      # Returns navigable view groups (those not opted out with navigation: false)
      def navigable_view_groups
        @view_group_definitions.values.select(&:navigable?)
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

      def load_menu
        menu_mode = LcpRuby.configuration.menu_mode
        menu_file = find_menu_file

        if menu_mode == :strict
          validate_strict_mode!
          unless menu_file
            raise MetadataError, "menu.yml is required when menu_mode is :strict"
          end
        end

        return unless menu_file

        data = YAML.safe_load_file(menu_file, permitted_classes: [ Symbol, Regexp ])
        return unless data

        @menu_definition = MenuDefinition.from_hash(data)
        validate_menu_references!

        auto_append_unreferenced_view_groups! if menu_mode == :auto
      rescue Psych::SyntaxError => e
        raise MetadataError, "YAML syntax error in #{menu_file}: #{e.message}"
      end

      def find_menu_file
        %w[menu.yml menu.yaml].each do |filename|
          path = base_path.join(filename)
          return path if path.exist?
        end
        nil
      end

      def validate_strict_mode!
        @view_group_definitions.each_value do |vg|
          next unless vg.navigable?

          nav = vg.navigation_config
          if nav.is_a?(Hash) && nav.any?
            raise MetadataError,
              "View group '#{vg.name}' has navigation config but menu_mode is :strict. " \
              "Use navigation: false or remove navigation config."
          end
        end
      end

      def validate_menu_references!
        validate_menu_items!(@menu_definition.top_menu) if @menu_definition.has_top_menu?
        validate_menu_items!(@menu_definition.sidebar_menu) if @menu_definition.has_sidebar_menu?
      end

      def validate_menu_items!(items)
        items.each do |item|
          if item.view_group?
            unless @view_group_definitions.key?(item.view_group_name)
              raise MetadataError,
                "Menu references unknown view group '#{item.view_group_name}'"
            end
          end

          validate_menu_items!(item.children) if item.group?
        end
      end

      # In :auto mode, append navigable view groups not referenced in menu.yml
      def auto_append_unreferenced_view_groups!
        referenced = collect_referenced_view_groups(@menu_definition)

        unreferenced = navigable_view_groups.reject { |vg| referenced.include?(vg.name) }
        return if unreferenced.empty?

        sorted = unreferenced.sort_by do |vg|
          nav = vg.navigation_config
          nav.is_a?(Hash) ? (nav["position"] || 99) : 99
        end

        appended_items = sorted.map do |vg|
          MenuItem.new(type: :view_group, view_group_name: vg.name)
        end

        # Append to top_menu (create it if only sidebar exists)
        if @menu_definition.has_top_menu?
          @menu_definition = MenuDefinition.new(
            top_menu: @menu_definition.top_menu + appended_items,
            sidebar_menu: @menu_definition.sidebar_menu
          )
        else
          @menu_definition = MenuDefinition.new(
            top_menu: appended_items,
            sidebar_menu: @menu_definition.sidebar_menu
          )
        end
      end

      def collect_referenced_view_groups(menu_def)
        names = Set.new
        collect_vg_names(menu_def.top_menu || [], names)
        collect_vg_names(menu_def.sidebar_menu || [], names)
        names
      end

      def collect_vg_names(items, names)
        items.each do |item|
          names << item.view_group_name if item.view_group?
          collect_vg_names(item.children, names) if item.group?
        end
      end
    end
  end
end
