# frozen_string_literal: true

require_relative "test_helper"

class SlideMetadataTest < Minitest::Test
  def metadata(content, index: 1, warnings: [])
    warning = ->(message) { warnings << message }
    result = Jekyll::Slides::SlideMetadata.new(content, index: index, warning: warning)
    rendered = Jekyll::Slides::ComponentRenderer.new(warning: warning).render_document(result.content)
    result.parse(components: rendered.components)
  end

  def test_extracts_metadata_comment_and_does_not_render_it
    result = metadata("<!--\nlayout: code-left\nclass: dark\nbackground: grid\n-->\n# Hello\nbody")
    assert_equal "code-left", result.layout
    assert_equal "dark", result.custom_class
    assert_equal "grid", result.background
    assert_equal "# Hello\nbody", result.content
  end

  def test_infers_title_for_first_slide_and_statement_for_heading_with_paragraph
    assert_equal "title", metadata("# Welcome", index: 0).layout
    assert_equal "statement", metadata("# Claim\n\nA short claim.").layout
    assert_equal "content", metadata("# Claim\n\nA paragraph.\n\n- more").layout
  end

  def test_invalid_metadata_falls_back_and_warns
    warnings = []
    result = metadata("<!-- layout: nonsense\nbackground: neon -->\n# Hi", warnings: warnings)
    assert_equal "statement", result.layout
    assert_equal "plain", result.background
    assert_equal 2, warnings.length
  end

  def test_known_metadata_is_applied_even_with_unknown_keys
    warnings = []
    result = metadata("<!--\nlayout: code\nwat: nope\nbackground: grid\n-->\n# Hi", warnings: warnings)
    assert_equal "code", result.layout
    assert_equal "grid", result.background
    assert_equal "# Hi", result.content
    assert_equal 1, warnings.length
  end

  def test_leading_comment_with_only_unknown_keys_remains_slide_content
    warnings = []
    source = "<!-- TODO: explain the example -->\n# Heading"

    result = metadata(source, warnings: warnings)

    assert_includes result.content, "TODO: explain the example"
    assert_empty warnings
  end

  def test_invalid_explicit_layout_uses_automatic_component_inference
    warnings = []
    source = "<!-- layout: made-up -->\n```ruby\na\n```\n{: .editor}"
    result = metadata(source, warnings: warnings)
    assert_equal "code", result.layout
    refute_empty warnings
  end

  def test_automatic_layout_detects_result_and_split_compositions
    result = metadata("```ruby\na\n```\n{: .editor}\n\n```console\n$ a\n```\n{: .terminal}")
    assert_equal "code-result", result.layout
    split = metadata("## Before\n\n```ruby\na\n```\n{: .editor}\n\n## After\n\n```ruby\nb\n```\n{: .editor}")
    assert_equal "split-code", split.layout
  end

  def test_component_inference_precedes_first_slide_title
    source = "Intro\n\n```ruby\na\n```\n{: .editor}"
    assert_equal "code", metadata(source, index: 0).layout
  end

  def test_component_inference_requires_real_component_fences
    prose = "An explanation mentioning .editor and .terminal classes."
    assert_equal "content", metadata(prose, index: 1).layout
  end

  def test_two_editor_components_infer_split_code_without_headings
    source = "```ruby\na\n```\n{: .editor}\n\n```ruby\nb\n```\n{: .editor}"
    assert_equal "split-code", metadata(source).layout
  end

  def test_nested_example_inside_outer_fence_is_not_a_component
    source = "````markdown\n```ruby\na\n```\n{: .editor}\n````"
    assert_equal "content", metadata(source).layout
  end

  def test_code_result_requires_exact_editor_then_terminal_pair
    editor = "```ruby\na\n```\n{: .editor}"
    terminal = "```console\n$ a\n```\n{: .terminal}"
    assert_equal "code-result", metadata("#{editor}\n\n#{terminal}").layout
    assert_equal "code", metadata("#{terminal}\n\n#{editor}").layout
    assert_equal "code", metadata("#{editor}\n\n#{terminal}\n\n#{editor}").layout
    assert_equal "code", metadata("#{terminal}\n\n#{terminal}").layout
  end

  def test_component_detection_requires_a_whole_line_ial
    source = "```ruby\na\n```\nnot-an-ial {: .editor}"
    assert_equal "content", metadata(source).layout
  end

  def test_component_detection_uses_class_tokens_not_attribute_text
    source = "```ruby\na\n```\n{: title=\"contains .editor marker\"}"
    assert_equal "content", metadata(source).layout
  end
end
