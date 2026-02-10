# frozen_string_literal: true

RSpec.describe CloudwatchQuery::Query do
  subject(:query) { described_class.new }

  describe "#logs" do
    it "returns self for chaining" do
      expect(query.logs("group1")).to eq(query)
    end

    it "accepts multiple groups" do
      query.logs("group1", "group2")
      insights = query.to_insights_query
      expect(insights).to include("fields")
    end
  end

  describe "#where" do
    it "adds equality filter" do
      query.logs("group1").where(level: "ERROR")
      expect(query.to_insights_query).to include("filter level = 'ERROR'")
    end

    it "handles multiple conditions" do
      query.logs("group1").where(level: "ERROR", env: "production")
      insights = query.to_insights_query
      expect(insights).to include("filter level = 'ERROR'")
      expect(insights).to include("filter env = 'production'")
    end
  end

  describe "#contains" do
    it "adds message filter" do
      query.logs("group1").contains("timeout")
      expect(query.to_insights_query).to include("filter @message like /timeout/")
    end

    it "escapes regex special characters" do
      query.logs("group1").contains("error.*")
      expect(query.to_insights_query).to include("filter @message like /error\\.\\*/")
    end

    it "escapes brackets and special chars" do
      query.logs("group1").contains("[test]")
      expect(query.to_insights_query).to include("filter @message like /\\[test\\]/")
    end
  end

  describe "#matches" do
    it "adds regex filter without escaping" do
      query.logs("group1").matches("error.*timeout")
      expect(query.to_insights_query).to include("filter @message like /error.*timeout/")
    end
  end

  describe "#last" do
    it "sets time range" do
      query.logs("group1").last(30, :minutes)
      # The time range is used during execution, not in the query string
      expect(query.to_insights_query).to include("fields")
    end
  end

  describe "#fields" do
    it "customizes selected fields" do
      query.logs("group1").fields(:timestamp, :message)
      expect(query.to_insights_query).to start_with("fields @timestamp, @message")
    end

    it "adds @ prefix if missing" do
      query.logs("group1").fields("timestamp", "message")
      expect(query.to_insights_query).to start_with("fields @timestamp, @message")
    end
  end

  describe "#limit" do
    it "sets result limit" do
      query.logs("group1").limit(50)
      expect(query.to_insights_query).to include("limit 50")
    end
  end

  describe "#to_insights_query" do
    it "builds complete query string" do
      insights = query
        .logs("group1")
        .where(level: "ERROR")
        .contains("timeout")
        .limit(100)
        .to_insights_query

      expect(insights).to eq(
        "fields @timestamp, @message, @logStream, @log | " \
        "filter level = 'ERROR' | " \
        "filter @message like /timeout/ | " \
        "sort @timestamp desc | " \
        "limit 100"
      )
    end
  end

  describe "#execute" do
    it "raises ConfigError when no log groups specified" do
      expect { query.execute }.to raise_error(CloudwatchQuery::ConfigError, "No log groups specified")
    end
  end
end
