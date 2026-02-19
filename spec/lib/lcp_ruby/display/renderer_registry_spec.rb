require "spec_helper"

RSpec.describe LcpRuby::Display::RendererRegistry do
  before { described_class.clear! }

  let(:test_renderer_class) do
    Class.new(LcpRuby::Display::BaseRenderer) do
      def render(value, options = {}, record: nil, view_context: nil)
        "rendered:#{value}"
      end
    end
  end

  describe ".register and .renderer_for" do
    it "registers a renderer class and returns an instance on lookup" do
      described_class.register("test", test_renderer_class)

      renderer = described_class.renderer_for("test")
      expect(renderer).to be_a(test_renderer_class)
      expect(renderer.render("hello")).to eq("rendered:hello")
    end

    it "stores instances, not classes" do
      described_class.register("test", test_renderer_class)

      renderer = described_class.renderer_for("test")
      expect(renderer).to be_an_instance_of(test_renderer_class)
    end

    it "returns nil for unknown renderer" do
      expect(described_class.renderer_for("unknown")).to be_nil
    end
  end

  describe ".registered?" do
    it "returns true for registered renderer" do
      described_class.register("test", test_renderer_class)
      expect(described_class.registered?("test")).to be true
    end

    it "returns false for unregistered renderer" do
      expect(described_class.registered?("unknown")).to be false
    end
  end

  describe ".clear!" do
    it "removes all registered renderers" do
      described_class.register("test", test_renderer_class)
      described_class.clear!

      expect(described_class.renderer_for("test")).to be_nil
    end
  end

  describe ".register_built_ins!" do
    it "registers all built-in renderers" do
      described_class.register_built_ins!

      LcpRuby::Display::RendererRegistry::BUILT_IN_RENDERERS.each_key do |key|
        expect(described_class.registered?(key)).to be true
      end
    end

    it "creates renderer instances for all built-ins" do
      described_class.register_built_ins!

      renderer = described_class.renderer_for("badge")
      expect(renderer).to be_a(LcpRuby::Display::BaseRenderer)
    end
  end

  describe ".discover!" do
    it "discovers renderers from directory" do
      Dir.mktmpdir do |tmpdir|
        renderers_dir = File.join(tmpdir, "renderers")
        FileUtils.mkdir_p(renderers_dir)

        # Write a test renderer file
        File.write(File.join(renderers_dir, "test_renderer.rb"), <<~'RUBY')
          module LcpRuby::HostRenderers
            class TestRenderer < LcpRuby::Display::BaseRenderer
              def render(value, options = {}, record: nil, view_context: nil)
                "discovered:#{value}"
              end
            end
          end
        RUBY

        described_class.discover!(tmpdir)

        expect(described_class.registered?("test_renderer")).to be true
        expect(described_class.renderer_for("test_renderer").render("foo")).to eq("discovered:foo")
      end
    end

    it "skips when renderers directory does not exist" do
      Dir.mktmpdir do |tmpdir|
        expect { described_class.discover!(tmpdir) }.not_to raise_error
      end
    end
  end
end
