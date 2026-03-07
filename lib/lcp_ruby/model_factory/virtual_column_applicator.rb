module LcpRuby
  module ModelFactory
    class VirtualColumnApplicator
      AR_TYPE_MAP = {
        "integer" => :integer,
        "float" => :float,
        "decimal" => :decimal,
        "boolean" => :boolean,
        "string" => :string,
        "date" => :date,
        "datetime" => :datetime,
        "json" => :json,
        "text" => :string
      }.freeze

      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return if @model_definition.virtual_columns.empty?

        @model_definition.virtual_columns.each_value do |vc_def|
          validate_service_virtual_column!(vc_def) if vc_def.service_type?

          # Declare AR attribute for type coercion
          ar_type = AR_TYPE_MAP[vc_def.inferred_type(@model_definition)] || :string
          @model_class.attribute vc_def.name.to_sym, ar_type
        end

        install_loaded_tracking!
      end

      private

      # Install thread-local stack, after_initialize callback, and reload override
      # for loaded-tracking guard (see design spec: Loaded-tracking guard).
      def install_loaded_tracking!
        # Thread-local stack of Sets — each exec_queries push/pop their VC name set
        @model_class.thread_mattr_accessor :_virtual_columns_stack

        @model_class.after_initialize :_track_loaded_virtual_columns

        empty_set = Set.new.freeze

        @model_class.define_method(:_track_loaded_virtual_columns) do
          return unless persisted?
          stack = self.class._virtual_columns_stack
          # The Set on the stack is frozen by Builder.apply — safe to share without dup.
          # When no stack is present (record loaded outside VC pipeline), use frozen empty set.
          @_loaded_virtual_columns = stack&.last || empty_set
        end

        # Override reload to clear tracking (plain reload doesn't include VC SELECTs)
        @model_class.define_method(:reload) do |*args|
          result = super(*args)
          @_loaded_virtual_columns = empty_set
          result
        end

        # Public query method for loaded-tracking guard
        @model_class.define_method(:virtual_column_loaded?) do |name|
          return true unless persisted?
          return true unless instance_variable_defined?(:@_loaded_virtual_columns)
          @_loaded_virtual_columns.include?(name.to_s)
        end
      end

      def validate_service_virtual_column!(vc_def)
        unless Services::Registry.vc_service_registered?(vc_def.service)
          raise MetadataError,
            "Model '#{@model_definition.name}', virtual column '#{vc_def.name}': " \
            "service '#{vc_def.service}' not found in virtual_columns or aggregates registry"
        end
      end
    end
  end
end
