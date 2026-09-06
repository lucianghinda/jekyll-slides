# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "test_helper"

class JekyllIntegrationTest < Minitest::Test
  Integration = Jekyll::Slides::JekyllIntegration

  FakeSite = Struct.new(:config, :converter) do
    def find_converter_instance(_klass)
      converter || raise("missing converter")
    end
  end

  class FakeDocument
    attr_accessor :content, :data
    attr_reader :site

    def initialize(site, data:, content:)
      @site = site
      @data = data
      @content = content
    end
  end

  def test_registers_one_site_post_read_hook
    Integration.install!

    registry = Jekyll::Hooks.instance_variable_get(:@registry)
    hooks = registry[:site][:post_read]
    assert_equal(1, hooks.count { |hook| hook.source_location.first.end_with?("jekyll_integration.rb") })

    count = hooks.length
    Integration.install!
    assert_equal count, registry[:site][:post_read].length
  end

  def test_processes_presentation_with_global_defaults_and_front_matter_overrides
    site = fake_site(
      "theme" => "ruby",
      "aspect_ratio" => "16:9",
      "progress" => true,
      "slide_numbers" => true,
      "overview" => false,
      "fullscreen" => false
    )
    data = { "layout" => "presentation", "title" => "Keep me", "theme" => nil, "progress" => false, "overview" => nil }
    document = FakeDocument.new(site, data: data, content: "# One\n---\n# Two")

    Integration.process(document)

    assert_equal "ruby", document.data["slides_theme"]
    assert_equal "16:9", document.data["slides_aspect_ratio"]
    assert_equal false, document.data["slides_progress"]
    assert_equal true, document.data["slides_slide_numbers"]
    assert_equal false, document.data["slides_overview"]
    assert_equal false, document.data["slides_fullscreen"]
    assert_equal 2, document.data["slides_count"]
    assert_equal "Keep me", document.data["title"]
    assert_equal "presentation", document.data["layout"]
    assert_instance_of Jekyll::Slides::Renderer, document.instance_variable_get(:@renderer)
  end

  def test_uses_built_in_defaults_when_slides_config_is_absent
    document = FakeDocument.new(fake_site_with_config({}), data: { "layout" => "presentation" }, content: "# One")

    Integration.process(document)

    assert_equal "midnight", document.data["slides_theme"]
    assert_equal "16:9", document.data["slides_aspect_ratio"]
    assert_equal true, document.data["slides_progress"]
    assert_equal true, document.data["slides_slide_numbers"]
    assert_equal true, document.data["slides_overview"]
    assert_equal true, document.data["slides_fullscreen"]
  end

  def test_uses_built_in_defaults_when_slides_config_is_nil
    document = FakeDocument.new(fake_site_with_config({ "slides" => nil }), data: { "layout" => "presentation" }, content: "# One")

    Integration.process(document)

    assert_equal "midnight", document.data["slides_theme"]
    assert_equal "16:9", document.data["slides_aspect_ratio"]
    assert_equal true, document.data["slides_progress"]
    assert_equal true, document.data["slides_slide_numbers"]
    assert_equal true, document.data["slides_overview"]
    assert_equal true, document.data["slides_fullscreen"]
  end

  def test_normalizes_boolean_strings_and_warns_for_invalid_values
    site = fake_site(
      "theme" => "not-a-theme",
      "aspect_ratio" => "1:1",
      "progress" => "sometimes",
      "slide_numbers" => "false",
      "overview" => "TRUE",
      "fullscreen" => "no"
    )
    document = FakeDocument.new(site, data: { "layout" => "presentation" }, content: "# One")

    warnings = capture_warnings { Integration.process(document) }

    assert_equal "midnight", document.data["slides_theme"]
    assert_equal "16:9", document.data["slides_aspect_ratio"]
    assert_equal true, document.data["slides_progress"]
    assert_equal false, document.data["slides_slide_numbers"]
    assert_equal true, document.data["slides_overview"]
    assert_equal true, document.data["slides_fullscreen"]
    assert_equal 4, warnings.length
    assert(warnings.all? { |warning| warning.include?("Jekyll Slides:") })
  end

  def test_front_matter_false_overrides_global_true
    site = fake_site("progress" => true, "slide_numbers" => true, "overview" => true, "fullscreen" => true)
    data = { "layout" => "presentation", "progress" => false, "slide_numbers" => false, "overview" => false, "fullscreen" => false }
    document = FakeDocument.new(site, data: data, content: "# One")

    Integration.process(document)

    assert_equal false, document.data["slides_progress"]
    assert_equal false, document.data["slides_slide_numbers"]
    assert_equal false, document.data["slides_overview"]
    assert_equal false, document.data["slides_fullscreen"]
  end

  def test_unquoted_yaml_aspect_ratio_warning_explains_quoting
    data = YAML.safe_load("layout: presentation\naspect_ratio: 16:9\n")
    document = FakeDocument.new(fake_site, data: data, content: "# One")

    warnings = capture_warnings { Integration.process(document) }

    assert_kind_of Numeric, data["aspect_ratio"]
    assert_equal "16:9", document.data["slides_aspect_ratio"]
    assert_equal 1, warnings.length
    assert_includes warnings.first, 'aspect_ratio: "16:9"'
    assert_match(/quot/i, warnings.first)
  end

  def test_ignores_non_presentation_documents
    original = "# Ordinary page"
    document = FakeDocument.new(fake_site, data: { "layout" => "default", "title" => "Untouched" }, content: original)

    Integration.process(document)

    assert_equal original, document.content
    assert_equal({ "layout" => "default", "title" => "Untouched" }, document.data)
  end

  def test_does_not_process_the_same_document_twice
    document = FakeDocument.new(fake_site, data: { "layout" => "presentation" }, content: "# One\n---\n# Two")

    Integration.process(document)
    first_renderer = document.instance_variable_get(:@renderer)
    Integration.process(document)

    assert_equal "# One\n---\n# Two", document.content
    assert_same first_renderer, document.instance_variable_get(:@renderer)
  end

  def test_real_jekyll_build_preserves_server_rendered_sections_and_liquid
    Dir.mktmpdir("jekyll-slides-integration") do |root|
      source = File.join(root, "source")
      destination = File.join(root, "destination")
      FileUtils.mkdir_p(File.join(source, "_layouts"))
      File.write(File.join(source, "_layouts", "presentation.html"), <<~LIQUID)
        <!doctype html>
        <html><body data-theme="{{ page.slides_theme }}" data-progress="{{ page.slides_progress }}" data-count="{{ page.slides_count }}">{{ content }}</body></html>
      LIQUID
      File.write(File.join(source, "deck.md"), <<~MARKDOWN)
        ---
        layout: presentation
        title: Integration deck
        progress: false
        ---
        # First {{ site.title }}

        Server-side prose.

        ```ruby
        puts "editor source"
        ```
        {: .editor}
        ---
        # Second

        More prose.
      MARKDOWN
      File.write(File.join(source, "ordinary.md"), <<~MARKDOWN)
        ---
        layout: default
        ---
        # Ordinary page
      MARKDOWN
      File.write(File.join(source, "_config.yml"), <<~YAML)
        title: Integration Site
        markdown: kramdown
        slides:
          theme: ruby
          progress: true
      YAML
      File.write(File.join(source, "_layouts", "default.html"), "{{ content }}")

      config = Jekyll.configuration(
        "source" => source,
        "destination" => destination,
        "quiet" => true,
        "disable_disk_cache" => true
      )
      Jekyll::Site.new(config).process

      output = File.read(File.join(destination, "deck.html"))
      ordinary = File.read(File.join(destination, "ordinary.html"))
      assert_equal 2, output.scan('<section class="slide ').length
      assert_includes output, 'id="slide-1" data-slide="1" aria-label="Slide 1"'
      assert_includes output, 'id="slide-2" data-slide="2" aria-label="Slide 2"'
      refute_includes output, "<hr"
      refute_includes output, "&lt;section"
      assert_includes output, "Integration Site"
      assert_includes output, "Server-side prose."
      assert_includes output, "editor source"
      assert_includes output, 'data-theme="ruby"'
      assert_includes output, 'data-progress="false"'
      assert_includes output, 'data-count="2"'
      assert_includes ordinary, "Ordinary page"
      refute_includes ordinary, "<section"
    end
  end

  def test_real_jekyll_build_preserves_raw_wrapped_liquid_source_in_editor
    build_site(
      "deck.md" => <<~MARKDOWN
        ---
        layout: presentation
        ---
        {% raw %}
        ```liquid
        {{ user.name }}
        ```
        {: .editor title="template.liquid"}
        {% endraw %}
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "deck.html"))

      assert_includes visible_code(output), "{{ user.name }}"
      assert_includes output, '<figure class="code-window'
    end
  end

  def test_real_jekyll_build_does_not_reconvert_generated_slides_as_block_html
    build_site(
      "_config.yml" => <<~YAML,
        markdown: kramdown
        kramdown:
          parse_block_html: true
      YAML
      "deck.md" => <<~MARKDOWN
        ---
        layout: presentation
        ---
        ```erb
        <%= user.name %>
        ```
        {: .editor title="template.html.erb"}
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "deck.html"))

      component = %r{
        <figure\ class="code-window[^"]*">
        <figcaption>template\.html\.erb</figcaption>
        <header\ class="code-window-header">.*?</header>
        <pre><code>.*?&lt;%=.*?</code></pre></figure>
      }mx
      assert_match(component, output)
    end
  end

  def test_plugin_supplies_layout_and_assets_without_becoming_the_site_theme
    build_site(
      "deck.md" => <<~MARKDOWN
        ---
        layout: presentation
        ---
        # Plugin-owned presentation
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "deck.html"))

      assert_includes output, "<!doctype html>"
      assert_includes output, "data-presentation-root"
      assert File.file?(File.join(destination, "assets/css/presentation.css"))
      assert File.file?(File.join(destination, "assets/js/presentation.js"))
    end
  end

  def test_plugin_processes_presentation_documents_in_output_collections
    build_site(
      "_config.yml" => <<~YAML,
        markdown: kramdown
        collections:
          talks:
            output: true
      YAML
      "_talks/deck.md" => <<~MARKDOWN
        ---
        layout: presentation
        ---
        # Collection presentation

        ```ruby
        puts :collection
        ```
        {: .editor}
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "talks/deck.html"))

      assert_includes output, "Collection presentation"
      assert_includes output, '<figure class="code-window'
    end
  end

  def test_real_jekyll_build_does_not_overwrite_site_generated_presentation_css
    build_site(
      "_plugins/generated_presentation_css.rb" => <<~RUBY,
        class GeneratedPresentationCss < Jekyll::Generator
          safe true
          priority :lowest

          def generate(site)
            page = Jekyll::PageWithoutAFile.new(site, site.source, "assets/css", "presentation.css")
            page.content = "/* site generated */\\nbody { color: hotpink; }\\n"
            page.data = {}
            site.pages << page
          end
        end
      RUBY
      "deck.md" => <<~MARKDOWN
        ---
        layout: presentation
        ---
        # Plugin-owned presentation
      MARKDOWN
    ) do |destination|
      output = File.read(File.join(destination, "assets/css/presentation.css"))

      assert_equal "/* site generated */\nbody { color: hotpink; }\n", output
    end
  end

  def test_scoped_defaults_apply_to_pages_and_collection_documents
    build_site(
      "_config.yml" => <<~YAML,
        markdown: kramdown
        slides: { theme: minimal-light, progress: true }
        collections: { talks: { output: true } }
        defaults:
          - scope: { path: "", type: pages }
            values: { layout: presentation, theme: ruby, progress: false }
          - scope: { path: "", type: talks }
            values: { layout: presentation, theme: ruby, progress: false }
      YAML
      "deck.md" => "---\n---\n# Page\n",
      "override.md" => "---\ntheme: minimal-dark\nprogress: true\n---\n# Override\n",
      "_talks/deck.md" => "---\n---\n# Collection\n"
    ) do |destination|
      ["deck.html", "talks/deck.html"].each do |path|
        output = File.read(File.join(destination, path))
        assert_includes output, 'data-theme="ruby"'
        assert_includes output, 'data-progress="false"'
        refute_includes output, "data-slide-progress"
      end
      output = File.read(File.join(destination, "override.html"))
      assert_includes output, 'data-theme="minimal-dark"'
      assert_includes output, 'data-progress="true"'
    end
  end

  private

  def fake_site(config = {})
    FakeSite.new({ "slides" => config }, converter)
  end

  def fake_site_with_config(config)
    FakeSite.new(config, converter)
  end
end
