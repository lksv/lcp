module LcpRuby
  module ViewSlotHelper
    def render_slot(slot, page:)
      components = ViewSlots::Registry.components_for(page, slot)
      return "".html_safe if components.empty?

      context = build_slot_context(page)

      results = components.filter_map do |component|
        next unless component.enabled?(context)

        render partial: component.partial, locals: { slot_context: context }
      end

      safe_join(results)
    end

    private

    def build_slot_context(page)
      ViewSlots::SlotContext.new(
        presenter: current_presenter,
        model_definition: current_model_definition,
        evaluator: current_evaluator,
        action_set: instance_variable_defined?(:@action_set) ? @action_set : nil,
        params: params,
        records: instance_variable_defined?(:@records) ? @records : nil,
        record: instance_variable_defined?(:@record) ? @record : nil,
        locals: instance_variable_defined?(:@slot_locals) ? @slot_locals : {}
      )
    end
  end
end
