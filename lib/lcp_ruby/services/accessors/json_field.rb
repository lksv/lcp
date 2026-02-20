module LcpRuby
  module Services
    module Accessors
      class JsonField
        def self.get(record, options:)
          column = options["column"]
          key = options["key"]
          record.send(column)&.dig(key)
        end

        def self.set(record, value, options:)
          column = options["column"]
          key = options["key"]
          data = record.send(column) || {}
          # Mark column dirty before assignment to ensure JSON changes are persisted
          # even when AR's equality check considers the old and new hashes equivalent.
          record.send("#{column}_will_change!") unless record.send("#{column}_changed?")
          record.send("#{column}=", data.merge(key => value))
        end
      end
    end
  end
end
