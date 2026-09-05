# frozen_string_literal: true

require_relative "test_helper"

class SlideRendererTest < Minitest::Test
  def test_renders_sections_with_accessible_semantics
    markdown = "<!-- layout: split-code\nbackground: spotlight\nclass: deck\n-->\n# Demo\n---\nText"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_includes html, '<section class="slide layout-split-code bg-spotlight deck" id="slide-1" data-slide="1" aria-label="Slide 1">'
    assert_includes html, '<section class="slide layout-content bg-plain" id="slide-2" data-slide="2" aria-label="Slide 2">'
    assert_includes html, '<div class="slide-content">'
    refute_includes html, '<div class="panes">'
  end

  def test_code_result_uses_stack_wrapper_and_consumes_component_ial
    markdown = "<!-- layout: code-result -->\n```ruby\na\n```\n{: .editor}\n\nResult"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_includes html, '<div class="stack">'
    assert_includes html, "code-window"
    refute_includes html, "{: .editor}"
  end

  def test_code_right_separates_prose_left_and_visual_right
    markdown = "<!-- layout: code-right -->\n# Explain\n\nText\n\n```ruby\na\n```\n{: .editor}"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_match(%r{<div class="pane prose">.*<h1[^>]*>Explain</h1>.*</div><div class="pane visual">.*code-window}m, html)
  end

  def test_code_left_separates_visual_left_and_prose_right
    markdown = "<!-- layout: code-left -->\n# Explain\n\nText\n\n```ruby\na\n```\n{: .editor}"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_match(%r{<div class="pane visual">.*code-window.*</div><div class="pane prose">.*<h1[^>]*>Explain</h1>}m, html)
  end

  def test_split_code_pairs_headings_with_each_editor
    markdown = "<!-- layout: split-code -->\n## Before\n\n```ruby\na\n```\n{: .editor}\n\n## After\n\n```ruby\nb\n```\n{: .editor}"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_equal 2, html.scan('<div class="pane">').length
    assert_equal 2, html.scan('<figure class="code-window').length
  end

  def test_code_places_prose_before_dominant_visual
    markdown = "<!-- layout: code -->\n# Heading\n\n```ruby\na\n```\n{: .editor}"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_match(%r{<div class="prose">.*<h1[^>]*>Heading</h1>.*</div><div class="visual">.*code-window}m, html)
  end

  def test_code_with_only_a_component_omits_the_empty_prose_pane
    markdown = "<!-- layout: code -->\n```ruby\na\n```\n{: .editor}"

    html = Jekyll::Slides::SlideRenderer.new.render(markdown)

    refute_includes html, '<div class="prose"></div>'
    assert_match(/<div class="slide-content"><div class="visual">.*code-window/m, html)
  end

  def test_content_layout_preserves_interleaved_prose_and_components
    markdown = "<!-- layout: content -->\nBefore\n\n```ruby\na\n```\n{: .editor}\n\nBetween\n\n```console\n$ b\n```\n{: .terminal}\n\nAfter"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_operator html.index("Before"), :<, html.index("code-window")
    assert_operator html.index("code-window"), :<, html.index("Between")
    assert_operator html.index("Between"), :<, html.index("terminal-window")
    assert_operator html.index("terminal-window"), :<, html.index("After")
  end

  def test_split_code_without_components_falls_back_to_normal_content
    html = Jekyll::Slides::SlideRenderer.new.render("<!-- layout: split-code -->\n# Just text")
    refute_includes html, 'class="panes"'
    assert_includes html, "Just text"
  end

  def test_split_code_hoists_global_intro_and_pairs_local_headings
    markdown = "<!-- layout: split-code -->\n# Global intro\n\nA description.\n\n## Before\n\n```ruby\na\n```\n{: .editor}\n\n## After\n\n```ruby\nb\n```\n{: .editor}\n\nTail"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_match(%r{<div class="prose">.*Global intro.*A description.*</div>}m, html)
    assert_equal 2, html.scan('<div class="pane">').length
    assert_operator html.index("Before"), :<, html.index("code-window")
    assert_operator html.index("After"), :<, html.rindex("code-window")
    assert_operator html.rindex("code-window"), :<, html.index("Tail")
  end

  def test_split_code_pairs_editors_without_headings
    markdown = "<!-- layout: split-code -->\n```ruby\na\n```\n{: .editor}\n\n```ruby\nb\n```\n{: .editor}"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_equal 2, html.scan('<div class="pane">').length
  end

  def test_split_code_hoists_h1_only_intro_before_editors
    markdown = "<!-- layout: split-code -->\n# Intro\n\n```ruby\na\n```\n{: .editor}\n\n```ruby\nb\n```\n{: .editor}"
    html = Jekyll::Slides::SlideRenderer.new.render(markdown)
    assert_match(%r{<div class="prose"><h1[^>]*>Intro</h1></div><div class="panes">}m, html)
    assert_match(/<div class="pane"><figure class="code-window/m, html)
    refute_match(/<div class="pane"><h1>Intro/m, html)
  end

  def test_high_level_presentation_returns_all_sections
    result = Jekyll::Slides::Presentation.new("# A\n---\n# B").render
    assert_equal 2, result.scan("<section ").length
  end

  def test_reference_link_definition_after_later_heading_resolves_across_the_slide
    markdown = <<~MARKDOWN
      # First

      Read the [guide][later].

      ## Second

      [later]: https://example.test/guide
    MARKDOWN

    html = Jekyll::Slides::SlideRenderer.new.render(markdown)

    assert_includes html, '<a href="https://example.test/guide">guide</a>'
  end

  def test_abbreviation_definition_after_a_later_heading_resolves_across_the_slide
    markdown = <<~MARKDOWN
      # First

      HTML stays defined.

      ## Glossary

      *[HTML]: HyperText Markup Language
    MARKDOWN

    html = Jekyll::Slides::SlideRenderer.new.render(markdown)

    assert_includes html, '<abbr title="HyperText Markup Language">HTML</abbr>'
  end

  def test_footnote_definition_after_later_heading_resolves_across_the_slide
    markdown = <<~MARKDOWN
      # First

      A note.[^detail]

      ## Second

      [^detail]: Footnote text.
    MARKDOWN

    html = Jekyll::Slides::SlideRenderer.new.render(markdown)

    assert_includes html, "Footnote text."
    assert_match(/class="footnote"/, html)
  end

  def test_footnote_ids_are_unique_across_slides
    markdown = <<~MARKDOWN
      First note.[^detail]

      [^detail]: First slide.
      ---
      Second note.[^detail]

      [^detail]: Second slide.
    MARKDOWN

    html = Jekyll::Slides::SlideRenderer.new.render(markdown)

    assert_includes html, 'id="fnref:slide-1-detail"'
    assert_includes html, 'href="#fn:slide-1-detail"'
    assert_includes html, 'id="fnref:slide-2-detail"'
    assert_includes html, 'href="#fn:slide-2-detail"'
  end

  def test_slide_footnote_ids_preserve_the_configured_prefix
    renderer = Jekyll::Slides::SlideRenderer.new(options: { "footnote_prefix" => "deck-" })

    html = renderer.render("A note.[^detail]\n\n[^detail]: Footnote text.")

    assert_includes html, 'id="fnref:deck-slide-1-detail"'
    assert_includes html, 'href="#fn:deck-slide-1-detail"'
  end

  def test_footnotes_follow_a_trailing_component
    markdown = <<~MARKDOWN
      <!-- layout: content -->
      A note.[^detail]

      ```ruby
      puts :last
      ```
      {: .editor}

      [^detail]: Footnote text.
    MARKDOWN

    html = Jekyll::Slides::SlideRenderer.new.render(markdown)

    assert_operator html.index("code-window"), :<, html.index('class="footnotes"')
  end

  def test_layout_inference_uses_the_configured_markdown_parser
    markdown = <<~MARKDOWN
      # Intro
      ---
      ```ruby
      puts :plain
      ```
      {: .editor}
    MARKDOWN

    html = Jekyll::Slides::SlideRenderer.new(options: { "input" => "kramdown" }).render(markdown)

    assert_includes html, '<section class="slide layout-content bg-plain" id="slide-2"'
    refute_includes html, "code-window"
    refute_includes html, '<div class="visual"></div>'
  end

  def test_generated_heading_ids_are_unique_within_and_across_slides
    html = Jekyll::Slides::SlideRenderer.new.render("# Repeat\n\n## Repeat\n---\n# Repeat")

    assert_includes html, 'id="slide-1-repeat"'
    assert_includes html, 'id="slide-1-repeat-1"'
    assert_includes html, 'id="slide-2-repeat"'
  end
end
