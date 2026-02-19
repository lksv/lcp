module LcpRuby
  module HostServices
    module Validators
      class DealDocumentsRequired
        STAGES_REQUIRING_DOCUMENTS = %w[proposal negotiation closed_won].freeze

        def self.call(record, **_opts)
          return unless record.respond_to?(:stage) && record.respond_to?(:documents)
          return unless STAGES_REQUIRING_DOCUMENTS.include?(record.stage)
          return if record.documents.attached?

          record.errors.add(:documents, "must be attached for deals in #{record.stage} stage")
        end
      end
    end
  end
end
