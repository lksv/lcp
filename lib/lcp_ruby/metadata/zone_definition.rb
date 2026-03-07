module LcpRuby
  module Metadata
    class ZoneDefinition
      attr_reader :name, :presenter, :area

      def initialize(name:, presenter:, area: "main")
        @name = name.to_s
        @presenter = presenter.to_s
        @area = (area || "main").to_s

        validate!
      end

      def self.from_hash(hash)
        hash = HashUtils.stringify_deep(hash)
        new(
          name: hash["name"],
          presenter: hash["presenter"],
          area: hash["area"]
        )
      end

      private

      def validate!
        raise MetadataError, "Zone name is required" if @name.blank?
        raise MetadataError, "Zone '#{@name}' requires a presenter reference" if @presenter.blank?
      end
    end
  end
end
