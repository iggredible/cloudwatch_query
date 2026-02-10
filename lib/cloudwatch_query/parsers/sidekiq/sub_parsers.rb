# frozen_string_literal: true

module CloudwatchQuery
  module Parsers
    module Sidekiq
      # Base module for Sidekiq sub-parsers
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

      # Parses job start: "INFO: start"
      class StartSubParser
        include SubParser

        def self.matches?(message)
          message.end_with?("INFO: start")
        end

        def self.parse(_message, _base_data)
          {
            line_type: :start,
            status: "start"
          }
        end
      end

      # Parses job done with elapsed: "elapsed=0.152 INFO: done"
      class DoneSubParser
        include SubParser

        ELAPSED_REGEX = /elapsed=(?<elapsed>[\d.]+)\s+INFO:\s+done$/

        def self.matches?(message)
          message.include?("INFO: done")
        end

        def self.parse(message, _base_data)
          match = message.match(ELAPSED_REGEX)
          elapsed = match ? match[:elapsed].to_f : nil

          {
            line_type: :done,
            status: "done",
            elapsed: elapsed
          }
        end
      end

      # Parses job failure: "INFO: fail" or error messages
      class FailSubParser
        include SubParser

        def self.matches?(message)
          message.include?("INFO: fail") || message.include?("ERROR:")
        end

        def self.parse(message, _base_data)
          {
            line_type: :fail,
            status: "fail"
          }
        end
      end
    end
  end
end
