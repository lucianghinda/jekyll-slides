# frozen_string_literal: true

require "minitest/autorun"

class ThemeContrastTest < Minitest::Test
  TOKENS = File.expand_path("../src/css/components/_tokens.css", __dir__)
  THEMES = %w[
    midnight minimal-light minimal-dark ruby
    catppuccin-latte catppuccin-frappe catppuccin-macchiato catppuccin-mocha
  ].freeze

  # Everything a window needs to repaint itself when a single editor or
  # terminal block carries a theme attribute. A token missing here would leave
  # that window half-themed: the deck's text colour on the override's surface.
  WINDOW_TOKENS = (
    %w[
      --slide-fg --slide-muted --slide-accent --slide-accent-strong --slide-link
      --slide-code-surface --slide-code-header --slide-code-border --slide-code-shadow
      --slide-code-highlight-surface --slide-code-highlight-border --slide-code-focus-surface
      --slide-highlight --slide-focus
    ] +
    %w[
      comment keyword string number function operator punctuation
      name variable symbol builtin constant error
    ].map { |token| "--slide-syntax-#{token}" }
  ).freeze

  # A slide background and a type scale belong to the deck, not to one window.
  DECK_ONLY_TOKENS = %w[
    --slide-bg --slide-selection --slide-grid-line --slide-spotlight
    --slide-gradient-start --slide-gradient-end --slide-quote
    --slide-heading-font-size --slide-title-font-size
    --slide-body-font-size --slide-statement-font-size
  ].freeze

  THEMES.each do |theme|
    define_method("test_#{theme.tr('-', '_')}_text_contrast_on_every_code_surface") do
      assert_readable_on_every_code_surface(theme, theme_colors(theme))
      colors = theme_colors(theme)

      assert_operator contrast(rgb(colors.fetch("--slide-fg")), rgb(colors.fetch("--slide-bg"))), :>=, 7
    end

    define_method("test_#{theme.tr('-', '_')}_repaints_a_single_window_on_its_own") do
      colors = code_theme_colors(theme)

      assert_empty WINDOW_TOKENS - colors.keys,
                   "[data-code-theme=\"#{theme}\"] must define every window token so one block can be themed alone"
      assert_readable_on_every_code_surface(theme, colors)
      assert_readable_title_bar(theme, colors)
    end
  end

  # macos-light is a component-only palette: it repaints one editor or terminal
  # and nothing around it, so it never appears in THEMES and never carries a
  # slide background or type scale.
  def test_macos_light_is_a_complete_window_palette_a_deck_cannot_select
    colors = code_theme_colors("macos-light")

    assert_empty WINDOW_TOKENS - colors.keys,
                 '[data-code-theme="macos-light"] must define every window token'
    assert_readable_on_every_code_surface("macos-light", colors)
    assert_readable_title_bar("macos-light", colors)

    refute_includes THEMES, "macos-light"
    assert_empty declarations(%([data-theme="macos-light"])),
                 "a deck must not be able to select macos-light"
    assert_empty colors.keys.grep(/\A--slide-dot-/), "macos-light must not repaint the traffic lights"
    assert_empty colors.keys & DECK_ONLY_TOKENS, "macos-light must not carry deck background or layout values"
  end

  def test_macos_light_is_a_light_window_with_dark_text
    colors = code_theme_colors("macos-light")

    assert_operator luminance(rgb(colors.fetch("--slide-code-surface"))), :>, 0.85
    assert_operator luminance(rgb(colors.fetch("--slide-code-header"))), :>, 0.8
    assert_operator contrast(rgb(colors.fetch("--slide-fg")), rgb(colors.fetch("--slide-code-surface"))), :>=, 7
  end

  def test_minimal_light_is_a_light_surface_with_dark_text
    colors = theme_colors("minimal-light")

    assert_operator luminance(rgb(colors.fetch("--slide-bg"))), :>, 0.8
    assert_operator luminance(rgb(colors.fetch("--slide-fg"))), :<, 0.1
    assert_operator luminance(rgb(colors.fetch("--slide-code-surface"))), :>, 0.7
  end

  # A flat near-white deck, not the warm paper tint it started as: a projected
  # slide that leans yellow reads as a colour cast rather than as white.
  def test_minimal_light_is_neutral_and_near_white
    colors = theme_colors("minimal-light")

    assert_operator luminance(rgb(colors.fetch("--slide-bg"))), :>, 0.93
    %w[--slide-bg --slide-code-surface --slide-code-header].each do |token|
      channels = rgb(colors.fetch(token))

      assert_operator channels.max - channels.min, :<=, 4, "#{token} must stay neutral, not paper-tinted"
    end
  end

  def test_catppuccin_latte_is_the_light_flavor_and_the_rest_are_dark
    assert_operator luminance(rgb(theme_colors("catppuccin-latte").fetch("--slide-bg"))), :>, 0.8
    %w[catppuccin-frappe catppuccin-macchiato catppuccin-mocha].each do |theme|
      assert_operator luminance(rgb(theme_colors(theme).fetch("--slide-bg"))), :<, 0.1, theme
    end
  end

  def test_window_controls_keep_the_macos_traffic_light_colors_in_every_theme
    root = declarations(":root")

    assert_equal "#ff5f57", root.fetch("--slide-dot-close")
    assert_equal "#febc2e", root.fetch("--slide-dot-minimize")
    assert_equal "#28c840", root.fetch("--slide-dot-maximize")
    THEMES.each do |theme|
      overrides = declarations(%([data-theme="#{theme}"])).keys.grep(/\A--slide-dot-/)

      assert_empty overrides, "#{theme} must not repaint the traffic lights"
    end
  end

  private

  def assert_readable_on_every_code_surface(theme, colors)
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
  end

  # The filename and the editor language both sit on the title bar in
  # --slide-muted, so that pair is its own contrast surface.
  def assert_readable_title_bar(theme, colors)
    header = rgb(colors.fetch("--slide-code-header"))

    assert_operator contrast(rgb(colors.fetch("--slide-muted")), header), :>=, 4.5,
                    "#{theme} title and language on the title bar"
  end

  def theme_colors(theme)
    declarations(%([data-theme="#{theme}"]))
  end

  def code_theme_colors(theme)
    declarations(%([data-code-theme="#{theme}"]))
  end

  # Merges every rule whose selector list names this selector, in source order,
  # the way the cascade resolves them on one element.
  def declarations(selector)
    source = File.read(TOKENS).gsub(%r{/\*.*?\*/}m, "")
    source.scan(/([^{}]*)\{([^}]*)\}/m).each_with_object({}) do |(selectors, body), merged|
      next unless selectors.split(",").any? { |candidate| candidate.strip == selector }

      merged.merge!(body.scan(/(--[a-z-]+):\s*([^;]+);/).to_h)
    end
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
