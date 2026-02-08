module LcpRuby
  class ConditionEvaluator
    class << self
      def evaluate(record, condition)
        return true unless condition

        condition = condition.transform_keys(&:to_s) if condition.is_a?(Hash)
        field = condition["field"]
        operator = condition["operator"]&.to_s
        value = condition["value"]

        return true unless field && record.respond_to?(field)

        actual = record.send(field)

        case operator
        when "eq"
          actual.to_s == value.to_s
        when "not_eq", "neq"
          actual.to_s != value.to_s
        when "in"
          Array(value).map(&:to_s).include?(actual.to_s)
        when "not_in"
          !Array(value).map(&:to_s).include?(actual.to_s)
        when "gt"
          actual.to_f > value.to_f
        when "gte"
          actual.to_f >= value.to_f
        when "lt"
          actual.to_f < value.to_f
        when "lte"
          actual.to_f <= value.to_f
        when "present"
          actual.present?
        when "blank"
          actual.blank?
        else
          actual.to_s == value.to_s
        end
      end
    end
  end
end
