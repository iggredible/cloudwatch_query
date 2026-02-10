# frozen_string_literal: true

module CloudwatchQuery
  module TimeHelpers
    UNIT_MULTIPLIERS = {
      seconds: 1,
      second: 1,
      minutes: 60,
      minute: 60,
      hours: 3600,
      hour: 3600,
      days: 86400,
      day: 86400,
      weeks: 604800,
      week: 604800
    }.freeze

    def self.duration_in_seconds(amount, unit)
      multiplier = UNIT_MULTIPLIERS[unit.to_sym]
      raise ConfigError, "Unknown time unit: #{unit}" unless multiplier

      amount * multiplier
    end

    def self.to_epoch(time)
      case time
      when Time, DateTime
        time.to_i
      when Integer
        time
      when String
        Time.parse(time).to_i
      else
        raise ConfigError, "Cannot convert #{time.class} to epoch time"
      end
    end

    def self.parse_relative_time(str)
      return nil unless str.is_a?(String)

      match = str.match(/^(\d+)(s|m|h|d|w)$/)
      return nil unless match

      amount = match[1].to_i
      unit = case match[2]
             when "s" then :seconds
             when "m" then :minutes
             when "h" then :hours
             when "d" then :days
             when "w" then :weeks
             end

      Time.now - duration_in_seconds(amount, unit)
    end
  end
end
