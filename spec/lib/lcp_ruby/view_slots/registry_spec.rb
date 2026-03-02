require "spec_helper"

RSpec.describe LcpRuby::ViewSlots::Registry do
  before { described_class.clear! }

  describe ".register and .components_for" do
    it "round-trips a component" do
      described_class.register(
        page: :index, slot: :toolbar_end, name: :my_button,
        partial: "my/partial", position: 5
      )

      components = described_class.components_for(:index, :toolbar_end)
      expect(components.size).to eq(1)
      expect(components.first.name).to eq(:my_button)
      expect(components.first.partial).to eq("my/partial")
      expect(components.first.position).to eq(5)
    end

    it "stores enabled callback" do
      callback = ->(ctx) { false }
      described_class.register(
        page: :index, slot: :toolbar_end, name: :conditional,
        partial: "my/partial", enabled: callback
      )

      component = described_class.components_for(:index, :toolbar_end).first
      expect(component.enabled?(double("context"))).to be false
    end
  end

  describe "position ordering" do
    it "returns components sorted by position" do
      described_class.register(page: :index, slot: :toolbar_end, name: :third,  partial: "p3", position: 30)
      described_class.register(page: :index, slot: :toolbar_end, name: :first,  partial: "p1", position: 5)
      described_class.register(page: :index, slot: :toolbar_end, name: :second, partial: "p2", position: 15)

      names = described_class.components_for(:index, :toolbar_end).map(&:name)
      expect(names).to eq([ :first, :second, :third ])
    end
  end

  describe "same-name replacement" do
    it "replaces a component with the same name in the same slot" do
      described_class.register(page: :index, slot: :toolbar_end, name: :button, partial: "original", position: 10)
      described_class.register(page: :index, slot: :toolbar_end, name: :button, partial: "override", position: 5)

      components = described_class.components_for(:index, :toolbar_end)
      expect(components.size).to eq(1)
      expect(components.first.partial).to eq("override")
      expect(components.first.position).to eq(5)
    end
  end

  describe ".registered?" do
    it "returns true for registered component" do
      described_class.register(page: :index, slot: :filter_bar, name: :search, partial: "p")

      expect(described_class.registered?(:index, :filter_bar, :search)).to be true
    end

    it "returns false for unregistered component" do
      expect(described_class.registered?(:index, :filter_bar, :nonexistent)).to be false
    end
  end

  describe ".register_built_ins!" do
    it "registers all BUILT_IN_COMPONENTS" do
      described_class.register_built_ins!

      described_class::BUILT_IN_COMPONENTS.each do |attrs|
        expect(
          described_class.registered?(attrs[:page], attrs[:slot], attrs[:name])
        ).to be(true), "Expected #{attrs[:page]}:#{attrs[:slot]}:#{attrs[:name]} to be registered"
      end
    end

    it "registers the correct number of built-in components" do
      described_class.register_built_ins!

      total = described_class::BUILT_IN_COMPONENTS.size
      all_keys = described_class::BUILT_IN_COMPONENTS.map { |a| "#{a[:page]}:#{a[:slot]}" }.uniq
      registered_count = all_keys.sum { |key| described_class.components_for(*key.split(":").map(&:to_sym)).size }

      expect(registered_count).to eq(total)
    end
  end

  describe ".clear!" do
    it "removes all registered components" do
      described_class.register(page: :index, slot: :toolbar_end, name: :button, partial: "p")
      described_class.clear!

      expect(described_class.components_for(:index, :toolbar_end)).to be_empty
      expect(described_class.registered?(:index, :toolbar_end, :button)).to be false
    end
  end

  describe "slot isolation" do
    it "does not mix components from different slots" do
      described_class.register(page: :index, slot: :toolbar_start, name: :a, partial: "pa")
      described_class.register(page: :index, slot: :toolbar_end,   name: :b, partial: "pb")

      start_names = described_class.components_for(:index, :toolbar_start).map(&:name)
      end_names   = described_class.components_for(:index, :toolbar_end).map(&:name)

      expect(start_names).to eq([ :a ])
      expect(end_names).to eq([ :b ])
    end

    it "does not mix components from different pages" do
      described_class.register(page: :index, slot: :toolbar_end, name: :a, partial: "pa")
      described_class.register(page: :show,  slot: :toolbar_end, name: :b, partial: "pb")

      index_names = described_class.components_for(:index, :toolbar_end).map(&:name)
      show_names  = described_class.components_for(:show, :toolbar_end).map(&:name)

      expect(index_names).to eq([ :a ])
      expect(show_names).to eq([ :b ])
    end
  end
end
