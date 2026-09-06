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

  def test_public_theme_and_layout_selectors_remain_available
    %w[minimal-light minimal-dark midnight ruby].each { |theme| assert_includes source, %(data-theme="#{theme}") }
    %w[title statement content code code-left code-right split-code code-result].each do |layout|
      assert_includes source, ".layout-#{layout}"
    end
    %w[plain gradient grid spotlight].each { |background| assert_includes source, ".bg-#{background}" }
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

  def test_abs_override_wins_the_cascade_in_the_compiled_stylesheet
    built = File.read(BUILT_CSS)

    abs_supports_offsets = built.enum_for(:scan, /@supports\s*\(transform:\s*scale\(abs\(-1\)\)\)/).map { Regexp.last_match.begin(0) }
    slide_scale_offsets = built.enum_for(:scan, "--slide-scale:").map { Regexp.last_match.begin(0) }
    overview_scale_offsets = built.enum_for(:scan, "--overview-slide-scale:").map { Regexp.last_match.begin(0) }

    assert_equal 2, abs_supports_offsets.size
    assert_equal 2, slide_scale_offsets.size
    assert_equal 2, overview_scale_offsets.size

    assert_operator slide_scale_offsets.first, :<, slide_scale_offsets.last
    assert_operator overview_scale_offsets.first, :<, overview_scale_offsets.last

    assert(
      abs_supports_offsets.any? { |offset| offset.between?(slide_scale_offsets.first, slide_scale_offsets.last) },
      "expected the abs() @supports block to sit between the two --slide-scale declarations"
    )
    assert(
      abs_supports_offsets.any? { |offset| offset.between?(overview_scale_offsets.first, overview_scale_offsets.last) },
      "expected the abs() @supports block to sit between the two --overview-slide-scale declarations"
    )
  end

  def test_code_only_layout_and_chrome_do_not_compete_with_slide_content
    assert_match(/\.layout-code \.slide-content\s*\{[^}]*justify-content:\s*center/m, source)
    assert_match(/\.presentation-chrome\s*\{[^}]*pointer-events:\s*none/m, source)
    assert_match(/\.slide-controls\s*\{[^}]*position:\s*absolute/m, source)
    assert_match(/\.slide-progress\s*\{[^}]*position:\s*absolute[^}]*width:\s*100%/m, source)
  end

  def test_overview_thumbnails_contribute_their_height_to_grid_rows
    assert_match(/\.presentation-root\.js\.is-overview \.slide, [^{]+\{[^}]*container-type:\s*inline-size/, source)
    assert_match(/\.presentation-root\.js\.is-overview \.slide-deck, [^{]+\{[^}]*align-content:\s*start/, source)
    assert_match(/\.presentation-root\.js\.is-overview \.slide-deck, [^{]+\{[^}]*grid-auto-rows:\s*max-content/, source)
    refute_match(/--overview-slide-scale:[^;]*100cqh/, source)
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
