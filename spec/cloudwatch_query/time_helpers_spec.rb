# frozen_string_literal: true

RSpec.describe CloudwatchQuery::TimeHelpers do
  describe ".duration_in_seconds" do
    it "converts minutes to seconds" do
      expect(described_class.duration_in_seconds(30, :minutes)).to eq(1800)
    end

    it "converts hours to seconds" do
      expect(described_class.duration_in_seconds(2, :hours)).to eq(7200)
    end

    it "converts days to seconds" do
      expect(described_class.duration_in_seconds(1, :days)).to eq(86400)
    end

    it "converts weeks to seconds" do
      expect(described_class.duration_in_seconds(1, :weeks)).to eq(604800)
    end

    it "handles singular units" do
      expect(described_class.duration_in_seconds(1, :minute)).to eq(60)
      expect(described_class.duration_in_seconds(1, :hour)).to eq(3600)
    end

    it "raises error for unknown unit" do
      expect { described_class.duration_in_seconds(1, :unknown) }
        .to raise_error(CloudwatchQuery::ConfigError, "Unknown time unit: unknown")
    end
  end

  describe ".to_epoch" do
    it "converts Time to epoch" do
      time = Time.new(2024, 1, 15, 10, 30, 0, "+00:00")
      expect(described_class.to_epoch(time)).to eq(time.to_i)
    end

    it "passes through integers" do
      expect(described_class.to_epoch(1705315800)).to eq(1705315800)
    end

    it "parses time strings" do
      epoch = described_class.to_epoch("2024-01-15T10:30:00Z")
      expect(epoch).to be_a(Integer)
    end

    it "raises error for unsupported types" do
      expect { described_class.to_epoch([]) }
        .to raise_error(CloudwatchQuery::ConfigError, /Cannot convert/)
    end
  end

  describe ".parse_relative_time" do
    it "parses seconds" do
      result = described_class.parse_relative_time("30s")
      expect(result).to be_within(1).of(Time.now - 30)
    end

    it "parses minutes" do
      result = described_class.parse_relative_time("5m")
      expect(result).to be_within(1).of(Time.now - 300)
    end

    it "parses hours" do
      result = described_class.parse_relative_time("2h")
      expect(result).to be_within(1).of(Time.now - 7200)
    end

    it "parses days" do
      result = described_class.parse_relative_time("1d")
      expect(result).to be_within(1).of(Time.now - 86400)
    end

    it "parses weeks" do
      result = described_class.parse_relative_time("1w")
      expect(result).to be_within(1).of(Time.now - 604800)
    end

    it "returns nil for invalid format" do
      expect(described_class.parse_relative_time("invalid")).to be_nil
    end

    it "returns nil for non-strings" do
      expect(described_class.parse_relative_time(123)).to be_nil
    end
  end
end
