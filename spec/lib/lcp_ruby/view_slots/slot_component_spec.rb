require "spec_helper"

RSpec.describe LcpRuby::ViewSlots::SlotComponent do
  describe "#initialize" do
    it "stores all attributes correctly" do
      callback = ->(ctx) { true }
      component = described_class.new(
        page: :index, slot: :toolbar_end, name: :my_button,
        partial: "lcp_ruby/slots/index/my_button", position: 5,
        enabled: callback
      )

      expect(component.page).to eq(:index)
      expect(component.slot).to eq(:toolbar_end)
      expect(component.name).to eq(:my_button)
      expect(component.partial).to eq("lcp_ruby/slots/index/my_button")
      expect(component.position).to eq(5)
      expect(component.enabled_callback).to eq(callback)
    end

    it "converts string page/slot/name to symbols" do
      component = described_class.new(
        page: "index", slot: "toolbar_end", name: "my_button",
        partial: "some/partial"
      )

      expect(component.page).to eq(:index)
      expect(component.slot).to eq(:toolbar_end)
      expect(component.name).to eq(:my_button)
    end

    it "defaults position to 10" do
      component = described_class.new(
        page: :index, slot: :toolbar_end, name: :test,
        partial: "some/partial"
      )

      expect(component.position).to eq(10)
    end
  end

  describe "#enabled?" do
    it "returns true when no callback is set" do
      component = described_class.new(
        page: :index, slot: :toolbar_end, name: :test,
        partial: "some/partial"
      )

      expect(component.enabled?(double("context"))).to be true
    end

    it "delegates to callback when set" do
      context = double("context")
      callback = ->(ctx) { ctx == context }

      component = described_class.new(
        page: :index, slot: :toolbar_end, name: :test,
        partial: "some/partial", enabled: callback
      )

      expect(component.enabled?(context)).to be true
      expect(component.enabled?(double("other"))).to be false
    end

    it "returns false when callback returns false" do
      component = described_class.new(
        page: :index, slot: :toolbar_end, name: :test,
        partial: "some/partial", enabled: ->(_ctx) { false }
      )

      expect(component.enabled?(double("context"))).to be false
    end
  end
end
