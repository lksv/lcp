module LcpRuby
  module HostServices
    module Validators
      class AlwaysFail
        def self.call(record, **opts)
          field = opts[:field] || :base
          record.errors.add(field, "always fails")
        end
      end
    end
  end
end
