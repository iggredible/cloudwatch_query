# frozen_string_literal: true

require_relative "cloudwatch_query/version"
require_relative "cloudwatch_query/errors"
require_relative "cloudwatch_query/configuration"
require_relative "cloudwatch_query/time_helpers"
require_relative "cloudwatch_query/parsers"
require_relative "cloudwatch_query/result"
require_relative "cloudwatch_query/result_set"
require_relative "cloudwatch_query/client"
require_relative "cloudwatch_query/query"

module CloudwatchQuery
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Parser registry - manages log message parsers
    def parsers
      @parsers ||= begin
        registry = Parsers::Registry.new
        registry.register(*Parsers.default_parsers)
        registry
      end
    end

    # Reset parsers to defaults
    def reset_parsers!
      @parsers = nil
      parsers
    end

    # Start a query for the specified log groups
    def logs(*groups)
      Query.new.logs(*groups)
    end
    alias log_group logs

    # Quick search shorthand
    def search(term, groups:, since: nil, limit: nil, **options)
      query = Query.new.logs(*Array(groups)).contains(term)
      query = query.since(since) if since
      query = query.limit(limit) if limit
      query.execute
    end

    # List available log groups
    def list_log_groups(prefix: nil)
      Client.new.list_log_groups(prefix: prefix)
    end
  end
end
