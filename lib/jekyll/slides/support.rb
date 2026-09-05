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
    end
  end
end
