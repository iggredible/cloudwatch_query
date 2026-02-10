# frozen_string_literal: true

module CloudwatchQuery
  module Parsers
    module Rails
      # Base module for Rails sub-parsers
      module SubParser
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def matches?(_message)
            raise NotImplementedError
          end

          def parse(_message, _base_data)
            raise NotImplementedError
          end
        end
      end

      # Parses: "Started GET "/path" for 1.2.3.4 at 2026-02-04 18:37:21 +0000"
      class RequestSubParser
        include SubParser

        REQUEST_REGEX = /Started\s+(?<http_method>GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+"(?<path>[^"]+)"\s+for\s+(?<ip_address>[\d.]+)\s+at\s+(?<timestamp>.+)$/

        def self.matches?(message)
          message.include?("Started ") &&
            (message.include?(" GET ") || message.include?(" POST ") ||
             message.include?(" PUT ") || message.include?(" PATCH ") ||
             message.include?(" DELETE "))
        end

        def self.parse(message, _base_data)
          match = message.match(REQUEST_REGEX)
          return {} unless match

          {
            line_type: :request,
            http_method: match[:http_method],
            path: match[:path],
            ip_address: match[:ip_address],
            request_timestamp: match[:timestamp]
          }
        end
      end

      # Parses: "Parameters: {...}"
      class ParametersSubParser
        include SubParser

        PARAMS_REGEX = /Parameters:\s+(?<params>\{.+\})$/

        def self.matches?(message)
          message.include?("Parameters: {")
        end

        def self.parse(message, _base_data)
          match = message.match(PARAMS_REGEX)
          return {} unless match

          {
            line_type: :parameters,
            params: safe_parse_params(match[:params])
          }
        end

        def self.safe_parse_params(params_string)
          JSON.parse(
            params_string
              .gsub(/=>/, ":")
              .gsub(/:(\w+)/, '"\1"')
              .gsub(/nil/, "null")
          )
        rescue JSON::ParserError, StandardError
          { raw: params_string }
        end
      end

      # Parses: "Redirected to https://..."
      class RedirectSubParser
        include SubParser

        REDIRECT_REGEX = /Redirected to\s+(?<redirect_url>.+)$/

        def self.matches?(message)
          message.include?("Redirected to ")
        end

        def self.parse(message, _base_data)
          match = message.match(REDIRECT_REGEX)
          return {} unless match

          {
            line_type: :redirect,
            redirect_url: match[:redirect_url].strip
          }
        end
      end

      # Parses: "[ActiveJob] Enqueued JobClass (Job ID: uuid) to Sidekiq(queue)"
      class ActiveJobSubParser
        include SubParser

        ACTIVE_JOB_REGEX = /\[ActiveJob\]\s+Enqueued\s+(?<job_class>[\w:]+)\s+\(Job ID:\s+(?<job_id>[^)]+)\)\s+to\s+\w+\((?<queue>\w+)\)(?:\s+with arguments:\s+(?<arguments>.+))?$/

        def self.matches?(message)
          message.include?("[ActiveJob] Enqueued")
        end

        def self.parse(message, _base_data)
          match = message.match(ACTIVE_JOB_REGEX)
          return {} unless match

          {
            line_type: :active_job,
            job_class: match[:job_class],
            job_id: match[:job_id],
            queue: match[:queue],
            arguments: match[:arguments]&.strip
          }
        end
      end

      # Parses: "Processing by Controller#action as FORMAT"
      class ProcessingSubParser
        include SubParser

        PROCESSING_REGEX = /Processing by\s+(?<controller>\w+)#(?<action>\w+)\s+as\s+(?<format>\w+)/

        def self.matches?(message)
          message.include?("Processing by ")
        end

        def self.parse(message, _base_data)
          match = message.match(PROCESSING_REGEX)
          return {} unless match

          {
            line_type: :processing,
            controller: match[:controller],
            action: match[:action],
            format: match[:format]
          }
        end
      end

      # Parses: "Completed 200 OK in 123ms"
      class CompletedSubParser
        include SubParser

        COMPLETED_REGEX = /Completed\s+(?<status>\d+)\s+\w+\s+in\s+(?<duration>[\d.]+)(?<unit>ms|s)/

        def self.matches?(message)
          message.include?("Completed ")
        end

        def self.parse(message, _base_data)
          match = message.match(COMPLETED_REGEX)
          return {} unless match

          duration_ms = match[:unit] == "s" ? match[:duration].to_f * 1000 : match[:duration].to_f

          {
            line_type: :completed,
            status_code: match[:status].to_i,
            duration_ms: duration_ms
          }
        end
      end
    end
  end
end
