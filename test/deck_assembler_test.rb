# frozen_string_literal: true

require_relative "test_helper"

# Real Jekyll builds that exercise Jekyll::Slides::DeckAssembler through the
# :site, :post_read hook. See test/jekyll_integration_test.rb for
# JekyllIntegration.process itself and single-file deck behavior.
class DeckAssemblerTest < Minitest::Test
  def test_folder_deck_renders_slide_files_in_natural_order
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/02-two.md" => "# Two",
      "deck/10-ten.md" => "# Ten",
      "deck/01-one.md" => "# One",
      "deck/appendix.md" => "# Appendix"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 4, output.scan('<section class="slide ').length
      assert_includes output, 'id="slide-1" data-slide="1"'
      assert_includes output, 'id="slide-2" data-slide="2"'
      assert_includes output, 'id="slide-3" data-slide="3"'
      assert_includes output, 'id="slide-4" data-slide="4"'

      positions = %w[One Two Ten Appendix].map { |text| output.index(text) }
      assert_equal positions, positions.sort
      assert_equal ["index.html"], Dir.children(File.join(destination, "deck"))
    end
  end

  def test_folder_deck_slide_files_are_not_published_on_their_own
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-one.md" => "# One",
      "deck/02-two.md" => "# Two"
    ) do |destination|
      refute_path_exists File.join(destination, "deck", "01-one.html")
      refute_path_exists File.join(destination, "deck", "01-one.md")
      refute_path_exists File.join(destination, "deck", "02-two.html")
      refute_path_exists File.join(destination, "deck", "02-two.md")
    end
  end

  def test_folder_deck_consumes_a_slide_file_with_no_front_matter_instead_of_copying_it
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-one.md" => "# One, no front matter at all\n"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_includes output, "One, no front matter at all"
      refute_path_exists File.join(destination, "deck", "01-one.md")
    end
  end

  def test_folder_deck_evaluates_liquid_inside_a_slide_file
    build_site(
      "_config.yml" => "markdown: kramdown\ntitle: Deck Site\n",
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-one.md" => "# Hello {{ site.title }}"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))
      assert_includes output, "Hello Deck Site"
    end
  end

  def test_folder_deck_preserves_raw_wrapped_liquid_in_a_slide_file
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-code.md" => <<~MARKDOWN
        {% raw %}
        ```liquid
        {{ user.name }}
        ```
        {: .editor title="template.liquid"}
        {% endraw %}
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_includes visible_code(output), "{{ user.name }}"
      assert_includes output, '<figure class="code-window'
    end
  end

  def test_folder_deck_slide_file_front_matter_sets_layout_and_background
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-statement.md" => <<~MARKDOWN
        ---
        layout: statement
        background: spotlight
        ---
        # A bold claim
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_includes output, "layout-statement"
      assert_includes output, "bg-spotlight"
      # This slide file has its own YAML front matter, so Jekyll reads it as
      # a Page (unlike a front-matter-less slide file, which becomes a
      # StaticFile). Assert it is pruned too, not just published untouched.
      refute_path_exists File.join(destination, "deck", "01-statement.html")
      refute_path_exists File.join(destination, "deck", "01-statement.md")
    end
  end

  def test_folder_deck_entry_body_becomes_the_leading_slides
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
        # Welcome
      MARKDOWN
      "deck/01-one.md" => "# One"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 2, output.scan('<section class="slide ').length
      assert_operator output.index("Welcome"), :<, output.index("One")
    end
  end

  def test_folder_deck_inside_an_output_collection_builds
    build_site(
      "_config.yml" => <<~YAML,
        markdown: kramdown
        collections:
          talks:
            output: true
      YAML
      "_talks/deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "_talks/deck/01-one.md" => "# One",
      "_talks/deck/02-two.md" => "# Two"
    ) do |destination|
      output = File.read(File.join(destination, "talks", "deck", "index.html"))

      assert_equal 2, output.scan('<section class="slide ').length
      assert_includes output, "One"
      assert_includes output, "Two"
    end
  end

  def test_slides_absent_leaves_sibling_pages_published
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        ---
        # Solo
      MARKDOWN
      "deck/01-one.md" => "# One"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 1, output.scan('<section class="slide ').length
      assert_includes output, "Solo"
      assert_path_exists File.join(destination, "deck", "01-one.md")
    end
  end

  def test_explicit_slides_list_orders_a_subset_and_still_absorbs_the_whole_folder
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: [02-two.md, 01-one.md]
        ---
      MARKDOWN
      "deck/01-one.md" => "# One",
      "deck/02-two.md" => "# Two",
      "deck/03-cut.md" => "# Cut"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 2, output.scan('<section class="slide ').length
      assert_operator output.index("Two"), :<, output.index("One")
      refute_includes output, "Cut"

      refute_path_exists File.join(destination, "deck", "01-one.md")
      refute_path_exists File.join(destination, "deck", "02-two.md")
      refute_path_exists File.join(destination, "deck", "03-cut.md")
      refute_path_exists File.join(destination, "deck", "03-cut.html")
    end
  end

  def test_hash_slides_value_warns_and_leaves_the_deck_single_file
    warnings = capture_warnings do
      build_site(
        "deck/index.md" => <<~MARKDOWN,
          ---
          layout: presentation
          slides:
            theme: midnight
          ---
          # Solo
        MARKDOWN
        "deck/01-one.md" => "# One"
      ) do |destination|
        output = File.read(File.join(destination, "deck", "index.html"))

        assert_equal 1, output.scan('<section class="slide ').length
        assert_includes output, "Solo"
        assert_path_exists File.join(destination, "deck", "01-one.md")
      end
    end
    assert(warnings.any? { |warning| warning.include?("theme") })
  end

  def test_non_index_entry_with_truthy_slides_warns_and_stays_single_file
    warnings = capture_warnings do
      build_site(
        "deck/notindex.md" => <<~MARKDOWN,
          ---
          layout: presentation
          slides: true
          ---
          # Solo
        MARKDOWN
        "deck/01-one.md" => "# One"
      ) do |destination|
        output = File.read(File.join(destination, "deck", "notindex.html"))

        assert_equal 1, output.scan('<section class="slide ').length
        assert_includes output, "Solo"
        assert_path_exists File.join(destination, "deck", "01-one.md")
      end
    end
    assert(warnings.any? { |warning| warning.include?("index") })
  end

  def test_liquid_generated_slides_report_the_true_slide_count
    build_site(
      "deck.md" => <<~LIQUID
        ---
        layout: presentation
        ---
        {% assign topics = "One,Two,Three" | split: "," %}
        {%- for topic in topics -%}
        # {{ topic }}
        {% unless forloop.last %}
        ---
        {% endunless %}
        {%- endfor -%}
      LIQUID
    ) do |destination|
      output = File.read(File.join(destination, "deck.html"))

      assert_equal 3, output.scan('<section class="slide ').length
      assert_includes output, 'data-slide-count="3"'
    end
  end

  def test_discovery_skips_a_sibling_excluded_by_the_site_config
    build_site(
      "_config.yml" => <<~YAML,
        markdown: kramdown
        exclude:
          - deck/02-secret.md
      YAML
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-one.md" => "# One",
      "deck/02-secret.md" => "# Secret plans"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 1, output.scan('<section class="slide ').length
      assert_includes output, "One"
      refute_includes output, "Secret plans"
      assert_equal ["index.html"], Dir.children(File.join(destination, "deck"))
    end
  end

  def test_discovery_skips_an_unpublished_sibling
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: true
        ---
      MARKDOWN
      "deck/01-one.md" => "# One",
      "deck/02-draft.md" => <<~MARKDOWN
        ---
        published: false
        ---
        # Draft thinking
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 1, output.scan('<section class="slide ').length
      assert_includes output, "One"
      refute_includes output, "Draft thinking"
      assert_equal ["index.html"], Dir.children(File.join(destination, "deck"))
    end
  end

  def test_an_explicitly_listed_unpublished_file_warns_and_is_skipped
    warnings = capture_warnings do
      build_site(
        "deck/index.md" => <<~MARKDOWN,
          ---
          layout: presentation
          slides:
            - 01-one.md
            - 02-draft.md
          ---
        MARKDOWN
        "deck/01-one.md" => "# One",
        "deck/02-draft.md" => <<~MARKDOWN
          ---
          published: false
          ---
          # Draft thinking
        MARKDOWN
      ) do |destination|
        output = File.read(File.join(destination, "deck", "index.html"))

        assert_equal 1, output.scan('<section class="slide ').length
        refute_includes output, "Draft thinking"
      end
    end
    assert(warnings.any? { |warning| warning.include?("02-draft.md") })
  end

  def test_an_empty_slide_list_still_absorbs_the_folder
    build_site(
      "deck/index.md" => <<~MARKDOWN,
        ---
        layout: presentation
        slides: []
        ---
        # Welcome
      MARKDOWN
      "deck/cut.md" => "# Cut for time"
    ) do |destination|
      output = File.read(File.join(destination, "deck", "index.html"))

      assert_equal 1, output.scan('<section class="slide ').length
      assert_includes output, "Welcome"
      refute_includes output, "Cut for time"
      assert_equal ["index.html"], Dir.children(File.join(destination, "deck"))
    end
  end
end
