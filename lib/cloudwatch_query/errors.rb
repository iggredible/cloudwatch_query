# frozen_string_literal: true

module CloudwatchQuery
  class Error < StandardError; end
  class QueryError < Error; end
  class ConfigError < Error; end
  class AuthError < Error; end
  class TimeoutError < Error; end
end
