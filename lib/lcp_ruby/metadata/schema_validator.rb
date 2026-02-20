# frozen_string_literal: true

require "json_schemer"

module LcpRuby
  module Metadata
    class SchemaValidator
      SCHEMA_TYPES = %w[model presenter permission view_group menu type].freeze

      def initialize
        @schemas = {}
        SCHEMA_TYPES.each do |name|
          path = File.join(schemas_dir, "#{name}.json")
          @schemas[name] = JSONSchemer.schema(JSON.parse(File.read(path)))
        end
      end

      def validate_model(model_definition)
        raw = model_definition.raw_hash
        return [] unless raw

        validate(:model, raw, context_name: "Model '#{model_definition.name}'")
      end

      def validate_presenter(presenter_definition)
        raw = presenter_definition.raw_hash
        return [] unless raw

        validate(:presenter, raw, context_name: "Presenter '#{presenter_definition.name}'")
      end

      def validate_permission(permission_definition)
        raw = permission_definition.raw_hash
        return [] unless raw

        validate(:permission, raw, context_name: "Permission '#{permission_definition.model}'")
      end

      def validate_view_group(view_group_definition)
        raw = view_group_definition.raw_hash
        return [] unless raw

        validate(:view_group, raw, context_name: "View group '#{view_group_definition.name}'")
      end

      def validate_menu(menu_definition)
        raw = menu_definition.raw_hash
        return [] unless raw

        validate(:menu, raw, context_name: "Menu")
      end

      def validate_type_hash(hash, name: nil)
        return [] unless hash

        context = name ? "Type '#{name}'" : "Type"
        validate(:type, hash, context_name: context)
      end

      private

      def validate(type, data, context_name: nil)
        schema = @schemas.fetch(type.to_s)
        errors = schema.validate(data).to_a

        # Collapse oneOf/type-mismatch failures: when multiple errors share the same pointer
        # and are all type-level errors (not structural like additionalProperties/missing required),
        # collapse them into a single "does not match any allowed format" message.
        errors_by_pointer = errors.group_by { |e| e["data_pointer"] }
        collapsed_pointers = errors_by_pointer.select do |_ptr, group|
          group.size > 1 && group.all? { |e| type_mismatch_error?(e) }
        end.keys

        result = []
        collapsed_pointers.each do |ptr|
          result << synthetic_one_of_error(ptr)
        end
        errors.each do |error|
          next if collapsed_pointers.include?(error["data_pointer"])

          result << error
        end

        result.map { |error| format_error(error, context_name) }
      end

      def type_mismatch_error?(error)
        %w[string object array integer number boolean const oneOf].include?(error["type"])
      end

      def synthetic_one_of_error(pointer)
        { "data_pointer" => pointer, "type" => "oneOf", "error" => "does not match any allowed format" }
      end

      def format_error(error, context_name)
        pointer = error["data_pointer"]
        prefix = context_name ? "#{context_name}, " : ""
        path = pointer_to_path(pointer)

        if error["type"] == "oneOf"
          "#{prefix}#{path}: invalid value (does not match any allowed format)"
        elsif error["error"].include?("additional property")
          property = pointer.split("/").last
          parent = pointer_to_path(pointer.sub(%r{/[^/]+\z}, ""))
          "#{prefix}#{parent}: unknown attribute '#{property}'"
        elsif error["error"].include?("missing required")
          missing = error["details"]["missing_keys"]
          "#{prefix}#{path}: missing required #{missing.join(', ')}"
        elsif error["type"] == "enum"
          allowed = error["schema"]["enum"]
          "#{prefix}#{path}: invalid value '#{error["data"]}' (allowed: #{allowed.join(', ')})"
        else
          "#{prefix}#{path}: #{error["error"]}"
        end
      end

      def pointer_to_path(pointer)
        return "(root)" if pointer.nil? || pointer.empty?

        pointer.delete_prefix("/").gsub(%r{/(\d+)/}, '[\\1].').gsub("/", ".")
      end

      def schemas_dir
        File.expand_path("../schemas", __dir__)
      end
    end
  end
end
