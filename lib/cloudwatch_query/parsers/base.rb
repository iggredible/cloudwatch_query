# frozen_string_literal: true

module CloudwatchQuery
  module Parsers
    class Base
      class << self
        # Override in subclass - return true if this parser can handle the message
        def matches?(message)
          raise NotImplementedError, "#{name} must implement .matches?(message)"
        end

        # Override in subclass - parse the message and return a structured object
        def parse(message)
          raise NotImplementedError, "#{name} must implement .parse(message)"
        end

        # Human-readable name for this parser
        def parser_name
          name.split("::").last.sub(/Parser$/, "").gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        end
      end
    end
  end
end
