# frozen_string_literal: true

require_relative "sidekiq/sub_parsers"
require_relative "sidekiq/sidekiq_log"

module CloudwatchQuery
  module Parsers
    class SidekiqParser < Base
      # Built-in sub-parsers mapped to symbols
      BUILT_IN_SUB_PARSERS = {
        start: Sidekiq::StartSubParser,
        done: Sidekiq::DoneSubParser,
        fail: Sidekiq::FailSubParser
      }.freeze

      # Matches Sidekiq log format: "2026-02-04T20:46:15.201Z pid=123 tid=abc class=Job jid=xyz"
      SIDEKIQ_PATTERN = /^\d{4}-\d{2}-\d{2}T[\d:.]+Z\s+pid=\d+\s+tid=\w+\s+class=/
      BASE_REGEX = /^(?<timestamp>\d{4}-\d{2}-\d{2}T[\d:.]+Z)\s+pid=(?<pid>\d+)\s+tid=(?<tid>\w+)\s+class=(?<job_class>[\w:]+)\s+jid=(?<jid>\w+)/

      attr_reader :sub_parsers

      # Initialize with specific sub-parsers or use all defaults
      #
      # @example Use all defaults
      #   SidekiqParser.new
      #
      # @example Use only specific built-in sub-parsers
      #   SidekiqParser.new(:start, :done)
      #
      # @example Mix built-in and custom sub-parsers
      #   SidekiqParser.new(:start, :done, MyCustomSubParser)
      #
      # @example All defaults plus custom
      #   SidekiqParser.new(:all, MyCustomSubParser)
      #
      def initialize(*args)
        @sub_parsers = resolve_sub_parsers(args)
      end

      def matches?(message)
        message.match?(SIDEKIQ_PATTERN)
      end

      def parse(message)
        return nil unless matches?(message)

        base_data = extract_base_data(message)
        return nil if base_data.empty?

        # Try each sub-parser until one matches
        sub_parser_data = {}
        @sub_parsers.each do |parser|
          if parser.matches?(message)
            sub_parser_data = parser.parse(message, base_data)
            break if sub_parser_data[:line_type]
          end
        end

        # If no sub-parser matched, mark as unknown
        sub_parser_data[:line_type] ||= :unknown
        sub_parser_data[:raw_message] = message if sub_parser_data[:line_type] == :unknown

        Sidekiq::SidekiqLog.new(base_data.merge(sub_parser_data))
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
          "sidekiq"
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
        match = message.match(BASE_REGEX)
        return {} unless match

        {
          timestamp: match[:timestamp],
          pid: match[:pid],
          tid: match[:tid],
          job_class: match[:job_class],
          jid: match[:jid]
        }
      end
    end
  end
end
