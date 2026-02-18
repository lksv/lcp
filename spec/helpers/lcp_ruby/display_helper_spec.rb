require "spec_helper"

RSpec.describe LcpRuby::DisplayHelper, type: :helper do
  include described_class

  describe "#render_display_value" do
    it "returns value unchanged for nil display_type" do
      expect(render_display_value("hello", nil)).to eq("hello")
    end

    it "returns value unchanged for blank display_type" do
      expect(render_display_value("hello", "")).to eq("hello")
    end

    it "renders heading as strong tag" do
      result = render_display_value("Title", "heading")
      expect(result).to include("<strong>")
      expect(result).to include("Title")
    end

    it "renders badge with default style" do
      result = render_display_value("active", "badge")
      expect(result).to include("badge")
      expect(result).to include("active")
    end

    it "renders badge with color_map" do
      result = render_display_value("active", "badge", { "color_map" => { "active" => "green" } })
      expect(result).to include("background: #28a745")
      expect(result).to include("active")
    end

    it "renders truncate with default max" do
      long_text = "a" * 100
      result = render_display_value(long_text, "truncate")
      # The truncated output includes HTML tags and ... so just check it's not the full text
      expect(result.to_s).to include("...")
    end

    it "renders truncate with custom max" do
      result = render_display_value("Hello World Foo Bar", "truncate", { "max" => 10 })
      expect(result).to include("...")
    end

    it "does not truncate short text" do
      result = render_display_value("short", "truncate", { "max" => 50 })
      expect(result).to eq("short")
    end

    it "renders boolean_icon true" do
      result = render_display_value(true, "boolean_icon")
      expect(result).to include("lcp-bool-true")
      expect(result).to include("Yes")
    end

    it "renders boolean_icon false" do
      result = render_display_value(false, "boolean_icon")
      expect(result).to include("lcp-bool-false")
      expect(result).to include("No")
    end

    it "renders progress_bar" do
      result = render_display_value(75, "progress_bar")
      expect(result).to include("lcp-progress-bar")
      expect(result).to include("75%")
    end

    it "renders progress_bar with custom max" do
      result = render_display_value(50, "progress_bar", { "max" => 200 })
      expect(result).to include("25%")
    end

    it "renders image with default size" do
      result = render_display_value("https://example.com/img.png", "image")
      expect(result).to include("<img")
      expect(result).to include("120px")
    end

    it "renders image with custom size" do
      result = render_display_value("https://example.com/img.png", "image", { "size" => "large" })
      expect(result).to include("240px")
    end

    it "renders nil for blank image" do
      result = render_display_value("", "image")
      expect(result).to be_nil
    end

    it "renders avatar" do
      result = render_display_value("https://example.com/avatar.png", "avatar")
      expect(result).to include("lcp-avatar")
    end

    it "renders currency with defaults" do
      result = render_display_value(1234.5, "currency")
      expect(result).to include("1,234.50")
    end

    it "renders currency with custom unit" do
      result = render_display_value(100, "currency", { "currency" => "EUR" })
      expect(result).to include("EUR")
    end

    it "renders percentage" do
      result = render_display_value(75.5, "percentage")
      expect(result).to include("75.5%")
    end

    it "renders formatted number" do
      result = render_display_value(1234567, "number")
      expect(result).to include("1,234,567")
    end

    it "renders date with default format" do
      date = Date.new(2024, 3, 15)
      result = render_display_value(date, "date")
      expect(result).to eq("2024-03-15")
    end

    it "renders date with custom format" do
      date = Date.new(2024, 3, 15)
      result = render_display_value(date, "date", { "format" => "%d/%m/%Y" })
      expect(result).to eq("15/03/2024")
    end

    it "renders relative_date" do
      date = 2.days.ago
      result = render_display_value(date, "relative_date")
      expect(result).to include("ago")
    end

    it "renders email_link" do
      result = render_display_value("test@example.com", "email_link")
      expect(result).to include("mailto:test@example.com")
    end

    it "renders phone_link" do
      result = render_display_value("+1234567890", "phone_link")
      expect(result).to include("tel:+1234567890")
    end

    it "renders url_link" do
      result = render_display_value("https://example.com", "url_link")
      expect(result).to include('target="_blank"')
      expect(result).to include("https://example.com")
    end

    it "renders color_swatch" do
      result = render_display_value("#ff0000", "color_swatch")
      expect(result).to include("lcp-color-swatch")
      expect(result).to include("#ff0000")
    end

    it "renders rating display" do
      result = render_display_value(3, "rating")
      expect(result).to include("lcp-rating-display")
      # 3 filled stars + 2 empty stars
      expect(result).to include("&#9733;" * 3)
      expect(result).to include("&#9734;" * 2)
    end

    it "renders code" do
      result = render_display_value("console.log()", "code")
      expect(result).to include("lcp-code")
      expect(result).to include("console.log()")
    end

    it "renders file_size" do
      result = render_display_value(1024, "file_size")
      expect(result).to include("1 KB")
    end

    it "renders rich_text" do
      result = render_display_value("<p>Hello</p>", "rich_text")
      expect(result).to include("rich-text")
      expect(result).to include("<p>Hello</p>")
    end

    it "renders link display type" do
      result = render_display_value("some text", "link")
      expect(result).to eq("some text")
    end

    it "returns value for unknown display type" do
      expect(render_display_value("hello", "unknown_type")).to eq("hello")
    end

    describe "collection display type" do
      it "renders array items joined by separator" do
        result = render_display_value(%w[Alice Bob Charlie], "collection")
        expect(result).to include("Alice")
        expect(result).to include("Bob")
        expect(result).to include("Charlie")
      end

      it "renders with custom separator" do
        result = render_display_value(%w[A B C], "collection", { "separator" => " | " })
        expect(result.to_s).to include(" | ")
      end

      it "applies limit and overflow" do
        result = render_display_value(%w[A B C D E], "collection", { "limit" => 3, "overflow" => "..." })
        expect(result.to_s).to include("A")
        expect(result.to_s).to include("B")
        expect(result.to_s).to include("C")
        expect(result.to_s).to include("...")
        expect(result.to_s).not_to include("D")
      end

      it "does not show overflow when items fit within limit" do
        result = render_display_value(%w[A B], "collection", { "limit" => 3 })
        expect(result.to_s).not_to include("...")
      end

      it "handles empty array" do
        result = render_display_value([], "collection")
        expect(result.to_s).to eq("")
      end

      it "wraps non-array value in array" do
        result = render_display_value("solo", "collection")
        expect(result.to_s).to include("solo")
      end

      it "applies item_display to each item" do
        result = render_display_value(%w[active inactive], "collection", {
          "item_display" => "badge"
        })
        expect(result.to_s).to include("badge")
      end
    end

    describe "custom renderer delegation" do
      before { LcpRuby::Display::RendererRegistry.clear! }

      it "delegates to registered custom renderer" do
        test_class = Class.new(LcpRuby::Display::BaseRenderer) do
          def render(value, options = {}, record: nil, view_context: nil)
            "custom:#{value}"
          end
        end
        LcpRuby::Display::RendererRegistry.register("my_renderer", test_class)

        result = render_display_value("test", "my_renderer")
        expect(result).to eq("custom:test")
      end

      it "falls back to value when renderer not found" do
        result = render_display_value("test", "nonexistent_renderer")
        expect(result).to eq("test")
      end
    end

    context "XSS protection" do
      it "strips script tags from rich_text" do
        result = render_display_value('<script>alert("xss")</script><p>Safe</p>', "rich_text")
        expect(result).not_to include("<script>")
        expect(result).to include("<p>Safe</p>")
      end

      it "strips iframe tags from rich_text" do
        result = render_display_value('<iframe src="evil.com"></iframe><p>OK</p>', "rich_text")
        expect(result).not_to include("<iframe")
        expect(result).to include("<p>OK</p>")
      end

      it "preserves safe HTML in rich_text" do
        result = render_display_value('<strong>Bold</strong> and <em>italic</em>', "rich_text")
        expect(result).to include("<strong>Bold</strong>")
        expect(result).to include("<em>italic</em>")
      end
    end

    context "color_swatch safety" do
      it "rejects malicious CSS injection in color_swatch" do
        result = render_display_value("red;background:url(evil)", "color_swatch")
        expect(result).to include("background:#ccc;")
      end

      it "allows valid hex color" do
        result = render_display_value("#ff0000", "color_swatch")
        expect(result).to include("background:#ff0000;")
      end

      it "allows valid named color" do
        result = render_display_value("rebeccapurple", "color_swatch")
        expect(result).to include("background:rebeccapurple;")
      end

      it "allows valid short hex color" do
        result = render_display_value("#fff", "color_swatch")
        expect(result).to include("background:#fff;")
      end

      it "allows rgb() color" do
        result = render_display_value("rgb(255, 0, 0)", "color_swatch")
        expect(result).to include("background:rgb(255, 0, 0);")
      end

      it "allows rgba() color" do
        result = render_display_value("rgba(255, 0, 0, 0.5)", "color_swatch")
        expect(result).to include("background:rgba(255, 0, 0, 0.5);")
      end

      it "allows hsl() color" do
        result = render_display_value("hsl(120, 100%, 50%)", "color_swatch")
        expect(result).to include("background:hsl(120, 100%, 50%);")
      end
    end
  end
end
