module LcpRuby
  module ModelFactory
    class AttachmentApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        attachment_fields.each do |field|
          apply_attachment(field)
        end
      end

      private

      def attachment_fields
        @model_definition.fields.select(&:attachment?)
      end

      def apply_attachment(field)
        name = field.name.to_sym
        options = field.attachment_options

        if field.attachment_multiple?
          @model_class.has_many_attached name
        else
          @model_class.has_one_attached name
        end

        apply_variants(field)
        apply_validations(field)
      end

      def apply_variants(field)
        options = field.attachment_options
        variants = options["variants"]
        return unless variants.is_a?(Hash) && variants.any?

        # Store variant config as a class-level attribute for use in views
        unless @model_class.respond_to?(:lcp_attachment_variants)
          @model_class.class_attribute :lcp_attachment_variants, default: {}
        end

        @model_class.lcp_attachment_variants = @model_class.lcp_attachment_variants.merge(
          field.name => variants.transform_keys(&:to_s)
        )
      end

      def apply_validations(field)
        if field.attachment_multiple?
          apply_multiple_validations(field)
        else
          apply_single_validations(field)
        end
      end

      def apply_single_validations(field)
        name = field.name.to_sym
        options = field.attachment_options
        max_size = parse_size(options["max_size"])
        min_size = parse_size(options["min_size"])
        allowed_types = options["content_types"]

        if max_size || min_size || allowed_types
          applicator = self
          @model_class.validate do |record|
            attachment = record.send(name)
            next unless attachment.attached?

            blob = attachment.blob

            if max_size && blob.byte_size > max_size
              record.errors.add(name, "is too large (maximum is #{options['max_size']})")
            end

            if min_size && blob.byte_size < min_size
              record.errors.add(name, "is too small (minimum is #{options['min_size']})")
            end

            if allowed_types && !applicator.send(:content_type_allowed?, blob.content_type, allowed_types)
              record.errors.add(name, "has an invalid content type (#{blob.content_type})")
            end
          end
        end
      end

      def apply_multiple_validations(field)
        name = field.name.to_sym
        options = field.attachment_options
        max_size = parse_size(options["max_size"])
        min_size = parse_size(options["min_size"])
        allowed_types = options["content_types"]
        max_files = options["max_files"]

        if max_size || min_size || allowed_types || max_files
          applicator = self
          @model_class.validate do |record|
            attachments = record.send(name)
            next unless attachments.attached?

            blobs = attachments.map(&:blob)

            if max_files && blobs.size > max_files
              record.errors.add(name, "has too many files (maximum is #{max_files})")
            end

            blobs.each do |blob|
              if max_size && blob.byte_size > max_size
                record.errors.add(name, "contains a file that is too large (maximum is #{options['max_size']})")
                break
              end

              if min_size && blob.byte_size < min_size
                record.errors.add(name, "contains a file that is too small (minimum is #{options['min_size']})")
                break
              end

              if allowed_types && !applicator.send(:content_type_allowed?, blob.content_type, allowed_types)
                record.errors.add(name, "contains a file with an invalid content type (#{blob.content_type})")
                break
              end
            end
          end
        end
      end

      def parse_size(size_str)
        return nil unless size_str.is_a?(String)

        match = size_str.strip.match(/\A(\d+(?:\.\d+)?)\s*(B|KB|MB|GB)\z/i)
        return nil unless match

        value = match[1].to_f
        unit = match[2].upcase

        case unit
        when "B"  then value.to_i
        when "KB" then (value * 1024).to_i
        when "MB" then (value * 1024 * 1024).to_i
        when "GB" then (value * 1024 * 1024 * 1024).to_i
        end
      end

      def content_type_allowed?(content_type, allowed_list)
        return true unless allowed_list.is_a?(Array) && allowed_list.any?

        allowed_list.any? do |pattern|
          if pattern.include?("*")
            # Wildcard matching: "image/*" matches "image/png"
            regex = Regexp.new("\\A" + Regexp.escape(pattern).gsub("\\*", ".*") + "\\z")
            regex.match?(content_type)
          else
            content_type == pattern
          end
        end
      end
    end
  end
end
