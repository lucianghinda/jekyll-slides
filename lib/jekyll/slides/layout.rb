# frozen_string_literal: true

module Jekyll
  module Slides
    class Layout < Jekyll::Layout
      def initialize(site)
        @site = site
        @base = ROOT
        @base_dir = ROOT
        @name = "presentation.html"
        @path = File.join(ROOT, "_layouts", @name)
        @relative_path = File.join("_layouts", @name)
        self.data = {}

        process(@name)
        read_yaml(File.dirname(@path), @name)
      end
    end
  end
end
