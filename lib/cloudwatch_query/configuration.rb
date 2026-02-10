# frozen_string_literal: true

module CloudwatchQuery
  class Configuration
    attr_accessor :region, :profile, :default_limit, :default_time_range

    def initialize
      @region = ENV["AWS_REGION"] || "us-west-1"
      @profile = ENV["AWS_PROFILE"]
      @default_limit = 100
      @default_time_range = 3600
    end
  end
end
