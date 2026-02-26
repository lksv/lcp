module LcpRuby
  module Groups
    class YamlLoader
      include Contract

      attr_reader :group_definitions

      def initialize
        @group_definitions = {}
      end

      # Loads group definitions from groups.yml/groups.yaml in the metadata path.
      # @param base_path [Pathname, String] the metadata directory
      def load(base_path)
        base_path = Pathname.new(base_path)
        file_path = find_groups_file(base_path)
        unless file_path
          log_warn("No groups.yml or groups.yaml found in #{base_path}; no groups will be loaded")
          return
        end

        data = YAML.safe_load_file(file_path, permitted_classes: [ Symbol, Regexp ])
        unless data
          log_warn("#{file_path} is empty; no groups will be loaded")
          return
        end

        groups_data = data["groups"]
        unless groups_data.is_a?(Array)
          log_warn("#{file_path} missing 'groups' array key; no groups will be loaded")
          return
        end

        groups_data.each do |group_hash|
          definition = Metadata::GroupDefinition.from_hash(group_hash)
          @group_definitions[definition.name] = definition
        end
      rescue Psych::SyntaxError => e
        raise MetadataError, "YAML syntax error in #{file_path}: #{e.message}"
      end

      # @return [Array<String>]
      def all_group_names
        @group_definitions.keys.sort
      end

      # Returns group names the user belongs to by calling the configured group_method.
      # @param user [Object]
      # @return [Array<String>]
      def groups_for_user(user)
        return [] unless user

        group_method = LcpRuby.configuration.group_method
        return [] unless user.respond_to?(group_method)

        user_groups = Array(user.send(group_method)).map(&:to_s)
        unknown = user_groups - @group_definitions.keys
        if unknown.any?
          log_warn("User has groups not defined in YAML: #{unknown.join(', ')}")
        end
        user_groups.select { |g| @group_definitions.key?(g) }
      end

      # @param group_name [String]
      # @return [Array<String>]
      def roles_for_group(group_name)
        definition = @group_definitions[group_name.to_s]
        return [] unless definition

        definition.roles
      end

      private

      def log_warn(message)
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.warn("[LcpRuby::Groups] #{message}")
        end
      end

      def find_groups_file(base_path)
        %w[groups.yml groups.yaml].each do |filename|
          path = base_path.join(filename)
          return path if path.exist?
        end
        nil
      end
    end
  end
end
