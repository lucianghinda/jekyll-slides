# frozen_string_literal: true

require "minitest/autorun"

class ThemeContrastTest < Minitest::Test
  TOKENS = File.expand_path("../src/css/components/_tokens.css", __dir__)

  %w[midnight minimal-light minimal-dark ruby].each do |theme|
    define_method("test_#{theme.tr('-', '_')}_text_contrast_on_every_code_surface") do
      colors = theme_colors(theme)
      base = rgb(colors.fetch("--slide-code-surface"))
      surfaces = {
        "normal" => base,
        "highlight" => composite(colors.fetch("--slide-code-highlight-surface"), base),
        "focus" => composite(colors.fetch("--slide-code-focus-surface"), base)
      }
      text = colors.select { |key, _| key.start_with?("--slide-syntax-") || key == "--slide-muted" }

      refute_empty text
      surfaces.each do |state, background|
        text.each do |token, color|
          assert_operator contrast(rgb(color), background), :>=, 4.5, "#{theme} #{token} on #{state}"
        end
      end
      assert_operator contrast(rgb(colors.fetch("--slide-fg")), rgb(colors.fetch("--slide-bg"))), :>=, 7
    end
  end

  def test_minimal_light_is_a_light_surface_with_dark_text
    colors = theme_colors("minimal-light")

    assert_operator luminance(rgb(colors.fetch("--slide-bg"))), :>, 0.8
    assert_operator luminance(rgb(colors.fetch("--slide-fg"))), :<, 0.1
    assert_operator luminance(rgb(colors.fetch("--slide-code-surface"))), :>, 0.7
  end

  private

  def theme_colors(theme)
    block = File.read(TOKENS)[/\[data-theme="#{Regexp.escape(theme)}"\]\s*\{([^}]+)\}/, 1]
    block.scan(/(--[a-z-]+):\s*([^;]+);/).to_h
  end

  def rgb(color)
    color.delete_prefix("#").scan(/../).map { |channel| channel.to_i(16).to_f }
  end

  def composite(color, background)
    return rgb(color) if color.start_with?("#")

    red, green, blue, alpha = color.scan(/[\d.]+/).map(&:to_f)
    [red, green, blue].zip(background).map { |fg, bg| (fg * alpha) + (bg * (1 - alpha)) }
  end

  def luminance(channels)
    linear = channels.map do |channel|
      channel /= 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    linear.zip([0.2126, 0.7152, 0.0722]).sum { |channel, weight| channel * weight }
  end

  def contrast(first, second)
    low, high = [luminance(first), luminance(second)].sort
    (high + 0.05) / (low + 0.05)
  end
end
