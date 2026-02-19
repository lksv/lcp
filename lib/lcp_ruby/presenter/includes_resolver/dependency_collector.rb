module LcpRuby
  module Presenter
    module IncludesResolver
      # Gathers AssociationDependency objects from various sources:
      # presenter metadata, sort params, search fields, and manual YAML config.
      class DependencyCollector
        attr_reader :dependencies

        def initialize
          @dependencies = []
        end

        # Auto-detect associations from presenter metadata based on context.
        #
        # @param presenter_def [PresenterDefinition]
        # @param model_def [ModelDefinition]
        # @param context [:index, :show, :form]
        def from_presenter(presenter_def, model_def, context)
          case context
          when :index then collect_index_deps(presenter_def, model_def)
          when :show  then collect_show_deps(presenter_def, model_def)
          when :form  then collect_form_deps(presenter_def, model_def)
          end
        end

        # Parse dot-notation sort field into a query dependency.
        # e.g. "company.name" -> :query on :company
        #
        # @param field [String, nil]
        # @param model_def [ModelDefinition]
        def from_sort(field, model_def)
          return unless field.to_s.include?(".")

          parts = field.to_s.split(".")
          assoc_name = parts.first
          assoc = find_association(model_def, assoc_name)
          return unless assoc

          add_dependency(path: assoc_name.to_sym, reason: :query)
        end

        # Parse dot-notation searchable fields into query dependencies.
        #
        # @param fields [Array<String>]
        # @param model_def [ModelDefinition]
        def from_search(fields, model_def)
          return unless fields.is_a?(Array)

          fields.each do |field|
            next unless field.to_s.include?(".")

            parts = field.to_s.split(".")
            assoc_name = parts.first
            assoc = find_association(model_def, assoc_name)
            next unless assoc

            add_dependency(path: assoc_name.to_sym, reason: :query)
          end
        end

        # Read manual includes/eager_load from presenter config hash.
        # includes -> :display, eager_load -> :query
        #
        # @param config [Hash] index_config, show_config, or form_config
        def from_manual(config)
          return unless config.is_a?(Hash)

          (config["includes"] || []).each do |entry|
            add_dependency(path: normalize_manual_path(entry), reason: :display)
          end

          (config["eager_load"] || []).each do |entry|
            add_dependency(path: normalize_manual_path(entry), reason: :query)
          end
        end

        private

        # Index context: scan table_columns for FK fields, dot-paths, and templates.
        def collect_index_deps(presenter_def, model_def)
          fk_map = model_def.belongs_to_fk_map
          presenter_def.table_columns.each do |col|
            field = col["field"].to_s

            if field.include?("{")
              # Template: extract all {ref} and collect dot-path deps
              field.scan(/\{([^}]+)\}/).flatten.each do |ref|
                collect_dot_path_dep(ref.strip, model_def) if ref.strip.include?(".")
              end
            elsif field.include?(".")
              collect_dot_path_dep(field, model_def)
            else
              assoc = fk_map[field]
              next unless assoc
              add_dependency(path: assoc.name.to_sym, reason: :display)
            end
          end
        end

        # Show context: scan layout for association_list sections and dot-path fields.
        def collect_show_deps(presenter_def, model_def)
          layout = presenter_def.show_config["layout"] || []
          layout.each do |section|
            if section["type"] == "association_list"
              assoc_name = section["association"]
              next unless assoc_name

              assoc = find_association(model_def, assoc_name)
              next unless assoc

              nested_includes = collect_template_nested_includes(assoc, section)
              if nested_includes.any?
                add_dependency(path: { assoc_name.to_sym => nested_includes }, reason: :display)
              else
                add_dependency(path: assoc_name.to_sym, reason: :display)
              end
            else
              # Scan section fields for dot-paths and templates
              (section["fields"] || []).each do |field_config|
                field = (field_config["field"] || "").to_s

                if field.include?("{")
                  field.scan(/\{([^}]+)\}/).flatten.each do |ref|
                    collect_dot_path_dep(ref.strip, model_def) if ref.strip.include?(".")
                  end
                elsif field.include?(".")
                  collect_dot_path_dep(field, model_def)
                end
              end
            end
          end
        end

        # Form context: scan for nested_fields sections.
        def collect_form_deps(presenter_def, model_def)
          sections = presenter_def.form_config["sections"] || []
          sections.each do |section|
            next unless section["type"] == "nested_fields"

            assoc_name = section["association"]
            next unless assoc_name

            assoc = find_association(model_def, assoc_name)
            next unless assoc

            add_dependency(path: assoc_name.to_sym, reason: :display)
          end
        end

        # Inspect the target model's display template for dot-path fields
        # and return association names needed for nested eager loading.
        def collect_template_nested_includes(assoc, section)
          return [] unless assoc.target_model

          target_def = LcpRuby.loader.model_definition(assoc.target_model)
          return [] unless target_def

          template_name = section["display"] || "default"
          template_def = target_def.display_template(template_name)
          return [] unless template_def

          # Extract association names from dot-path fields in the template
          template_def.referenced_fields
            .select { |f| f.include?(".") }
            .map { |f| f.split(".").first.to_sym }
            .uniq
        rescue LcpRuby::MetadataError
          []
        end

        def collect_dot_path_dep(field_path, model_def)
          parts = field_path.split(".")
          # Last part is the field name, everything before is association chain
          assoc_parts = parts[0..-2]
          return if assoc_parts.empty?

          # Verify the first association exists
          assoc = find_association(model_def, assoc_parts.first)
          return unless assoc

          path = build_nested_path(assoc_parts)
          add_dependency(path: path, reason: :display)
        end

        def build_nested_path(assoc_parts)
          if assoc_parts.length == 1
            assoc_parts.first.to_sym
          else
            # Build nested hash: ["company", "industry"] => { company: :industry }
            assoc_parts.reverse.reduce(nil) do |inner, part|
              inner.nil? ? part.to_sym : { part.to_sym => inner }
            end
          end
        end

        def find_association(model_def, name)
          model_def.associations.find { |a| a.name == name.to_s }
        end

        def add_dependency(path:, reason:)
          # Avoid duplicates with same path and reason
          return if @dependencies.any? { |d| d.path == path && d.reason == reason }

          @dependencies << AssociationDependency.new(path: path, reason: reason)
        end

        # Normalize manual path from String/Symbol/Hash to Symbol/Hash format.
        def normalize_manual_path(value)
          case value
          when Symbol then value
          when String then value.to_sym
          when Hash   then normalize_hash_path(value)
          else raise ArgumentError, "Invalid includes path: #{value.inspect}"
          end
        end

        def normalize_hash_path(hash)
          hash.each_with_object({}) do |(k, v), result|
            key = k.to_s.to_sym
            result[key] = case v
            when String, Symbol then v.to_s.to_sym
            when Array then v.map { |item| item.to_s.to_sym }
            when Hash then normalize_hash_path(v)
            else v
            end
          end
        end
      end
    end
  end
end
