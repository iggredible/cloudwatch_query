# frozen_string_literal: true

module CloudwatchQuery
  class ResultSet
    include Enumerable

    attr_reader :results, :statistics

    def initialize(results: [], statistics: {}, registry: nil)
      @results = results.map { |r| Result.new(r, registry: registry) }
      @statistics = statistics
    end

    def each(&block)
      @results.each(&block)
    end

    def count
      @results.count
    end
    alias size count
    alias length count

    def empty?
      @results.empty?
    end

    def first(n = nil)
      n ? @results.first(n) : @results.first
    end

    def last(n = nil)
      n ? @results.last(n) : @results.last
    end

    def to_a
      @results
    end

    # Filter results by log type
    def by_type(type)
      @results.select { |r| r.log_type == type }
    end

    # Get only parsed results
    def parsed
      @results.select(&:parsed?)
    end

    # Get only unparsed results
    def unparsed
      @results.reject(&:parsed?)
    end

    # Group results by request_id (for Rails logs)
    def group_by_request
      @results
        .select { |r| r.parsed&.respond_to?(:request_id) && r.parsed.request_id }
        .group_by { |r| r.parsed.request_id }
    end
  end
end
