# frozen_string_literal: true

module CloudwatchQuery
  class Result
    attr_reader :data, :parsed, :parser_name

    def initialize(data, registry: nil)
      @data = data.transform_keys(&:to_sym)
      @registry = registry
      @parsed = nil
      @parser_name = nil
      parse_message! if @registry
    end

    def timestamp
      @data[:timestamp]
    end

    def message
      @data[:message]
    end

    def log_stream
      @data[:logStream]
    end

    def log
      @data[:log]
    end

    def [](key)
      @data[key.to_sym]
    end

    def to_h
      @data.dup
    end

    # Check if message was successfully parsed
    def parsed?
      !@parsed.nil?
    end

    # Get the type of parsed log (e.g., :rails_request, :sidekiq)
    def log_type
      @parsed&.type
    end

    def respond_to_missing?(method_name, include_private = false)
      @data.key?(method_name.to_sym) || super
    end

    def method_missing(method_name, *args)
      key = method_name.to_sym
      return @data[key] if @data.key?(key)

      super
    end

    private

    def parse_message!
      return unless message

      @parsed, @parser_name = @registry.parse(message)
    end
  end
end
