module LcpRuby
  module HostServices
    module DataProviders
      class PipelineValue
        def self.call(user:)
          total = LcpRuby.registry.model_for("deal")
            .where.not(stage: %w[closed_won closed_lost])
            .sum(:value)
          return nil if total.zero?

          formatted = number_to_compact(total)
          { "value" => formatted }
        end

        def self.number_to_compact(number)
          if number >= 1_000_000
            "#{(number / 1_000_000.0).round(1)}M"
          elsif number >= 1_000
            "#{(number / 1_000.0).round(1)}K"
          else
            number.to_i.to_s
          end
        end
      end
    end
  end
end
