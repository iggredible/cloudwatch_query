# frozen_string_literal: true

module CloudwatchQuery
  module Parsers
    class Registry
      def initialize
        @parsers = []
      end

      # Register one or more parsers (appends to end, lower priority)
      def register(*parsers)
        parsers.flatten.each do |parser|
          validate_parser!(parser)
          @parsers << parser unless @parsers.include?(parser)
        end
        self
      end

      # Add parser(s) at the beginning (highest priority)
      def prepend(*parsers)
        parsers.flatten.reverse.each do |parser|
          validate_parser!(parser)
          @parsers.delete(parser)
          @parsers.unshift(parser)
        end
        self
      end

      # Insert parser at specific index
      def insert(index, parser)
        validate_parser!(parser)
        @parsers.delete(parser)
        @parsers.insert(index, parser)
        self
      end

      # Remove a parser
      def unregister(parser)
        @parsers.delete(parser)
        self
      end

      # Clear all parsers
      def clear
        @parsers.clear
        self
      end

      # List all registered parsers
      def list
        @parsers.dup
      end

      # Parse a message using the first matching parser
      # Returns [parsed_object, parser_name] or [nil, nil] if no match
      def parse(message)
        return [nil, nil] if message.nil? || message.empty?

        @parsers.each do |parser|
          if parser.matches?(message)
            begin
              parsed = parser.parse(message)
              return [parsed, get_parser_name(parser)] if parsed
            rescue StandardError
              # Parser failed, try next one
              next
            end
          end
        end

        [nil, nil]
      end

      private

      def get_parser_name(parser)
        if parser.respond_to?(:parser_name)
          parser.parser_name
        elsif parser.class.respond_to?(:parser_name)
          parser.class.parser_name
        else
          parser.class.name.split("::").last.sub(/Parser$/, "").downcase
        end
      end

      def validate_parser!(parser)
        unless parser.respond_to?(:matches?) && parser.respond_to?(:parse)
          raise ArgumentError, "Parser must respond to .matches?(message) and .parse(message)"
        end
      end
    end
  end
end
