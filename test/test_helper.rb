# frozen_string_literal: true

require "cgi/escape"
require "minitest/autorun"
require_relative "../lib/jekyll-slides"

class Minitest::Test
  def converter
    ->(markdown) { "<p>#{CGI.escapeHTML(markdown.strip)}</p>" }
  end
end
