# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "test_helper"

class LayoutRuntimeTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  LAYOUT = File.read(File.join(ROOT, "_layouts", "presentation.html"))

  def include_file(name)
    File.read(File.join(ROOT, "_includes", "slides", name))
  end

  def test_layout_is_a_complete_local_html_document
    assert_includes LAYOUT, "<!doctype html>"
    assert_match(/<html lang="/, LAYOUT)
    assert_includes LAYOUT, '<meta charset="utf-8">'
    assert_includes LAYOUT, '<meta name="viewport"'
    assert_includes LAYOUT, "{{ '/assets/css/presentation.css' | relative_url }}"
    assert_includes LAYOUT, "{{ '/assets/js/presentation.js' | relative_url }}"
    assert_includes LAYOUT, "<title>"
    refute_match(%r{https?://}, LAYOUT)
  end

  def test_layout_exposes_normalized_options_and_keeps_server_content_intact
    %w[theme aspect-ratio progress slide-numbers overview fullscreen slide-count].each do |name|
      assert_includes LAYOUT, %(data-#{name}=)
    end
    %w[slides_theme slides_aspect_ratio slides_progress slides_slide_numbers slides_overview slides_fullscreen slides_count].each do |name|
      assert_includes LAYOUT, "{{ page.#{name} | escape }}"
    end
    assert_includes LAYOUT, "{{ content }}"
    assert_includes LAYOUT, "{% include slides/controls.html %}"
    assert_includes LAYOUT, "{% include slides/progress.html %}"
    refute_match(/document\.createElement|innerHTML|cloneNode/, LAYOUT)
  end

  def test_controls_have_accessible_labels_and_conditional_hooks
    controls = include_file("controls.html")
    assert_operator controls.scan('type="button"').length, :>=, 2
    assert_includes controls, 'aria-label="Previous slide"'
    assert_includes controls, 'aria-label="Next slide"'
    assert_includes controls, "{% if page.slides_overview %}"
    assert_includes controls, "{% if page.slides_fullscreen %}"
    assert_includes controls, 'aria-pressed="false"'
    assert_includes controls, "{% if page.slides_slide_numbers %}"
    assert_includes include_file("progress.html"), "{% if page.slides_progress %}"
  end

  def test_runtime_is_dependency_free_and_has_browser_and_node_surfaces
    runtime = File.read(File.join(ROOT, "assets", "js", "presentation.js"))
    assert_includes runtime, "module.exports"
    assert_includes runtime, "createPresentationController"
    assert_includes runtime, "requestFullscreen"
    assert_includes runtime, "prefers-reduced-motion"
    refute_match(%r{<script|https?://}, runtime)
  end

  def test_real_liquid_render_has_conditional_chrome_and_escaped_local_configuration
    Dir.mktmpdir("jekyll-slides-layout") do |root|
      source = File.join(root, "source")
      destination = File.join(root, "destination")
      FileUtils.mkdir_p(File.join(source, "_layouts"))
      FileUtils.mkdir_p(File.join(source, "_includes", "slides"))
      layout_path = File.join(ROOT, "_layouts", "presentation.html")
      FileUtils.cp(layout_path, File.join(source, "_layouts", "presentation.html"))
      %w[controls progress overview].each do |name|
        FileUtils.cp(File.join(ROOT, "_includes", "slides", "#{name}.html"), File.join(source, "_includes", "slides", "#{name}.html"))
      end
      File.write(File.join(source, "_config.yml"), <<~YAML)
        title: Layout test
        baseurl: /slides
        markdown: kramdown
      YAML
      File.write(File.join(source, "true.md"), <<~MARKDOWN)
        ---
        layout: presentation
        title: "True <Deck>"
        theme: ruby
        aspect_ratio: "16:9"
        progress: true
        slide_numbers: true
        overview: true
        fullscreen: true
        ---
        # Server content
      MARKDOWN
      File.write(File.join(source, "false.md"), <<~MARKDOWN)
        ---
        layout: presentation
        title: False deck
        theme: minimal-dark
        progress: false
        slide_numbers: false
        overview: false
        fullscreen: false
        ---
        # Other server content
      MARKDOWN

      config = Jekyll.configuration("source" => source, "destination" => destination, "quiet" => true, "disable_disk_cache" => true)
      Jekyll::Site.new(config).process
      enabled = File.read(File.join(destination, "true.html"))
      disabled = File.read(File.join(destination, "false.html"))

      assert_includes enabled, "<title>True &lt;Deck&gt;</title>"
      assert_includes enabled, "data-presentation-root"
      assert_includes enabled, "data-presentation-chrome"
      assert_includes enabled, 'id="slides-overview-hint"'
      assert_includes enabled, 'aria-describedby="slides-overview-hint"'
      refute_match(/class="presentation-root js"/, enabled)
      assert_includes enabled, 'href="/slides/assets/css/presentation.css"'
      assert_includes enabled, 'src="/slides/assets/js/presentation.js"'
      assert_includes enabled, 'data-theme="ruby"'
      assert_equal 2, enabled.scan('data-theme="ruby"').length
      assert_includes enabled, 'data-aspect-ratio="16:9"'
      assert_includes enabled, 'data-progress="true"'
      assert_includes enabled, 'data-slide-numbers="true"'
      assert_includes enabled, 'data-overview="true"'
      assert_includes enabled, 'data-fullscreen="true"'
      assert_includes enabled, 'data-slide-count="1"'
      assert_match(/<main[^>]*>\s*<section class="slide /m, enabled)
      assert_includes enabled, "Server content"
      assert_includes enabled, 'aria-live="polite"'
      assert_includes enabled, 'aria-atomic="true"'
      assert_includes enabled, "data-slide-progress"
      assert_match(/<progress[^>]*data-slide-progress[^>]*max="1"[^>]*value="1"[^>]*aria-label="Slide progress"/, enabled)
      assert_includes enabled, "data-slide-overview"
      assert_includes enabled, "data-slide-fullscreen"
      assert_operator enabled.scan('type="button"').length, :>=, 4
      assert_includes enabled, 'aria-label="Previous slide"'
      assert_includes enabled, 'aria-label="Next slide"'
      assert_includes enabled, 'aria-pressed="false"'
      assert_includes enabled, 'aria-label="Show slide overview"'
      assert_includes enabled, 'aria-label="Enter fullscreen"'

      assert_includes disabled, 'data-theme="minimal-dark"'
      assert_equal 2, disabled.scan('data-theme="minimal-dark"').length
      assert_includes disabled, 'data-progress="false"'
      assert_includes disabled, 'data-slide-numbers="false"'
      assert_includes disabled, 'data-overview="false"'
      assert_includes disabled, 'data-fullscreen="false"'
      assert_includes disabled, "data-presentation-root"
      assert_includes disabled, "data-presentation-chrome"
      refute_includes disabled, "slides-overview-hint"
      refute_match(/class="presentation-root js"/, disabled)
      refute_includes disabled, "data-slide-progress"
      refute_includes disabled, "data-slide-counter"
      refute_includes disabled, "data-slide-overview"
      refute_includes disabled, "data-slide-fullscreen"
      assert_equal 2, disabled.scan('type="button"').length
      assert_includes disabled, 'aria-label="Previous slide"'
      assert_includes disabled, 'aria-label="Next slide"'
      assert_match(/<main[^>]*>\s*<section class="slide /m, disabled)
      assert_includes disabled, "Other server content"
    end
  end
end
