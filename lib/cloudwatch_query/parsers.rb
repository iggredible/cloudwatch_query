# frozen_string_literal: true

require_relative "parsers/base"
require_relative "parsers/registry"
require_relative "parsers/rails_parser"
require_relative "parsers/sidekiq_parser"

module CloudwatchQuery
  module Parsers
    class << self
      def default_parsers
        [
          RailsParser.new,
          SidekiqParser.new
        ]
      end
    end
  end
end
