module LcpRuby
  module ViewSlots
    class Registry
      BUILT_IN_COMPONENTS = [
        { page: :index, slot: :toolbar_center, name: :view_switcher,      partial: "lcp_ruby/slots/index/view_switcher",      position: 10 },
        { page: :index, slot: :toolbar_end,    name: :manage_all,         partial: "lcp_ruby/slots/index/manage_all",          position: 5 },
        { page: :index, slot: :toolbar_end,    name: :collection_actions, partial: "lcp_ruby/slots/index/collection_actions",  position: 10 },
        { page: :index, slot: :filter_bar,     name: :search,             partial: "lcp_ruby/slots/index/search",              position: 10 },
        { page: :index, slot: :filter_bar,     name: :predefined_filters, partial: "lcp_ruby/slots/index/predefined_filters",  position: 20 },
        { page: :index, slot: :filter_bar,     name: :advanced_filter,    partial: "lcp_ruby/slots/index/advanced_filter",     position: 30 },
        { page: :index, slot: :below_content,  name: :pagination,         partial: "lcp_ruby/slots/index/pagination",          position: 10 },
        { page: :show,  slot: :toolbar_start,  name: :view_switcher,      partial: "lcp_ruby/slots/show/view_switcher",        position: 10 },
        { page: :show,  slot: :toolbar_start,  name: :back_to_list,       partial: "lcp_ruby/slots/show/back_to_list",         position: 20 },
        { page: :show,  slot: :toolbar_end,    name: :copy_url,           partial: "lcp_ruby/slots/show/copy_url",             position: 10 },
        { page: :show,  slot: :toolbar_end,    name: :single_actions,     partial: "lcp_ruby/slots/show/single_actions",       position: 20 }
      ].freeze

      class << self
        def register(page:, slot:, name:, partial:, position: 10, enabled: nil)
          component = SlotComponent.new(
            page: page, slot: slot, name: name,
            partial: partial, position: position, enabled: enabled
          )
          key = registry_key(page, slot)
          registry[key] ||= []

          # Replace existing component with the same name (enables host app overrides)
          registry[key].reject! { |c| c.name == component.name }
          registry[key] << component
        end

        def components_for(page, slot)
          key = registry_key(page, slot)
          (registry[key] || []).sort_by(&:position)
        end

        def registered?(page, slot, name)
          key = registry_key(page, slot)
          (registry[key] || []).any? { |c| c.name == name.to_sym }
        end

        def register_built_ins!
          BUILT_IN_COMPONENTS.each do |attrs|
            register(**attrs)
          end
        end

        def clear!
          @registry = {}
        end

        private

        def registry_key(page, slot)
          [ page.to_sym, slot.to_sym ].freeze
        end

        def registry
          @registry ||= {}
        end
      end
    end
  end
end
