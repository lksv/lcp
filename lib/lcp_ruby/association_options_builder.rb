module LcpRuby
  # Shared helpers for building association select options.
  # Used by both FormHelper (server-side rendering) and
  # ResourcesController (AJAX JSON endpoint).
  module AssociationOptionsBuilder
    private

    def resolve_label(record, label_method)
      record.respond_to?(label_method) ? record.send(label_method) : record.to_s
    end

    def resolve_default_label_method(assoc)
      target_model_def = LcpRuby.loader.model_definition(assoc.target_model)
      method = target_model_def&.label_method
      method && method != "to_s" ? method : "to_label"
    rescue LcpRuby::MetadataError
      "to_label"
    end

    # Returns array of columns to SELECT, or nil when optimization is not safe.
    # Optimization is skipped when any referenced column (label, group_by, sort)
    # is not a real DB column (e.g. computed method like :to_label).
    def optimize_select_columns(target_class, label_method, group_by, sort: nil)
      return nil unless target_class.respond_to?(:column_names)

      label_col = label_method.to_s
      return nil unless target_class.column_names.include?(label_col)

      cols = [:id, label_col.to_sym]

      if group_by
        return nil unless target_class.column_names.include?(group_by.to_s)
        cols << group_by.to_sym
      end

      if sort.is_a?(Hash)
        sort.each_key do |col|
          col_s = col.to_s
          return nil unless target_class.column_names.include?(col_s)
          cols << col_s.to_sym
        end
      end

      cols.uniq
    end
  end
end
