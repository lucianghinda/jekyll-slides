# frozen_string_literal: true

require "jekyll"

module Jekyll
  module Slides
    module JekyllIntegration
      DEFAULTS = {
        "theme" => "midnight",
        "aspect_ratio" => "16:9",
        "progress" => true,
        "slide_numbers" => true,
        "overview" => true,
        "fullscreen" => true
      }.freeze
      THEMES = %w[minimal-light minimal-dark midnight ruby].freeze
      BOOLEAN_OPTIONS = %w[progress slide_numbers overview fullscreen].freeze
      OPTION_KEYS = DEFAULTS.keys.freeze

      class << self
        def install!
          return if @installed

          Jekyll::Hooks.register(:site, :post_read) do |site|
            process_site(site)
          end
          @installed = true
        end

        def process_site(site)
          install_resources(site)
          DeckAssembler.assemble(site)
          presentation_documents(site).each { |document| process(document) }
        end

        def process(document)
          return unless presentation?(document)
          return if document.instance_variable_defined?(:@jekyll_slides_processed)

          site = document.site
          options = normalized_options(site, document.data)
          source = document.content.to_s
          document.data.merge!(normalized_data(options, source))
          document.instance_variable_set(:@renderer, Renderer.new(site, document))
          document.instance_variable_set(:@jekyll_slides_processed, true)
        end

        private

        def presentation?(document)
          document.respond_to?(:data) && document.data.is_a?(Hash) && document.data["layout"].to_s == "presentation"
        end

        def install_resources(site)
          site.layouts[LAYOUT_NAME] ||= Layout.new(site)
          includes_path = File.join(ROOT, "_includes")
          site.includes_load_paths << includes_path unless site.includes_load_paths.include?(includes_path)
          Assets.install(site)
        end

        def presentation_documents(site)
          collection_documents = site.collections.values.flat_map(&:docs)
          site.pages + collection_documents
        end

        def normalized_options(site, front_matter)
          global = site.config.is_a?(Hash) ? site.config["slides"] : nil
          if global.nil?
            global = {}
          elsif !global.is_a?(Hash)
            warning("Invalid slides configuration; using defaults")
            global = {}
          end

          OPTION_KEYS.to_h do |key|
            value = front_matter[key]
            value = global.fetch(key, DEFAULTS[key]) if value.nil?
            [key, normalize_option(key, value)]
          end
        end

        def normalize_option(key, value)
          case key
          when "theme"
            theme = value.to_s
            return theme if THEMES.include?(theme)

            warning("Invalid theme #{value.inspect}; falling back to midnight")
            DEFAULTS[key]
          when "aspect_ratio"
            return value if value == DEFAULTS[key]

            warning("Invalid aspect ratio #{value.inspect}; quote it in YAML as aspect_ratio: \"16:9\"; falling back to 16:9")
            DEFAULTS[key]
          when *BOOLEAN_OPTIONS
            return value if [true, false].include?(value)

            normalized = value.to_s.strip.downcase
            return true if normalized == "true"
            return false if normalized == "false"

            warning("Invalid #{key} option #{value.inspect}; falling back to #{DEFAULTS[key]}")
            DEFAULTS[key]
          end
        end

        def normalized_data(options, source)
          {
            "slides_theme" => options["theme"],
            "slides_aspect_ratio" => options["aspect_ratio"],
            "slides_progress" => options["progress"],
            "slides_slide_numbers" => options["slide_numbers"],
            "slides_overview" => options["overview"],
            "slides_fullscreen" => options["fullscreen"],
            "slides_count" => PresentationParser.new(source).parse.length
          }
        end

        def warning(message)
          Jekyll.logger.warn("Jekyll Slides:", message)
        end
      end
    end
  end
end

Jekyll::Slides::JekyllIntegration.install!
