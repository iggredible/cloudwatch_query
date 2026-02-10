# frozen_string_literal: true

module CloudwatchQuery
  class Query
    include Enumerable

    DEFAULT_FIELDS = %w[@timestamp @message @logStream @log].freeze

    def initialize
      @log_groups = []
      @conditions = []
      @fields = DEFAULT_FIELDS.dup
      @start_time = nil
      @end_time = nil
      @limit = nil
      @sort_field = "@timestamp"
      @sort_order = "desc"
    end

    # Log group selection
    def logs(*groups)
      @log_groups.concat(groups.flatten)
      self
    end
    alias log_group logs

    # Filtering
    def where(**conditions)
      conditions.each do |field, value|
        field_name = field.to_s.start_with?("@") ? field.to_s : field.to_s
        @conditions << "#{field_name} = '#{escape_value(value)}'"
      end
      self
    end

    def contains(text)
      @conditions << "@message like /#{escape_regex(text)}/"
      self
    end

    def matches(pattern)
      @conditions << "@message like /#{pattern}/"
      self
    end

    # Time range
    def since(time)
      @start_time = TimeHelpers.to_epoch(time)
      self
    end

    def before(time)
      @end_time = TimeHelpers.to_epoch(time)
      self
    end

    def between(start_time, end_time)
      @start_time = TimeHelpers.to_epoch(start_time)
      @end_time = TimeHelpers.to_epoch(end_time)
      self
    end

    def last(amount, unit)
      seconds = TimeHelpers.duration_in_seconds(amount, unit)
      @start_time = (Time.now - seconds).to_i
      @end_time = Time.now.to_i
      self
    end

    # Field selection
    def fields(*field_list)
      @fields = field_list.flatten.map { |f| f.to_s.start_with?("@") ? f.to_s : "@#{f}" }
      self
    end

    def limit(n)
      @limit = n
      self
    end

    def sort(field, order = :desc)
      @sort_field = field.to_s.start_with?("@") ? field.to_s : "@#{field}"
      @sort_order = order.to_s
      self
    end

    # Execution
    def execute
      validate!
      client.execute(
        query_string: to_insights_query,
        log_group_names: @log_groups,
        start_time: resolved_start_time,
        end_time: resolved_end_time,
        limit: resolved_limit
      )
    end
    alias to_a execute

    def each(&block)
      execute.each(&block)
    end

    def to_insights_query
      parts = []
      parts << "fields #{@fields.join(', ')}"
      @conditions.each { |c| parts << "filter #{c}" }
      parts << "sort #{@sort_field} #{@sort_order}"
      parts << "limit #{resolved_limit}" if resolved_limit
      parts.join(" | ")
    end

    private

    def client
      @client ||= Client.new
    end

    def config
      CloudwatchQuery.configuration
    end

    def resolved_start_time
      @start_time || (Time.now - config.default_time_range).to_i
    end

    def resolved_end_time
      @end_time || Time.now.to_i
    end

    def resolved_limit
      @limit || config.default_limit
    end

    def validate!
      raise ConfigError, "No log groups specified" if @log_groups.empty?
    end

    def escape_value(value)
      value.to_s.gsub("'", "\\\\'")
    end

    def escape_regex(text)
      Regexp.escape(text.to_s)
    end
  end
end
