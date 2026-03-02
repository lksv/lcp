module LcpRuby
  module Auditing
    module AuditWriter
      # Fields always excluded from audit diffs
      EXCLUDED_FIELDS = %w[id created_at updated_at].freeze

      class << self
        # Main entry point. Computes diffs and writes an audit log record.
        #
        # @param action [Symbol] :create, :update, :destroy, :discard, :undiscard
        # @param record [ActiveRecord::Base] the changed record
        # @param options [Hash] auditing options from model definition
        # @param model_definition [Metadata::ModelDefinition] the model's metadata
        def log(action:, record:, options:, model_definition:)
          # Delegate to custom writer if configured
          custom_writer = LcpRuby.configuration.audit_writer
          if custom_writer
            user = LcpRuby::Current.user
            changes = compute_all_changes(action, record, options, model_definition)
            return custom_writer.log(
              action: action,
              record: record,
              changes: changes,
              user: user,
              metadata: build_metadata
            )
          end

          return unless Registry.available?

          changes = compute_all_changes(action, record, options, model_definition)

          # Skip empty updates (no tracked fields changed)
          return if action == :update && changes.empty?

          write_audit_record(action, record, changes, model_definition)
        end

        # Computes all changes for the given action, applying filters and expansions.
        # Public for custom audit writers that need to recompute changes.
        #
        # @return [Hash] field-level diffs
        def compute_all_changes(action, record, options, model_definition)
          changes = compute_scalar_changes(action, record)
          changes = filter_fields(changes, options, model_definition)

          # Expand custom_data into cf: prefixed keys
          if options.fetch("expand_custom_fields", true) && changes.key?("custom_data")
            expand_custom_data!(changes)
          end

          # Expand JSON fields into dot-path diffs
          Array(options["expand_json_fields"]).each do |field_name|
            expand_json_field!(changes, field_name) if changes.key?(field_name)
          end

          # Aggregate nested association changes
          if options.fetch("track_associations", true)
            nested_changes = compute_nested_changes(record, model_definition)
            changes.merge!(nested_changes)
          end

          changes
        end

        private

        # Computes scalar field changes based on the action type.
        def compute_scalar_changes(action, record)
          case action
          when :create
            tracked_attributes(record).each_with_object({}) do |(field, value), h|
              h[field] = [ nil, value ]
            end
          when :update
            record.saved_changes.except(*EXCLUDED_FIELDS)
          when :destroy
            tracked_attributes(record).each_with_object({}) do |(field, value), h|
              h[field] = [ value, nil ]
            end
          when :discard, :undiscard
            # discard!/undiscard! use update_columns which bypasses dirty tracking,
            # so saved_changes is empty. The action type itself conveys what happened.
            {}
          else
            {}
          end
        end

        # Filters changes by only/ignore lists and excluded fields.
        def filter_fields(changes, options, model_definition)
          excluded = EXCLUDED_FIELDS.dup

          if model_definition.userstamps?
            excluded << model_definition.userstamps_creator_field
            excluded << model_definition.userstamps_updater_field
            if model_definition.userstamps_store_name?
              excluded << model_definition.userstamps_creator_name_field
              excluded << model_definition.userstamps_updater_name_field
            end
          end

          if model_definition.soft_delete?
            excluded << model_definition.soft_delete_column
            excluded << SoftDeleteApplicator::DISCARDED_BY_TYPE_COL
            excluded << SoftDeleteApplicator::DISCARDED_BY_ID_COL
          end

          changes = changes.except(*excluded)

          only = Array(options["only"]).map(&:to_s)
          ignore = Array(options["ignore"]).map(&:to_s)

          if only.any?
            changes = changes.select { |k, _| only.include?(k) }
          elsif ignore.any?
            changes = changes.reject { |k, _| ignore.include?(k) }
          end

          changes
        end

        # Expands the custom_data column change into individual cf: prefixed diffs.
        # Mutates changes hash in place.
        def expand_custom_data!(changes)
          old_data, new_data = changes.delete("custom_data")
          old_data = old_data.is_a?(Hash) ? old_data : {}
          new_data = new_data.is_a?(Hash) ? new_data : {}

          diff_hashes(old_data, new_data).each do |key, diff|
            changes["cf:#{key}"] = diff
          end
        end

        # Expands a JSON field change into dot-path diffs for hash values.
        # Array values are stored as whole-value diffs. Mutates changes hash in place.
        def expand_json_field!(changes, field_name)
          old_val, new_val = changes.delete(field_name)

          # If either side is not a Hash, store as whole-value diff
          unless old_val.is_a?(Hash) && new_val.is_a?(Hash)
            changes[field_name] = [ old_val, new_val ]
            return
          end

          diff_hashes(old_val, new_val).each do |key, diff|
            changes["#{field_name}.#{key}"] = diff
          end
        end

        # Computes key-level diffs between two hashes.
        # Returns a hash of { key => [old_value, new_value] } for changed keys only.
        def diff_hashes(old_hash, new_hash)
          result = {}
          (old_hash.keys | new_hash.keys).each do |key|
            old_v = old_hash[key]
            new_v = new_hash[key]
            result[key] = [ old_v, new_v ] unless old_v == new_v
          end
          result
        end

        # Aggregates nested_attributes child changes into parent-level keys.
        def compute_nested_changes(record, model_definition)
          changes = {}

          model_definition.associations.each do |assoc|
            next unless assoc.nested_attributes
            next unless %w[has_many has_one].include?(assoc.type)

            assoc_name = assoc.name
            parent_fk = assoc.foreign_key || "#{model_definition.name.singularize}_id"

            # Access the loaded association (already in memory from nested_attributes)
            next unless record.association(assoc_name.to_sym).loaded?

            children = Array(record.public_send(assoc_name))

            created = []
            updated = []
            destroyed = []

            children.each do |child|
              if child.previously_new_record?
                attrs = child.attributes.except("id", parent_fk, "created_at", "updated_at")
                created << attrs
              elsif child.destroyed? || child.marked_for_destruction?
                attrs = child.attributes.except(parent_fk, "created_at", "updated_at")
                destroyed << attrs
              elsif child.saved_changes.except("created_at", "updated_at").any?
                child_changes = child.saved_changes.except("created_at", "updated_at", parent_fk)
                next if child_changes.empty?

                entry = { "id" => child.id }
                child_changes.each { |k, v| entry[k] = v }
                updated << entry
              end
            end

            changes["#{assoc_name}:created"] = created if created.any?
            changes["#{assoc_name}:updated"] = updated if updated.any?
            changes["#{assoc_name}:destroyed"] = destroyed if destroyed.any?
          end

          changes
        end

        def tracked_attributes(record)
          record.attributes.except(*EXCLUDED_FIELDS)
        end

        def write_audit_record(action, record, changes, model_definition)
          audit_class = Registry.audit_model_class
          return unless audit_class

          fields = field_mapping
          user = LcpRuby::Current.user

          attrs = {
            fields["auditable_type"] => model_definition.name,
            fields["auditable_id"] => record.id,
            fields["action"] => action.to_s,
            fields["changes_data"] => changes
          }

          if fields["user_id"] && audit_class.column_names.include?(fields["user_id"])
            attrs[fields["user_id"]] = user&.id
          end

          if fields["user_snapshot"] && audit_class.column_names.include?(fields["user_snapshot"])
            attrs[fields["user_snapshot"]] = UserSnapshot.capture(user)
          end

          if fields["metadata"] && audit_class.column_names.include?(fields["metadata"])
            attrs[fields["metadata"]] = build_metadata
          end

          audit_class.create!(attrs)
        end

        def field_mapping
          @field_mapping ||= LcpRuby.configuration.audit_model_fields.transform_keys(&:to_s)
        end

        def build_metadata
          meta = {}
          meta["request_id"] = LcpRuby::Current.request_id if LcpRuby::Current.request_id
          meta.presence
        end
      end

      # Clear cached field mapping (called from LcpRuby.reset!)
      def self.clear_cache!
        @field_mapping = nil
      end
    end
  end
end
