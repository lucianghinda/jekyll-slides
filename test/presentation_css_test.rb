# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"

class PresentationCssTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SOURCE_ROOT = File.join(ROOT, "src/css")
  APP_CSS = File.join(SOURCE_ROOT, "app.css")
  BUILT_CSS = File.join(ROOT, "assets/css/presentation.css")

  def source
    @source ||= Dir[File.join(SOURCE_ROOT, "**/*.css")].map { |path| File.read(path) }.join("\n")
  end

  def test_entrypoint_imports_each_component
    entrypoint = File.read(APP_CSS)

    assert_includes entrypoint, '@import "tailwindcss" source(none);'
    %w[_fonts _tokens _base _slides _code _chrome _print].each do |component|
      assert_includes entrypoint, %(@import "./components/#{component}.css";)
    end
  end

  THEMES = %w[
    minimal-light minimal-dark midnight ruby
    catppuccin-latte catppuccin-frappe catppuccin-macchiato catppuccin-mocha
  ].freeze

  def test_public_theme_and_layout_selectors_remain_available
    THEMES.each { |theme| assert_includes source, %(data-theme="#{theme}") }
    %w[title statement content code code-left code-right split-code code-result].each do |layout|
      assert_includes source, ".layout-#{layout}"
    end
    %w[plain gradient grid spotlight].each { |background| assert_includes source, ".bg-#{background}" }
  end

  def test_every_theme_is_also_available_to_a_single_window
    THEMES.each { |theme| assert_includes source, %([data-code-theme="#{theme}"]) }
  end

  # A component-only palette: available to one window, never to a deck, and it
  # has to reach the shipped stylesheet to be usable at all.
  def test_the_component_only_window_palette_ships_in_the_compiled_stylesheet
    assert_includes source, '[data-code-theme="macos-light"]'
    refute_includes source, '[data-theme="macos-light"]'
    assert_includes File.read(BUILT_CSS), "[data-code-theme=macos-light]"
  end

  def test_both_window_types_share_one_macos_title_bar
    # The terminal used to fake its bar with ::before, which cannot hold
    # traffic lights or a title. Both windows now render a real header.
    refute_match(/\.terminal-window::before/, source)
    assert_match(/\.code-window-header\s*\{[^}]*height:\s*var\(--slide-window-bar\)/, source)
    assert_match(/\.code-window-controls i\s*\{[^}]*var\(--slide-dot-rim\)/, source)
    %w[close minimize maximize].each do |control|
      assert_match(/background:\s*var\(--slide-dot-#{control}\)/, source)
    end
  end

  def test_window_titles_sit_after_the_traffic_lights
    caption = source[/\.code-window figcaption, \.terminal-window figcaption\s*\{([^}]*)\}/, 1]

    refute_nil caption
    assert_match(/top:\s*0/, caption)
    assert_match(/height:\s*var\(--slide-window-bar\)/, caption)
    assert_match(/line-height:\s*var\(--slide-window-bar\)/, caption)
    # line-height, not flex centering, so the one-line title can still ellipsize.
    assert_match(/text-overflow:\s*ellipsis/, caption)
    refute_match(/display:\s*flex/, caption)

    # The title now follows the controls instead of being centered over the bar.
    refute_match(/left:\s*50%/, caption)
    refute_match(/translateX\(-50%\)/, caption)
    assert_match(/inset-inline-start:\s*calc\([^;]*var\(--slide-window-controls\)/, caption)
    assert_match(/max-width:\s*max\(0px, calc\([^;]*var\(--slide-window-controls\)/, caption)

    # Both offsets are derived from the bar height, so sm, md, and lg align.
    assert_match(/--slide-window-controls:\s*calc\(var\(--slide-window-bar\) \* 1\.28\)/, source)
    %w[sm md lg].each do |size|
      assert_match(/\.code-window\.size-#{size}, \.terminal-window\.size-#{size} \{[^}]*--slide-window-bar:/, source)
    end
  end

  # Flat chrome, following the supplied macOS references: one solid title-bar
  # fill, a hairline border, and traffic lights with a rim but no gloss.
  def test_window_chrome_is_flat
    header = source[/\.code-window-header\s*\{([^}]*)\}/, 1]

    refute_nil header
    assert_match(/background:\s*var\(--slide-code-header\);/, header)
    assert_match(/border-bottom:\s*1px solid var\(--slide-code-border\)/, header)

    window = source[/\.code-window, \.terminal-window \{([^}]*)\}/, 1]

    refute_nil window
    assert_match(/border:\s*1px solid var\(--slide-code-border\)/, window)
    assert_match(/box-shadow:\s*0 12px 32px var\(--slide-code-shadow\);/, window)

    controls = source[/\.code-window-controls i\s*\{([^}]*)\}/, 1]

    assert_match(/box-shadow:\s*inset 0 0 0 1px var\(--slide-dot-rim\);/, controls)

    # The gradient, body inset, and control gloss are gone, and so are the
    # tokens that only ever fed them.
    refute_match(/linear-gradient/, header)
    refute_match(/--slide-surface-shine/, source)
    refute_match(/--slide-code-inset/, source)
    refute_match(/--slide-dot-gloss/, source)
  end

  def test_code_components_inherit_the_theme_monospace_font
    assert_match(/--font-slide-sans:\s*"Atkinson Hyperlegible Next"/, source)
    assert_match(/--font-slide-mono:\s*"Atkinson Hyperlegible Mono"/, source)
    assert_match(/\.code-window pre, \.terminal-window pre\s*\{[^}]*font-family:\s*inherit/m, source)
    assert_match(/\.code-window code, \.terminal-window code\s*\{[^}]*font:\s*inherit/m, source)
  end

  def test_contextual_code_and_line_numbers_are_not_faded
    refute_match(/\.code-window\.has-focus \.line:not\(\.is-focused\)\s*\{[^}]*opacity:/, source)
    refute_match(/\.code-window \.line::before\s*\{[^}]*opacity:\s*\./, source)
    assert_match(/\.code-window\.has-focus \.line\.is-focused\s*\{[^}]*border-inline-start-color:/, source)
  end

  def test_code_preserves_operator_shapes_and_exposes_overflow
    assert_match(/\.code-window, \.terminal-window\s*\{[^}]*font-variant-ligatures:\s*none/, source)
    refute_match(/scrollbar-width:\s*none|scrollbar-color:\s*transparent transparent/, source)
  end

  def test_css_owns_canvas_and_overview_scaling
    scale = /min\(tan\(atan2\(100cqw,\s*1920px\)\),\s*tan\(atan2\(100cqh,\s*1080px\)\)\)/
    supports = /\(width:\s*1cqw\)\s+and\s+\(height:\s*1cqh\)\s+and\s+\(transform:\s*scale\(tan\(atan2\(1px,\s*1px\)\)\)\)/
    unsupported = /not\s+\(\s*#{supports}\s*\)/

    assert_match(/\.presentation-root\.js \.slide-deck\s*\{[^}]*display:\s*flex[^}]*overflow:\s*visible/m, source)
    assert_match(/\.presentation-root\.js \.slide\s*\{[^}]*position:\s*relative[^}]*height:\s*auto/m, source)
    assert_match(/@supports\s+#{supports}\s*\{[^}]*\.presentation-root\.js\s*\{[^}]*overflow:\s*hidden/m, source)
    assert_match(/@supports\s+#{supports}\s*\{.*--slide-scale:\s*#{scale}.*transform:\s*translate\(-50%,\s*-50%\)\s*scale\(var\(--slide-scale,\s*1\)\)/m, source)
    assert_match(/--overview-slide-scale:[^;]*100cqw[^;]*;.*transform:\s*scale\(var\(--overview-slide-scale,\s*1\)\)/m, source)
    fallback_padding = /@supports\s+#{unsupported}\s*\{.*@media\s*\(max-width:\s*900px\).*
                        \.presentation-root\.js\s+\.slide-content\s*\{[^}]*padding:\s*56px/mx
    fallback_panes = /@supports\s+#{unsupported}\s*\{.*@media\s*\(max-width:\s*900px\).*
                      \.presentation-root\.js\s+\.layout-split-code\s+\.panes\s*\{[^}]*grid-template-columns:\s*1fr/mx
    assert_match(fallback_padding, source)
    assert_match(fallback_panes, source)

    javascript = File.read(File.join(ROOT, "assets/js/presentation.js"))
    refute_includes javascript, 'setProperty("--slide-scale"'
    refute_includes javascript, 'setProperty("--overview-slide-scale"'
    refute_match(/addEventListener\("resize"/, javascript)
  end

  def test_abs_corrects_the_safari_atan2_sign_bug_when_supported
    abs_supports = /@supports\s*\(transform:\s*scale\(abs\(-1\)\)\)/
    slide_scale_abs = /min\(\s*abs\(tan\(atan2\(100cqw,\s*1920px\)\)\)\s*,\s*abs\(tan\(atan2\(100cqh,\s*1080px\)\)\)\s*\)/
    overview_scale_abs = /abs\(tan\(atan2\(100cqw,\s*1920px\)\)\)/

    assert_match(/#{abs_supports}\s*\{[^}]*\.presentation-root\.js \.slide\s*\{[^}]*--slide-scale:\s*#{slide_scale_abs}/m, source)
    assert_match(/#{abs_supports}\s*\{[^}]*--overview-slide-scale:\s*#{overview_scale_abs}/m, source)

    abs_blocks = source.scan(/@supports\s*\(transform:\s*scale\(abs\(-1\)\)\)\s*\{(.*?)\n\}/m).flatten
    assert_equal 2, abs_blocks.size
    abs_blocks.each { |block| refute_match(/transform:/, block) }
  end

  def test_abs_override_follows_the_legacy_formula_in_the_compiled_stylesheet
    built = File.read(BUILT_CSS)

    abs_supports_offsets = built.enum_for(:scan, /@supports\s*\(transform:\s*scale\(abs\(-1\)\)\)/).map { Regexp.last_match.begin(0) }
    slide_scale_offsets = built.enum_for(:scan, "--slide-scale:").map { Regexp.last_match.begin(0) }
    overview_scale_offsets = built.enum_for(:scan, "--overview-slide-scale:").map { Regexp.last_match.begin(0) }

    assert_equal 2, abs_supports_offsets.size
    assert_equal 3, slide_scale_offsets.size
    assert_equal 3, overview_scale_offsets.size

    assert_operator slide_scale_offsets.first, :<, slide_scale_offsets.last
    assert_operator overview_scale_offsets.first, :<, overview_scale_offsets.last

    assert(
      abs_supports_offsets.any? { |offset| offset.between?(slide_scale_offsets.first, slide_scale_offsets[1]) },
      "expected the abs() @supports block to sit between the two --slide-scale declarations"
    )
    assert(
      abs_supports_offsets.any? { |offset| offset.between?(overview_scale_offsets.first, overview_scale_offsets[1]) },
      "expected the abs() @supports block to sit between the two --overview-slide-scale declarations"
    )
  end

  def test_direct_length_division_overrides_trigonometry_when_supported
    [source, File.read(BUILT_CSS)].each do |css|
      support = css.index(%r{@supports\s*\(transform:\s*scale\(calc\(1px\s*/\s*1px\)\)\)})
      refute_nil support, "direct division must be feature detected"
      slide = css.rindex("--slide-scale:")
      overview = css.rindex("--overview-slide-scale:")
      assert_operator slide, :>, support
      assert_operator overview, :>, support
      assert_match(%r{--slide-scale:\s*min\(calc\(100cqw\s*/\s*1920px\),\s*calc\(100cqh\s*/\s*1080px\)\)}, css)
      assert_match(%r{--overview-slide-scale:\s*calc\(100cqw\s*/\s*1920px\)}, css)
    end
  end

  def test_code_only_layout_and_chrome_do_not_compete_with_slide_content
    assert_match(/\.layout-code \.slide-content\s*\{[^}]*justify-content:\s*center/m, source)
    assert_match(/\.presentation-chrome\s*\{[^}]*pointer-events:\s*none/m, source)
    assert_match(/\.slide-controls\s*\{[^}]*position:\s*absolute/m, source)
    assert_match(/\.slide-progress\s*\{[^}]*position:\s*absolute[^}]*width:\s*100%/m, source)
  end

  # One inset for every layout, named once, so an overview preview and the
  # presented slide compose their content identically.
  def test_slide_content_uses_one_shared_inset_everywhere
    assert_match(/--slide-pad-block:\s*72px/, source)
    assert_match(/--slide-pad-inline:\s*80px/, source)
    assert_match(/\.slide-content\s*\{[^}]*padding:\s*var\(--slide-pad-block\)\s+var\(--slide-pad-inline\)/m, source)

    overview = source[/\.presentation-root\.js\.is-overview \.slide-content, [^{]+\{([^}]*)\}/, 1]

    refute_nil overview
    assert_match(/padding:\s*var\(--slide-pad-block\)\s+var\(--slide-pad-inline\)/, overview)
    refute_match(/\.slide-content\s*\{[^}]*padding:\s*108px/m, source)
    refute_match(/padding-inline:\s*180px/, source)
  end

  def test_overview_thumbnails_contribute_their_height_to_grid_rows
    assert_match(/\.presentation-root\.js\.is-overview \.slide, [^{]+\{[^}]*container-type:\s*inline-size/, source)
    assert_match(/\.presentation-root\.js\.is-overview \.slide-deck, [^{]+\{[^}]*align-content:\s*start/, source)
    assert_match(/\.presentation-root\.js\.is-overview \.slide-deck, [^{]+\{[^}]*grid-auto-rows:\s*max-content/, source)
    refute_match(/--overview-slide-scale:[^;]*100cqh/, source)
  end

  # Paragraphs, lists, quotes, and tables already carry a bottom margin. Code
  # blocks and figures carry none, so the prose after them used to sit flush
  # against them.
  def test_a_block_and_the_prose_after_it_keep_one_gap
    scope = ":where(.prose, .layout-split-code .pane)"

    # :is(), not :where(): the rule has to outrank the zero-specificity
    # `margin: 0 0 28px` shorthand that already sets margin-top on a paragraph.
    assert_match(
      /#{Regexp.escape(scope)} > :is\(pre, div\.highlighter-rouge, figure\) \+ \*\s*\{[^}]*margin-block-start:\s*28px/,
      source
    )
    %w[p blockquote].each do |element|
      assert_match(/#{Regexp.escape(scope)} #{element} \{[^}]*margin: 0 0 28px/, source)
    end
    assert_match(/#{Regexp.escape(scope)} :where\(ul, ol\) \{[^}]*margin: 0 0 28px/, source)

    # A block that already ends with a margin must not also gain a leading one:
    # .layout-split-code .pane is a flex column, where sibling margins add up
    # instead of collapsing.
    gap_rule = source[/#{Regexp.escape(scope)} > :is\(([^)]*)\) \+ \*/, 1]

    refute_nil gap_rule
    %w[p table blockquote ul ol].each do |element|
      refute_includes gap_rule.split(/,\s*/), element
    end

    # The gap belongs to the outer block; a code window keeps its own padding.
    assert_match(/\.code-window pre, \.terminal-window pre\s*\{[^}]*margin:\s*0/, source)
  end

  def test_a_plain_fence_still_reads_as_code
    assert_match(
      /:where\(\.prose, \.layout-split-code \.pane\) > pre\s*\{[^}]*font-family:\s*var\(--font-slide-mono\)/,
      source
    )
  end

  # A container-wide measure clipped diagrams and code, which carry no measure
  # of their own, while every text element already caps itself in ch.
  def test_code_and_tables_are_not_clipped_by_the_prose_reading_measure
    refute_match(/\.layout-content \.prose\s*\{[^}]*max-width:\s*920px/, source)
    assert_match(/:where\(\.prose, \.layout-split-code \.pane\) p \{[^}]*max-width: 40ch/, source)
    assert_match(/:where\(\.prose, \.layout-split-code \.pane\) :where\(h1, h2, h3, h4\) \{[^}]*max-width: 16ch/, source)
  end

  def test_code_windows_can_shrink_to_make_their_pre_scrollable
    assert_match(/\.visual, \.stack\s*\{[^}]*display:\s*flex[^}]*flex-direction:\s*column/, source)
    assert_match(/\.code-window, \.terminal-window\s*\{[^}]*min-height:\s*0[^}]*max-height:\s*100%/, source)
    assert_match(/\.code-window, \.terminal-window\s*\{[^}]*display:\s*flex[^}]*flex-direction:\s*column/, source)
    assert_match(/\.code-window pre, \.terminal-window pre\s*\{[^}]*min-height:\s*0[^}]*overflow:\s*auto/, source)
  end

  def test_liquid_highlight_figures_share_the_code_surface_and_syntax_palette
    assert_match(/\.highlighter-rouge \.highlight, figure\.highlight\s*\{[^}]*background:\s*var\(--slide-code-surface\)/, source)
    %w[comment keyword string number function operator punctuation name variable symbol builtin constant error].each do |token|
      assert_match(/:is\(\.highlighter-rouge, figure\.highlight\)[^{]+\{[^}]*color:\s*var\(--slide-syntax-#{token}\)/, source)
    end
  end

  def test_side_by_side_code_panes_allow_their_windows_to_shrink
    assert_match(/\.panes\s*\{[^}]*grid-template-rows:\s*minmax\(0,\s*1fr\)/, source)
    assert_match(/\.pane\s*\{[^}]*min-height:\s*0[^}]*max-height:\s*100%/, source)
  end

  def test_paragraph_reveals_reserve_their_space_and_fade_in_once
    assert_match(
      /\.presentation-root\.js \.fragment:not\(\.is-revealed\)\s*\{[^}]*visibility:\s*hidden[^}]*opacity:\s*0[^}]*transform:\s*translateY\(6px\)/,
      source
    )
    assert_match(
      /\.presentation-root\.js \.fragment\s*\{[^}]*transition:\s*opacity \.18s ease-out, transform \.18s ease-out/,
      source
    )
    # display: none would reflow the rest of the slide on every reveal.
    refute_match(/\.fragment:not\(\.is-revealed\)\s*\{[^}]*display:\s*none/, source)
    assert_match(
      /\.presentation-root\.is-reduced-motion \.fragment, [^{]+\{[^}]*transition:\s*none/,
      source
    )
  end

  # Hiding belongs to the enhanced presentation only. Stacked document flow,
  # print, and no-JavaScript output have no way to reveal a paragraph, so they
  # must never hide one.
  def test_reveals_hide_nothing_outside_a_working_presentation_canvas
    canvas_blocks = source.scan(
      /@supports \(width: 1cqw\) and \(height: 1cqh\) and \(transform: scale\(tan\(atan2\(1px, 1px\)\)\)\) \{(.*?)\n\}/m
    ).flatten

    refute_empty canvas_blocks
    assert(
      canvas_blocks.any? { |block| block.include?(".fragment:not(.is-revealed)") },
      "reveal hiding must be gated on the same @supports as the slide canvas"
    )
    hiding_rules = source.scan(/^[^\n{]*\.fragment:not\(\.is-revealed\)[^\n{]*\{/)

    assert_equal 1, hiding_rules.length, "one place hides a paragraph, so one place can get it wrong"

    print_rules = source[/@media print\s*\{.*\}\s*\z/m]

    assert_match(/\.fragment \{[^}]*visibility:\s*visible\s*!important/, print_rules)
  end

  def test_no_javascript_mode_keeps_complete_slides_in_document_flow
    assert_match(/\.presentation-root:not\(\.js\) \.slide-deck\s*\{[^}]*display:\s*flex[^}]*overflow:\s*visible/m, source)
    assert_match(/\.presentation-root:not\(\.js\) \.slide\s*\{[^}]*position:\s*relative[^}]*height:\s*auto/m, source)
    refute_match(/\.slide:not\(\.is-active\)[^}]*display:\s*none/m, source)
  end

  def test_print_hides_presentation_chrome
    print_rules = source[/@media print\s*\{.*\}\s*\z/m]

    refute_nil print_rules
    assert_match(/\.presentation-chrome[^}]*display:\s*none\s*!important/m, print_rules)
    assert_match(/break-after:\s*page/, print_rules)
    assert_match(/print-color-adjust:\s*exact/, print_rules)
  end

  def test_tailwind_build_is_reproducible_from_committed_source
    Dir.mktmpdir("jekyll-slides-css") do |directory|
      output = File.join(directory, "presentation.css")
      command = ["./node_modules/.bin/tailwindcss", "-i", "./src/css/app.css", "-o", output, "--minify"]
      _stdout, stderr, status = Open3.capture3(*command, chdir: ROOT)

      assert_predicate status, :success?, stderr
      assert_equal File.binread(BUILT_CSS), File.binread(output)
    end
  end

  def test_compiled_asset_contains_no_unresolved_tailwind_directives
    built = File.read(BUILT_CSS)

    refute_match(/@import\s+"tailwindcss"|@theme\s*\{|@apply\b/, built)
    %w[presentation-root slide-deck code-window presentation-chrome].each { |selector| assert_includes built, selector }
  end
end
