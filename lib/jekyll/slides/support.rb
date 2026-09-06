# frozen_string_literal: true

require "cgi/escape"

module Jekyll
  module Slides
    module Support
      module_function

      def warn(warning, message)
        return unless warning

        if warning.respond_to?(:call)
          warning.call(message)
        elsif warning.respond_to?(:warn)
          warning.warn(message)
        end
      end

      def escape(value)
        CGI.escapeHTML(value.to_s)
      end

      # A comparable Array key for natural filename ordering: digit runs
      # compare numerically, text runs compare case-insensitively, and digit
      # runs sort before text runs. The name itself is appended as a stable
      # tiebreaker so equal-value keys (e.g. "01-a" and "1-a") still order
      # deterministically.
      def natural_sort_key(name)
        name = name.to_s
        key = name.scan(/\d+|\D+/).map do |run|
          run.match?(/\A\d+\z/) ? [0, run.to_i, ""] : [1, 0, run.downcase]
        end
        key << [2, 0, name]
        key
      end
    end
  end
end
