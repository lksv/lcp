module LcpRuby
  module VirtualColumns
    # Scans presenter metadata to determine which virtual columns to include.
    class Collector
      # Collect virtual column names needed for a given context.
      #
      # @param presenter_def [Metadata::PresenterDefinition]
      # @param model_def [Metadata::ModelDefinition]
      # @param context [:index, :show, :edit]
      # @param sort_field [String, nil] runtime sort field from request params (?sort=)
      # @return [Set<String>]
      def self.collect(presenter_def:, model_def:, context: :index, sort_field: nil)
        all_vc_names = model_def.virtual_column_names.to_set
        return Set.new if all_vc_names.empty?

        vc_names = Set.new

        # 1. auto_include: true virtual columns (always included)
        model_def.virtual_columns.each do |name, vc_def|
          vc_names << name if vc_def.auto_include
        end

        case context
        when :index
          collect_index(presenter_def, model_def, all_vc_names, vc_names)
        when :show
          collect_show(presenter_def, model_def, all_vc_names, vc_names)
        when :edit
          collect_edit(presenter_def, model_def, all_vc_names, vc_names)
        end

        # Runtime sort param — include VC if sorting by it
        if sort_field.present?
          field = sort_field.to_s
          vc_names << field if all_vc_names.include?(field)
        end

        # Filter to only existing VC names
        vc_names & all_vc_names
      end

      class << self
        private

        def collect_index(presenter_def, model_def, all_vc_names, vc_names)
          # table_columns field names
          presenter_def.table_columns.each do |col|
            field = col["field"].to_s
            vc_names << field if all_vc_names.include?(field)
          end

          # tile fields
          if presenter_def.tiles?
            presenter_def.all_tile_field_refs.each do |field|
              vc_names << field if all_vc_names.include?(field)
            end
          end

          # item_classes conditions
          presenter_def.item_classes.each do |rule|
            condition = rule["when"]
            walk_condition_fields(condition, all_vc_names, vc_names) if condition.is_a?(Hash)
          end

          collect_action_condition_vcs(presenter_def, all_vc_names, vc_names)

          # record_rules conditions (from permissions if available)
          collect_record_rules_vcs(model_def, all_vc_names, vc_names)

          # Explicit index virtual_columns
          explicit = presenter_def.index_config["virtual_columns"]
          if explicit.is_a?(Array)
            explicit.each { |name| vc_names << name.to_s if all_vc_names.include?(name.to_s) }
          end
        end

        def collect_show(presenter_def, model_def, all_vc_names, vc_names)
          # Show layout field names
          layout = presenter_def.show_config["layout"] || []
          layout.each do |section|
            (section["fields"] || []).each do |f|
              field = f["field"].to_s
              vc_names << field if all_vc_names.include?(field)
            end
          end

          collect_action_condition_vcs(presenter_def, all_vc_names, vc_names)

          # Explicit show virtual_columns
          explicit = presenter_def.show_config["virtual_columns"]
          if explicit.is_a?(Array)
            explicit.each { |name| vc_names << name.to_s if all_vc_names.include?(name.to_s) }
          end
        end

        def collect_edit(presenter_def, model_def, all_vc_names, vc_names)
          # Scan form visible_when/disable_when conditions
          sections = presenter_def.form_config["sections"] || []
          sections.each do |section|
            %w[visible_when disable_when].each do |key|
              cond = section[key]
              walk_condition_fields(cond, all_vc_names, vc_names) if cond.is_a?(Hash)
            end

            (section["fields"] || []).each do |f|
              %w[visible_when disable_when].each do |key|
                cond = f[key]
                walk_condition_fields(cond, all_vc_names, vc_names) if cond.is_a?(Hash)
              end
            end
          end

          collect_action_condition_vcs(presenter_def, all_vc_names, vc_names)
        end

        def collect_action_condition_vcs(presenter_def, all_vc_names, vc_names)
          all_actions = presenter_def.single_actions + presenter_def.collection_actions + presenter_def.batch_actions
          all_actions.each do |action|
            %w[visible_when disable_when].each do |key|
              cond = action[key]
              walk_condition_fields(cond, all_vc_names, vc_names) if cond.is_a?(Hash)
            end

            # Action-level explicit virtual_columns declarations
            explicit = action["virtual_columns"]
            if explicit.is_a?(Array)
              explicit.each { |name| vc_names << name.to_s if all_vc_names.include?(name.to_s) }
            end
          end

          # Scope-level explicit virtual_columns declarations (from predefined_filters)
          collect_scope_vcs(presenter_def, all_vc_names, vc_names)
        end

        def collect_scope_vcs(presenter_def, all_vc_names, vc_names)
          filters = presenter_def.search_config.dig("predefined_filters")
          return unless filters.is_a?(Array)

          filters.each do |filter|
            explicit = filter["virtual_columns"]
            next unless explicit.is_a?(Array)

            explicit.each { |name| vc_names << name.to_s if all_vc_names.include?(name.to_s) }
          end
        end

        def collect_record_rules_vcs(model_def, all_vc_names, vc_names)
          perm_def = LcpRuby.loader.permission_definition(model_def.name)
          return unless perm_def

          perm_def.roles.each_value do |role_config|
            rules = role_config["record_rules"]
            next unless rules.is_a?(Array)

            rules.each do |rule|
              condition = rule["when"]
              walk_condition_fields(condition, all_vc_names, vc_names) if condition.is_a?(Hash)
            end
          end
        end

        # Recursively walks a condition tree and adds any field names that match VC names.
        def walk_condition_fields(condition, all_vc_names, vc_names)
          return unless condition.is_a?(Hash)

          normalized = condition.transform_keys(&:to_s)

          if normalized.key?("all") || normalized.key?("any")
            Array(normalized["all"] || normalized["any"]).each do |child|
              walk_condition_fields(child, all_vc_names, vc_names)
            end
          elsif normalized.key?("not")
            walk_condition_fields(normalized["not"], all_vc_names, vc_names)
          elsif normalized.key?("collection")
            child = normalized["condition"]
            walk_condition_fields(child, all_vc_names, vc_names) if child.is_a?(Hash)
          elsif normalized.key?("field")
            field = normalized["field"].to_s
            root_field = field.split(".").first
            vc_names << root_field if all_vc_names.include?(root_field)
          end
        end
      end
    end
  end
end
