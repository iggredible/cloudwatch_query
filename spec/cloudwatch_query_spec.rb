# frozen_string_literal: true

RSpec.describe CloudwatchQuery do
  it "has a version number" do
    expect(CloudwatchQuery::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "allows setting region" do
      described_class.configure do |config|
        config.region = "eu-west-1"
      end

      expect(described_class.configuration.region).to eq("eu-west-1")
    end

    it "allows setting default_limit" do
      described_class.configure do |config|
        config.default_limit = 50
      end

      expect(described_class.configuration.default_limit).to eq(50)
    end

    it "allows setting default_time_range" do
      described_class.configure do |config|
        config.default_time_range = 7200
      end

      expect(described_class.configuration.default_time_range).to eq(7200)
    end
  end

  describe ".logs" do
    it "returns a Query object" do
      query = described_class.logs("my-log-group")
      expect(query).to be_a(CloudwatchQuery::Query)
    end
  end
end
