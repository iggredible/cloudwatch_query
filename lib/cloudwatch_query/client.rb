# frozen_string_literal: true

require "aws-sdk-cloudwatchlogs"

module CloudwatchQuery
  class Client
    DEFAULT_POLL_INTERVAL = 1
    DEFAULT_TIMEOUT = 60

    attr_reader :aws_client

    def initialize(region: nil, profile: nil)
      config = CloudwatchQuery.configuration
      client_options = {
        region: region || config.region
      }

      # AWS SDK automatically picks up credentials from:
      # 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
      # 2. Shared credentials file (~/.aws/credentials) - set by saml2aws
      # 3. EC2 instance metadata
      @aws_client = Aws::CloudWatchLogs::Client.new(client_options)
    end

    def execute(query_string:, log_group_names:, start_time:, end_time:, limit:)
      query_id = start_query(
        query_string: query_string,
        log_group_names: log_group_names,
        start_time: start_time,
        end_time: end_time,
        limit: limit
      )

      poll_results(query_id)
    rescue Aws::CloudWatchLogs::Errors::ServiceError => e
      handle_aws_error(e)
    end

    def list_log_groups(prefix: nil)
      options = {}
      options[:log_group_name_prefix] = prefix if prefix

      groups = []
      aws_client.describe_log_groups(options).each_page do |page|
        groups.concat(page.log_groups.map(&:log_group_name))
      end
      groups
    rescue Aws::CloudWatchLogs::Errors::ServiceError => e
      handle_aws_error(e)
    end

    private

    def start_query(query_string:, log_group_names:, start_time:, end_time:, limit:)
      response = aws_client.start_query(
        log_group_names: Array(log_group_names),
        start_time: start_time,
        end_time: end_time,
        query_string: query_string,
        limit: limit
      )
      response.query_id
    end

    def poll_results(query_id, timeout: DEFAULT_TIMEOUT)
      deadline = Time.now + timeout

      loop do
        raise TimeoutError, "Query timed out after #{timeout} seconds" if Time.now > deadline

        response = aws_client.get_query_results(query_id: query_id)

        case response.status
        when "Complete"
          return build_result_set(response)
        when "Failed", "Cancelled"
          raise QueryError, "Query #{response.status.downcase}"
        when "Running", "Scheduled"
          sleep(DEFAULT_POLL_INTERVAL)
        else
          raise QueryError, "Unknown query status: #{response.status}"
        end
      end
    end

    def build_result_set(response)
      results = response.results.map do |row|
        row.each_with_object({}) do |field, hash|
          key = field.field.sub(/^@/, "")
          hash[key] = field.value
        end
      end

      ResultSet.new(
        results: results,
        statistics: response.statistics&.to_h || {},
        registry: CloudwatchQuery.parsers
      )
    end

    def handle_aws_error(error)
      case error
      when Aws::CloudWatchLogs::Errors::AccessDeniedException,
           Aws::CloudWatchLogs::Errors::UnauthorizedException
        raise AuthError, "AWS authentication failed: #{error.message}"
      else
        raise QueryError, "AWS error: #{error.message}"
      end
    end
  end
end
