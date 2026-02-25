module LcpRuby
  # Wraps a plain hash (one item from a JSON column array) with
  # ActiveModel::Model so it can participate in validations and
  # provide typed getter/setter access based on a ModelDefinition.
  #
  # Usage:
  #   wrapper = JsonItemWrapper.new({"name" => "Alice"}, model_def)
  #   wrapper.name        # => "Alice"
  #   wrapper.name = "Bob"
  #   wrapper.valid?       # runs model_def validations
  #   wrapper.to_hash      # => {"name" => "Bob"}
  class JsonItemWrapper
    include ActiveModel::Model

    attr_reader :model_definition

    def initialize(data = {}, model_definition = nil)
      @data = (data || {}).transform_keys(&:to_s)
      @model_definition = model_definition
      define_accessors! if model_definition
    end

    # Dynamic field access — falls back to hash lookup
    def respond_to_missing?(method_name, include_private = false)
      name = method_name.to_s
      if name.end_with?("=")
        true
      else
        @data.key?(name) || super
      end
    end

    def method_missing(method_name, *args)
      name = method_name.to_s
      if name.end_with?("=")
        @data[name.chomp("=")] = args.first
      elsif @data.key?(name)
        @data[name]
      else
        super
      end
    end

    # Convert back to a plain hash for JSON persistence
    def to_hash
      @data.dup
    end
    alias_method :to_h, :to_hash

    # Apply validations from the model definition using ActiveModel's
    # validation framework. This mirrors how ValidationApplicator works
    # for AR models, ensuring consistent semantics (error messages, options).
    # Returns true if no errors, false otherwise.
    def validate_with_model_rules!
      return true unless model_definition

      apply_dynamic_validations!
      valid?
    end

    private

    def define_accessors!
      model_definition.fields.each do |field|
        field_name = field.name

        # Define getter
        define_singleton_method(field_name) do
          coerce_value(@data[field_name], field)
        end

        # Define setter
        define_singleton_method("#{field_name}=") do |value|
          @data[field_name] = value
        end
      end
    end

    def coerce_value(value, field)
      return nil if value.nil?

      case field.type
      when "integer"
        value.to_s.blank? ? nil : value.to_i
      when "float"
        value.to_s.blank? ? nil : value.to_f
      when "decimal"
        if value.to_s.blank?
          nil
        else
          begin
            BigDecimal(value.to_s)
          rescue ArgumentError
            nil
          end
        end
      when "boolean"
        ActiveModel::Type::Boolean.new.cast(value)
      else
        value
      end
    end

    # Dynamically register ActiveModel validations from the model definition.
    # Uses the singleton class so validations apply only to this instance.
    # Guarded against double-call to prevent validation accumulation.
    def apply_dynamic_validations!
      return if @validations_applied
      @validations_applied = true

      model_definition.fields.each do |field|
        field.validations.each do |validation|
          register_validation(field.name, validation)
        end
      end
    end

    def register_validation(field_name, validation)
      sym = field_name.to_sym
      opts = validation.options.dup
      opts[:message] = validation.message if validation.message

      case validation.type
      when "presence"
        self.singleton_class.validates sym, presence: opts.except(:message).empty? ? { message: opts[:message] }.compact : opts
      when "length"
        self.singleton_class.validates sym, length: opts
      when "numericality"
        self.singleton_class.validates sym, numericality: opts.except(:message).empty? ? { message: opts[:message] }.compact : opts
      when "format"
        if opts[:with].is_a?(String)
          opts[:with] = ConditionEvaluator.safe_regexp(opts[:with])
        end
        self.singleton_class.validates sym, format: opts
      when "inclusion"
        self.singleton_class.validates sym, inclusion: opts
      when "exclusion"
        self.singleton_class.validates sym, exclusion: opts
      end
    end
  end
end
