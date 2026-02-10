# frozen_string_literal: true

RSpec.describe CloudwatchQuery::ResultSet do
  subject(:result_set) { described_class.new(results: results, statistics: statistics) }

  let(:results) do
    [
      { "timestamp" => "2024-01-15T10:30:00Z", "message" => "Error 1" },
      { "timestamp" => "2024-01-15T10:31:00Z", "message" => "Error 2" },
      { "timestamp" => "2024-01-15T10:32:00Z", "message" => "Error 3" }
    ]
  end

  let(:statistics) { { records_matched: 3, records_scanned: 1000 } }

  describe "#count" do
    it "returns the number of results" do
      expect(result_set.count).to eq(3)
    end
  end

  describe "#size" do
    it "is an alias for count" do
      expect(result_set.size).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns false when results exist" do
      expect(result_set.empty?).to be false
    end

    it "returns true when no results" do
      empty_set = described_class.new(results: [])
      expect(empty_set.empty?).to be true
    end
  end

  describe "#first" do
    it "returns the first result" do
      expect(result_set.first.message).to eq("Error 1")
    end

    it "returns first n results" do
      first_two = result_set.first(2)
      expect(first_two.size).to eq(2)
      expect(first_two.first.message).to eq("Error 1")
    end
  end

  describe "#last" do
    it "returns the last result" do
      expect(result_set.last.message).to eq("Error 3")
    end
  end

  describe "#each" do
    it "yields each result" do
      messages = []
      result_set.each { |r| messages << r.message }
      expect(messages).to eq(["Error 1", "Error 2", "Error 3"])
    end
  end

  describe "Enumerable" do
    it "supports map" do
      messages = result_set.map(&:message)
      expect(messages).to eq(["Error 1", "Error 2", "Error 3"])
    end

    it "supports select" do
      filtered = result_set.select { |r| r.message.include?("2") }
      expect(filtered.size).to eq(1)
    end
  end

  describe "#statistics" do
    it "returns query statistics" do
      expect(result_set.statistics[:records_matched]).to eq(3)
    end
  end
end
