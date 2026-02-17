module LcpRuby
  module HostServices
    module Validators
      class DealCreditLimit
        def self.call(record, **opts)
          return unless record.respond_to?(:company_id) && record.company_id

          company_deals = record.class.where(company_id: record.company_id)
          company_deals = company_deals.where.not(id: record.id) if record.persisted?
          total = company_deals.sum(:value).to_f + record.value.to_f

          if total > 1_000_000
            record.errors.add(:value, "total company deals exceed credit limit (1M)")
          end
        end
      end
    end
  end
end
