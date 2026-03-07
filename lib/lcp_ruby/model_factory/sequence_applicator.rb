module LcpRuby
  module ModelFactory
    class SequenceApplicator
      VIRTUAL_SCOPE_KEYS = %w[_year _month _day].freeze
      VALID_ASSIGN_ON = %w[create always].freeze

      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        sequence_fields = collect_sequence_fields
        return if sequence_fields.empty?

        model_name = @model_definition.name

        # before_create: assign sequence values for new records
        @model_class.before_create do |record|
          sequence_fields.each do |field_name, config|
            next unless record.has_attribute?(field_name)
            next if config["assign_on"] == "always" && record.send(field_name).present?

            value = SequenceApplicator.assign_next!(record, model_name, field_name, config)
            record.send("#{field_name}=", value)
          end
        end

        # before_update: fill blank values for assign_on: "always" fields
        always_fields = sequence_fields.select { |_, config| config["assign_on"] == "always" }
        return if always_fields.empty?

        @model_class.before_update do |record|
          always_fields.each do |field_name, config|
            next unless record.has_attribute?(field_name)
            next if record.send(field_name).present?

            value = SequenceApplicator.assign_next!(record, model_name, field_name, config)
            record.send("#{field_name}=", value)
          end
        end
      end

      # Atomically get the next counter value, format it, and return the formatted string.
      def self.assign_next!(record, model_name, field_name, config)
        scope_values = resolve_scope_values(record, config)
        scope_key = Sequences.build_scope_key(scope_values)
        start = config["start"]
        step = config["step"]

        counter_value = next_value!(model_name, field_name, scope_key, start, step)

        format_template = config["format"]
        if format_template
          format_value(counter_value, format_template, record, scope_values)
        else
          counter_value
        end
      end

      # Atomically increment the counter and return the new value.
      # Wrapped in its own transaction to ensure the UPDATE row lock and subsequent
      # SELECT are atomic, even if called outside an AR save callback.
      def self.next_value!(model_name, field_name, scope_key, start, step)
        counter_model = LcpRuby.registry.model_for("gapfree_sequence")

        # The unique index on (seq_model, seq_field, scope_key) prevents duplicates.
        # Retry on conflict handles the race where two threads both try to INSERT.
        attrs = { seq_model: model_name, seq_field: field_name, scope_key: scope_key }

        counter_model.transaction do
          # Try atomic increment first (most common path for existing counters).
          # The UPDATE acquires an implicit row lock held until transaction commit,
          # so the subsequent SELECT is safe from concurrent increments.
          updated = counter_model.where(attrs).update_all(
            [ "current_value = current_value + ?, updated_at = ?", step, Time.current ]
          )

          if updated == 0
            # New scope — insert with start value, retry increment on unique constraint violation
            begin
              counter_model.create!(attrs.merge(current_value: start))
              next start
            rescue ActiveRecord::RecordNotUnique
              # Another thread beat us to the INSERT — increment the row they created.
              # The losing thread gets start + step (the winner got start).
              retried = counter_model.where(attrs).update_all(
                [ "current_value = current_value + ?, updated_at = ?", step, Time.current ]
              )
              raise "Sequence counter row vanished for #{attrs.inspect}" if retried == 0
            end
          end

          counter_model.where(attrs).pick(:current_value)
        end
      end

      # Resolve scope values from the record.
      def self.resolve_scope_values(record, config)
        scope = config.fetch("scope", [])
        time = resolve_time(record)

        scope.each_with_object({}) do |key, values|
          values[key] = case key
          when "_year"  then time.strftime("%Y")
          when "_month" then time.strftime("%m")
          when "_day"   then time.strftime("%d")
          else record.send(key).to_s
          end
        end
      end

      # Format the counter value using the template.
      def self.format_value(counter, format_template, record, scope_values)
        result = format_template.dup

        # Handle %{sequence:Nd} (zero-padded) — must be processed before %{sequence}
        result.gsub!(/\%\{sequence:(\d+)d\}/) { counter.to_s.rjust(Regexp.last_match(1).to_i, "0") }
        # Handle %{sequence} (raw)
        result.gsub!("%{sequence}", counter.to_s)

        # Handle scope values and field references in a single pass
        result.gsub(/\%\{(\w+)\}/) do
          key = Regexp.last_match(1)
          if scope_values.key?(key)
            scope_values[key].to_s
          elsif record.respond_to?(key)
            record.send(key).to_s
          else
            ""
          end
        end
      end

      private

      def collect_sequence_fields
        fields = {}
        @model_definition.fields.each do |field|
          next unless field.sequence?

          fields[field.name] = normalize_config(field.sequence)
        end
        fields
      end

      def normalize_config(config)
        assign_on = config.fetch("assign_on", "create")
        unless VALID_ASSIGN_ON.include?(assign_on)
          raise LcpRuby::MetadataError,
            "Invalid assign_on value '#{assign_on}' — must be one of: #{VALID_ASSIGN_ON.join(', ')}"
        end

        {
          "scope" => config.fetch("scope", []),
          "format" => config["format"],
          "start" => config.fetch("start", 1),
          "step" => config.fetch("step", 1),
          "readonly" => config.fetch("readonly", true),
          "assign_on" => assign_on
        }
      end

      def self.resolve_time(record)
        if record.respond_to?(:created_at) && record.created_at
          record.created_at
        else
          Time.current
        end
      end
    end
  end
end
