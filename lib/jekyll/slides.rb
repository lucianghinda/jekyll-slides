# frozen_string_literal: true

require "jekyll"
require "rouge"

module Jekyll
  module Slides
    ROOT = File.expand_path("../..", __dir__)
    LAYOUT_NAME = "presentation"
  end
end

require_relative "slides/version"
require_relative "slides/support"
require_relative "slides/presentation_parser"
require_relative "slides/slide_metadata"
require_relative "slides/range_parser"
require_relative "slides/rouge_renderer"
require_relative "slides/component_renderer"
require_relative "slides/slide_renderer"
require_relative "slides/presentation"
require_relative "slides/renderer"
require_relative "slides/layout"
require_relative "slides/assets"
require_relative "slides/jekyll_integration"
