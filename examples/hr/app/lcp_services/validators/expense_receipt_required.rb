module LcpRuby
  module HostServices
    module Validators
      class ExpenseReceiptRequired
        def self.call(record, **opts)
          return unless record.respond_to?(:amount) && record.amount.to_f > 500

          has_receipt = record.respond_to?(:receipt) && record.receipt.attached?

          unless has_receipt
            record.errors.add(:receipt, "is required for expense claims over 500")
          end
        end
      end
    end
  end
end
