module LcpRuby
  module Metadata
    ContractResult = Struct.new(:errors, :warnings, keyword_init: true) do
      def valid?
        errors.empty?
      end
    end
  end
end
