# frozen_string_literal: true

require_relative "rails/sub_parsers"
require_relative "rails/rails_log"

module CloudwatchQuery
  module Parsers
    class RailsParser < Base
      # Built-in sub-parsers mapped to symbols
      BUILT_IN_SUB_PARSERS = {
        request: Rails::RequestSubParser,
        parameters: Rails::ParametersSubParser,
        redirect: Rails::RedirectSubParser,
        active_job: Rails::ActiveJobSubParser,
        processing: Rails::ProcessingSubParser,
        completed: Rails::CompletedSubParser
      }.freeze

      # Matches request UUID pattern: [abc-123-def-456]
      REQUEST_ID_REGEX = /\[(?<request_id>[a-f0-9-]{36})\]/

      # Matches syslog prefix: "Feb  4 22:37:47 ip-10-15-1-216 cryo[1030829]:"
      SYSLOG_PREFIX_REGEX = /^(?<syslog_timestamp>\w+\s+\d+\s+[\d:]+)\s+(?<server>[\w.-]+)\s+\w+\[(?<process_id>\d+)\]:\s*/

      attr_reader :sub_parsers

      # Initialize with specific sub-parsers or use all defaults
      #
      # @example Use all defaults
      #   RailsParser.new
      #
      # @example Use only specific built-in sub-parsers
      #   RailsParser.new(:request, :parameters)
      #
      # @example Mix built-in and custom sub-parsers
      #   RailsParser.new(:request, :parameters, MyCustomSubParser)
      #
      # @example All defaults plus custom
      #   RailsParser.new(:all, MyCustomSubParser)
      #
      def initialize(*args)
        @sub_parsers = resolve_sub_parsers(args)
      end

      def matches?(message)
        # Must have a Rails request UUID pattern
        message.match?(REQUEST_ID_REGEX)
      end

      def parse(message)
        return nil unless matches?(message)

        base_data = extract_base_data(message)
        clean_message = strip_syslog_prefix(message)

        # Try each sub-parser until one matches
        sub_parser_data = {}
        @sub_parsers.each do |parser|
          if parser.matches?(clean_message)
            sub_parser_data = parser.parse(clean_message, base_data)
            break if sub_parser_data[:line_type]
          end
        end

        # If no sub-parser matched, mark as unknown
        sub_parser_data[:line_type] ||= :unknown
        sub_parser_data[:raw_message] = message if sub_parser_data[:line_type] == :unknown

        Rails::RailsLog.new(base_data.merge(sub_parser_data))
      end

      # Class method for simple usage (uses all defaults)
      class << self
        def matches?(message)
          new.matches?(message)
        end

        def parse(message)
          new.parse(message)
        end

        def parser_name
          "rails"
        end

        # List available built-in sub-parser names
        def available_sub_parsers
          BUILT_IN_SUB_PARSERS.keys
        end
      end

      private

      def resolve_sub_parsers(args)
        return BUILT_IN_SUB_PARSERS.values if args.empty?

        parsers = []
        args.each do |arg|
          case arg
          when :all
            parsers.concat(BUILT_IN_SUB_PARSERS.values)
          when Symbol
            parser = BUILT_IN_SUB_PARSERS[arg]
            raise ArgumentError, "Unknown sub-parser: #{arg}. Available: #{BUILT_IN_SUB_PARSERS.keys.join(', ')}" unless parser

            parsers << parser
          else
            # Assume it's a custom sub-parser class/object
            validate_sub_parser!(arg)
            parsers << arg
          end
        end
        parsers.uniq
      end

      def validate_sub_parser!(parser)
        unless parser.respond_to?(:matches?) && parser.respond_to?(:parse)
          raise ArgumentError, "Sub-parser must respond to .matches?(message) and .parse(message, base_data)"
        end
      end

      def extract_base_data(message)
        data = {}

        # Extract request ID
        if (match = message.match(REQUEST_ID_REGEX))
          data[:request_id] = match[:request_id]
        end

        # Extract syslog prefix data
        if (match = message.match(SYSLOG_PREFIX_REGEX))
          data[:server] = match[:server]
          data[:process_id] = match[:process_id]
        end

        data
      end

      def strip_syslog_prefix(message)
        message.sub(SYSLOG_PREFIX_REGEX, "")
      end
    end
  end
end
