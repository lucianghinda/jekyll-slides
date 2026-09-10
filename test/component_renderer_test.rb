# frozen_string_literal: true

require_relative "test_helper"

class ComponentRendererTest < Minitest::Test
  def render(markdown, warnings: [])
    Jekyll::Slides::ComponentRenderer.new(warning: ->(message) { warnings << message }).render(markdown)
  end

  def test_editor_component_renders_semantic_window_and_options
    source = <<~MARKDOWN
      ```ruby
      puts "one"
      puts "two"
      ```
      {: .editor #demo title="app.rb" highlight="2" focus="1" line_numbers="false" size="lg"}
    MARKDOWN
    html = render(source)
    assert_includes html, '<figure class="code-window size-lg has-focus" id="demo">'
    assert_includes html, "<figcaption>app.rb</figcaption>"
    assert_includes html, '<span class="code-window-language">ruby</span>'
    assert_includes html, 'class="line is-highlighted"'
    assert_includes html, 'class="line is-focused"'
    refute_includes html, "data-line-number"
    assert_includes html, 'aria-hidden="true"'
  end

  def test_editor_defaults_line_numbers_and_escapes_attributes
    html = render("```js\nalert(1)\n```\n{: .editor #<bad title=\"<&\"}")
    assert_includes html, 'data-line-number="1"'
    refute_includes html, 'id="<bad"'
    assert_includes html, "&lt;&amp;"
  end

  def test_invalid_editor_ranges_and_size_warn_but_render
    warnings = []
    html = render("```ruby\na\nb\n```\n{: .editor highlight=\"nope\" size=\"xl\"}", warnings: warnings)
    assert_includes html, "size-md"
    assert_equal 2, warnings.length
  end

  def test_long_components_warn_without_losing_source
    source = (1..28).map { |line| "line #{line}\n" }.join

    %w[editor terminal].each do |component|
      warnings = []
      html = render("```text\n#{source}```\n{: .#{component}}", warnings: warnings)

      assert_equal source, visible_code(html)
      assert_equal ["#{component.capitalize} block has 28 lines and may require scrolling; consider splitting it across slides, especially for print."], warnings
    end
  end

  def test_components_with_up_to_twenty_lines_do_not_warn
    source = (1..20).map { |line| "line #{line}\n" }.join

    %w[editor terminal].each do |component|
      warnings = []
      html = render("```text\n#{source}```\n{: .#{component}}", warnings: warnings)

      assert_equal source, visible_code(html)
      assert_empty warnings
    end
  end

  def test_terminal_component_preserves_visible_source_and_has_no_editor_chrome
    source = "```console\n$ echo '<hi>'\n❯ next\n```\n{: .terminal #term title=\"Demo\" size=\"sm\"}"
    html = render(source)
    assert_includes html, '<figure class="terminal-window size-sm" id="term">'
    assert_includes html, "<figcaption>Demo</figcaption>"
    assert_includes html, "&lt;hi&gt;"
    assert_includes html, "class=\"prompt\""
    refute_includes html, "code-window-language"
    refute_includes html, "data-line-number"
  end

  def test_both_window_types_render_the_same_title_bar_controls
    controls = '<span class="code-window-controls" aria-hidden="true"><i></i><i></i><i></i></span>'

    %w[editor terminal].each do |component|
      html = render("```ruby\nputs 1\n```\n{: .#{component} title=\"Demo\"}")

      assert_includes html, '<header class="code-window-header">', component
      assert_includes html, controls, component
      # The caption stays a figure child, so the figure remains valid markup.
      assert_match(%r{<figure[^>]*><figcaption>Demo</figcaption><header}, html, component)
    end
  end

  def test_terminal_title_bar_omits_the_language_the_editor_shows
    assert_includes render("```ruby\nputs 1\n```\n{: .editor}"), '<span class="code-window-language">ruby</span>'
    refute_includes render("```ruby\nputs 1\n```\n{: .terminal}"), "code-window-language"
  end

  def test_a_single_window_can_carry_any_deck_theme
    %w[editor terminal].each do |component|
      warnings = []
      html = render("```ruby\nputs 1\n```\n{: .#{component} theme=\"catppuccin-mocha\"}", warnings: warnings)

      assert_includes html, 'data-code-theme="catppuccin-mocha"', component
      assert_empty warnings, component
    end
  end

  def test_unknown_component_theme_warns_and_inherits_the_deck_theme
    warnings = []
    html = render("```ruby\nputs 1\n```\n{: .editor theme=\"dracula\"}", warnings: warnings)

    refute_includes html, "data-code-theme"
    assert_equal 1, warnings.length
    assert_includes warnings.first, "Unsupported component theme"
    assert_includes warnings.first, "catppuccin-mocha"
  end

  def test_windows_without_a_theme_attribute_inherit_the_deck_theme
    refute_includes render("```ruby\nputs 1\n```\n{: .editor}"), "data-code-theme"
    refute_includes render("```console\n$ ls\n```\n{: .terminal}"), "data-code-theme"
  end

  def test_indented_four_backtick_component_and_longer_closing_fence
    source = "  ````ruby\n  one\n  ```\n  ---\n  `````\n  {: .editor line_numbers=\"true\"}"
    html = render(source)
    assert_equal "  one\n  ```\n  ---\n", visible_code(html)
  end

  def test_terminal_only_styles_prompt_characters_followed_by_a_space
    commands = "$ echo hi\n> next\n❯ finish\n"
    output = "$HOME=/tmp\n>output\n❯symbol\n$\n"
    html = render("```console\n#{commands}#{output}```\n{: .terminal}")

    assert_equal 3, html.scan('class="prompt"').length
    assert_equal commands + output, visible_code(html)
    assert_includes html, '<span class="tline">$HOME=/tmp'
    assert_includes html, '<span class="tline">&gt;output'
    assert_includes html, '<span class="tline">❯symbol'
  end

  def test_invalid_line_numbers_warns_and_defaults_to_true
    warnings = []
    html = render("```ruby\na\n```\n{: .editor line_numbers=\"maybe\"}", warnings: warnings)
    assert_includes html, 'data-line-number="1"'
    refute_empty warnings
  end

  def test_only_literal_boolean_line_numbers_values_are_valid
    %w[yes no on off 1 0 maybe].each do |value|
      warnings = []
      html = render("```ruby\na\n```\n{: .editor line_numbers=\"#{value}\"}", warnings: warnings)
      assert_includes html, 'data-line-number="1"'
      refute_empty warnings
    end

    %w[true TRUE false False].each do |value|
      warnings = []
      html = render("```ruby\na\n```\n{: .editor line_numbers=\"#{value}\"}", warnings: warnings)
      assert_empty warnings
      assert_equal(value.downcase == "true", html.include?('data-line-number="1"'))
    end
  end

  def test_rendered_editor_and_terminal_text_preserve_source_newlines
    editor = render("```text\na\n\n$ b\n```\n{: .editor}")
    terminal = render("```console\n$ a\n\n❯ b\n```\n{: .terminal}")
    assert_equal "a\n\n$ b\n", visible_code(editor)
    assert_equal "$ a\n\n❯ b\n", visible_code(terminal)
  end

  def test_plain_fenced_markdown_is_rendered_normally
    html = Jekyll::Slides::ComponentRenderer.new.render("```ruby\nputs 1\n```")
    assert_includes html, "highlighter-rouge"
    assert_includes html, "puts"
  end

  def test_fence_with_non_component_ial_remains_normal_markdown
    source = "```ruby\nputs 1\n```\n{: .unknown}"
    html = Jekyll::Slides::ComponentRenderer.new.render(source)
    assert_includes html, "unknown"
    refute_includes html, "code-window"
  end

  def test_nested_example_inside_longer_outer_fence_is_delegated_intact
    source = "````markdown\n```ruby\na\n```\n{: .editor}\n````"
    html = Jekyll::Slides::ComponentRenderer.new.render(source)
    refute_includes html, "code-window"
    assert_includes html, ".editor"
  end

  def test_heading_inside_plain_fence_is_not_split_for_converter
    source = "```text\n# literal\n---\n```"
    html = Jekyll::Slides::ComponentRenderer.new.render(source)
    assert_includes visible_code(html), "# literal\n---"
  end

  def test_multiline_lexer_state_is_preserved_for_editor
    source = "```ruby\n=begin\nmultiline\n=end\n```\n{: .editor}"
    html = render(source)
    assert_includes html, 'class="cm"'
    assert_equal "=begin\nmultiline\n=end\n", visible_code(html)
  end

  def test_rouge_renderer_lexes_complete_source_and_preserves_newlines
    source = "=begin\nmultiline\n=end\n"
    html = Jekyll::Slides::RougeRenderer.new.render(source, "ruby")
    assert_includes html, "\n"
    assert_includes html, "class=\"cm\""
  end

  private

  def visible_code(html)
    CGI.unescapeHTML(html[%r{<pre[^>]*><code[^>]*>(.*?)</code></pre>}m, 1].to_s.gsub(/<[^>]+>/, ""))
  end
end
