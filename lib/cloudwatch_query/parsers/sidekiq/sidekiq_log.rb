# frozen_string_literal: true

module CloudwatchQuery
  module Parsers
    module Sidekiq
      class SidekiqLog
        attr_reader :timestamp, :pid, :tid, :job_class, :jid,
                    :line_type, :status, :elapsed,
                    :raw_message

        def initialize(attributes = {})
          attributes.each do |key, value|
            instance_variable_set("@#{key}", value) if respond_to?(key)
          end
          @line_type ||= :unknown
        end

        def type
          :sidekiq
        end

        def start?
          line_type == :start
        end

        def done?
          line_type == :done
        end

        def fail?
          line_type == :fail
        end

        # Alias for elapsed
        def duration
          elapsed
        end

        def to_h
          instance_variables.each_with_object({}) do |var, hash|
            key = var.to_s.delete("@").to_sym
            value = instance_variable_get(var)
            hash[key] = value unless value.nil?
          end
        end

        def [](key)
          instance_variable_get("@#{key}")
        end
      end
    end
  end
end
