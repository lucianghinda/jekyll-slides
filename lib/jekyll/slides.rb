# frozen_string_literal: true

require "jekyll"
require "rouge"

module Jekyll
  # Markdown presentations for Jekyll, with editor and terminal components.
  #
  # Add +jekyll-slides+ to the site's plugins and choose the +presentation+
  # layout on a Markdown page. Separate slides with +---+ outside fenced code blocks.
  # The plugin supplies layouts, includes, styles, scripts, and offline fonts
  # while preserving the site's theme and local overrides.
  #
  # Configure defaults under +slides:+ in _config.yml, or use front matter on
  # individual decks. The supported aspect ratio is 16:9; quote this value in YAML.
  #
  # Jekyll runs Liquid before rendering each slide as one Markdown document.
  # Jekyll::Slides::Presentation also renders slide HTML directly when Jekyll integration
  # is not needed; it does not evaluate Liquid or wrap the presentation layout.
  module Slides
    ROOT = File.expand_path("../..", __dir__)
    LAYOUT_NAME = "presentation"

    # Every deck palette the plugin ships. A theme sets the whole deck through
    # front matter, and any one of them also restyles a single editor or
    # terminal block through that block's +theme+ attribute.
    THEMES = %w[
      minimal-light minimal-dark midnight ruby
      catppuccin-latte catppuccin-frappe catppuccin-macchiato catppuccin-mocha
    ].freeze

    # Every palette a single editor or terminal block may carry: the deck
    # palettes plus the ones that exist only at window scale. +macos-light+ is
    # a flat light code window meant to sit inside a deck of any color, so it
    # defines no slide background or type scale and cannot be a deck theme.
    COMPONENT_THEMES = (THEMES + %w[macos-light]).freeze
    DEFAULT_THEME = "midnight"
  end
end

require_relative "slides/version"
require_relative "slides/support"
require_relative "slides/front_matter"
require_relative "slides/presentation_parser"
require_relative "slides/slide_metadata"
require_relative "slides/slide_file"
require_relative "slides/deck"
require_relative "slides/deck_assembler"
require_relative "slides/range_parser"
require_relative "slides/rouge_renderer"
require_relative "slides/component_renderer"
require_relative "slides/slide_renderer"
require_relative "slides/presentation"
require_relative "slides/renderer"
require_relative "slides/layout"
require_relative "slides/assets"
require_relative "slides/jekyll_integration"
