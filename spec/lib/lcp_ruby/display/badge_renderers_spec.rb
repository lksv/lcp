require "spec_helper"

RSpec.describe "Badge Renderers" do
  let(:view_context) do
    view = Object.new
    # Mimics Rails content_tag: content_tag(tag, content, opts) or content_tag(tag, opts, &block)
    def view.content_tag(tag, content_or_opts = nil, opts = nil, &block)
      if block
        # When block is given, second arg is options hash
        attrs = format_attrs(content_or_opts.is_a?(Hash) ? content_or_opts : (opts || {}))
        inner = block.call
        "<#{tag}#{attrs}>#{inner}</#{tag}>"
      else
        attrs = format_attrs(opts || {})
        "<#{tag}#{attrs}>#{content_or_opts}</#{tag}>"
      end
    end

    def view.format_attrs(opts)
      return "" if opts.nil? || opts.empty?
      opts.compact.map { |k, v| " #{k}=\"#{v}\"" }.join
    end

    view
  end

  describe LcpRuby::Display::CountBadge do
    subject(:renderer) { described_class.new }

    it "renders a pill for positive integer" do
      result = renderer.render(5, {}, view_context: view_context)

      expect(result).to include("5")
      expect(result).to include("lcp-menu-badge")
    end

    it "returns nil for zero" do
      result = renderer.render(0, {}, view_context: view_context)

      expect(result).to be_nil
    end

    it "returns nil for negative integer" do
      result = renderer.render(-1, {}, view_context: view_context)

      expect(result).to be_nil
    end

    it "returns nil for nil" do
      result = renderer.render(nil, {}, view_context: view_context)

      expect(result).to be_nil
    end

    it "returns nil for non-integer" do
      result = renderer.render("5", {}, view_context: view_context)

      expect(result).to be_nil
    end
  end

  describe LcpRuby::Display::TextBadge do
    subject(:renderer) { described_class.new }

    it "renders text from string value" do
      result = renderer.render("URGENT", {}, view_context: view_context)

      expect(result).to include("URGENT")
      expect(result).to include("lcp-menu-badge-text")
    end

    it "renders text from hash with text key" do
      result = renderer.render({ "text" => "NEW" }, {}, view_context: view_context)

      expect(result).to include("NEW")
    end

    it "applies color from hash" do
      result = renderer.render({ "text" => "ALERT", "color" => "#ff0000" }, {}, view_context: view_context)

      expect(result).to include("background:#ff0000")
    end

    it "applies color from options when value is string" do
      result = renderer.render("ALERT", { "color" => "#dc3545" }, view_context: view_context)

      expect(result).to include("background:#dc3545")
    end

    it "returns nil for blank string" do
      result = renderer.render("", {}, view_context: view_context)

      expect(result).to be_nil
    end

    it "returns nil for hash with blank text" do
      result = renderer.render({ "text" => "" }, {}, view_context: view_context)

      expect(result).to be_nil
    end
  end

  describe LcpRuby::Display::IconBadge do
    subject(:renderer) { described_class.new }

    it "renders an icon element from string value" do
      result = renderer.render("check", {}, view_context: view_context)

      expect(result).to include("lcp-menu-badge-icon")
      expect(result).to include("lcp-icon-check")
    end

    it "renders icon from hash with icon key" do
      result = renderer.render({ "icon" => "warning" }, {}, view_context: view_context)

      expect(result).to include("lcp-icon-warning")
    end

    it "applies color from hash" do
      result = renderer.render({ "icon" => "check", "color" => "#28a745" }, {}, view_context: view_context)

      expect(result).to include("color:#28a745")
    end

    it "applies color from options when value is string" do
      result = renderer.render("check", { "color" => "#28a745" }, view_context: view_context)

      expect(result).to include("color:#28a745")
    end

    it "returns nil for blank string" do
      result = renderer.render("", {}, view_context: view_context)

      expect(result).to be_nil
    end
  end
end
