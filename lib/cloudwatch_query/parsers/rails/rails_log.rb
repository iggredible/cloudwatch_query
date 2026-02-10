# frozen_string_literal: true

module CloudwatchQuery
  module Parsers
    module Rails
      class RailsLog
        attr_reader :request_id, :line_type, :server, :process_id,
                    # Request fields
                    :http_method, :path, :ip_address, :request_timestamp,
                    # Parameters fields
                    :params,
                    # Redirect fields
                    :redirect_url,
                    # ActiveJob fields
                    :job_class, :job_id, :queue, :arguments,
                    # Processing fields
                    :controller, :action, :format,
                    # Completed fields
                    :status_code, :duration_ms,
                    # Raw message for unparsed line types
                    :raw_message

        def initialize(attributes = {})
          attributes.each do |key, value|
            instance_variable_set("@#{key}", value) if respond_to?(key)
          end
          @line_type ||= :unknown
        end

        def type
          :rails
        end

        def request?
          line_type == :request
        end

        def parameters?
          line_type == :parameters
        end

        def redirect?
          line_type == :redirect
        end

        def active_job?
          line_type == :active_job
        end

        def processing?
          line_type == :processing
        end

        def completed?
          line_type == :completed
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
