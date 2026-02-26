module LcpRuby
  module Metadata
    class GroupDefinition
      attr_reader :name, :label, :description, :roles

      def initialize(name:, label: nil, description: nil, roles: [])
        @name = name.to_s
        @label = label || @name.titleize
        @description = description
        @roles = Array(roles).map(&:to_s)
      end

      # Factory method to build from a parsed YAML hash.
      # @param hash [Hash] e.g. { "name" => "sales_team", "roles" => ["sales_rep", "viewer"] }
      # @return [GroupDefinition]
      def self.from_hash(hash)
        hash = hash.transform_keys(&:to_s)
        name = hash["name"]
        if name.nil? || name.to_s.strip.empty?
          raise MetadataError, "Group definition must have a 'name' key"
        end
        new(
          name: name,
          label: hash["label"],
          description: hash["description"],
          roles: hash["roles"] || []
        )
      end
    end
  end
end
